use crate::cli::PruneArgs;
use crate::config::Config;
use anyhow::Result;
use chrono::Local;
use colored::*;
use std::fs;
use std::io::{BufRead, BufReader, Write};

pub fn prune(args: PruneArgs) -> Result<()> {
    let timeline_path = Config::timeline_path()?;

    if !timeline_path.exists() {
        println!("No activity history found.");
        return Ok(());
    }

    let cutoff = Local::now().date_naive() - chrono::Duration::days(args.keep_days as i64);

    let file = fs::File::open(&timeline_path)?;
    let reader = BufReader::new(file);

    let mut kept = Vec::new();
    let mut pruned_count = 0usize;

    for line in reader.lines() {
        let line = line?;
        if line.trim().is_empty() {
            continue;
        }

        let keep = if let Ok(event) = serde_json::from_str::<crate::events::Event>(&line) {
            let date = event.timestamp.with_timezone(&Local).date_naive();
            date >= cutoff
        } else {
            true
        };

        if keep {
            kept.push(line);
        } else {
            pruned_count += 1;
        }
    }

    if pruned_count == 0 {
        println!(
            "Nothing to prune (no events older than {} days).",
            args.keep_days
        );
        return Ok(());
    }

    if args.dry_run {
        println!(
            "{} {} events would be pruned (older than {}).",
            "[dry-run]".yellow(),
            pruned_count.to_string().yellow(),
            cutoff.format("%Y-%m-%d")
        );
        println!(
            "{} {} events would be retained.",
            "[dry-run]".yellow(),
            kept.len().to_string().green()
        );
        return Ok(());
    }

    let data_dir = Config::data_dir()?;
    let archive_name = format!(
        "timeline-archive-{}.jsonl",
        Local::now().format("%Y%m%d%H%M%S")
    );
    let archive_path = data_dir.join(&archive_name);

    let original = fs::read_to_string(&timeline_path)?;
    fs::write(&archive_path, &original)?;

    let mut out = fs::OpenOptions::new()
        .write(true)
        .truncate(true)
        .open(&timeline_path)?;

    for line in &kept {
        writeln!(out, "{}", line)?;
    }

    println!(
        "Pruned {} events older than {}.",
        pruned_count.to_string().yellow(),
        cutoff.format("%Y-%m-%d")
    );
    println!("Retained {} events.", kept.len().to_string().green());
    println!(
        "Archive saved to: {}",
        archive_path.display().to_string().dimmed()
    );

    Ok(())
}
