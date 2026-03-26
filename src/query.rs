use crate::cli::{BackArgs, SearchArgs, StatsArgs, TimelineArgs};
use crate::config::Config;
use crate::events::{Event, EventType};
use crate::projwarp::ProjWarp;
use crate::utils;
use anyhow::Result;
use chrono::{Local, NaiveDate};
use colored::*;
use std::collections::HashMap;
use std::fs;

pub fn time_travel(args: BackArgs) -> Result<()> {
    let timeline_path = Config::timeline_path()?;

    if !timeline_path.exists() {
        println!("No activity history found.");
        return Ok(());
    }

    let contents = fs::read_to_string(&timeline_path)?;
    let events: Vec<Event> = contents
        .lines()
        .filter_map(|line| serde_json::from_str(line).ok())
        .collect();

    let target_time = utils::parse_relative_time(&args.when)?;

    let target_event = events
        .iter()
        .filter(|e| e.cwd.is_some() && e.timestamp <= target_time)
        .max_by_key(|e| e.timestamp);

    if let Some(event) = target_event {
        if let Some(ref cwd) = event.cwd {
            let staleness = chrono::Utc::now() - event.timestamp;
            if staleness.num_hours() < 24 {
                println!("{}", cwd);
            } else {
                eprintln!(
                    "No recent activity found for that time (closest match was {} ago)",
                    utils::format_duration(staleness)
                );
                std::process::exit(1);
            }
        }
    } else {
        eprintln!("No activity found for that time.");
        std::process::exit(1);
    }

    Ok(())
}


pub fn search(args: SearchArgs) -> Result<()> {
    let timeline_path = Config::timeline_path()?;

    if !timeline_path.exists() {
        println!("No activity history found.");
        return Ok(());
    }

    let contents = fs::read_to_string(&timeline_path)?;
    let events: Vec<Event> = contents
        .lines()
        .filter_map(|line| serde_json::from_str(line).ok())
        .collect();

    let query_lower = args.query.to_lowercase();

    let filtered: Vec<&Event> = events
        .iter()
        .filter(|e| {
            if args.today {
                let today = Local::now().date_naive();
                if e.timestamp.with_timezone(&Local).date_naive() != today {
                    return false;
                }
            }

            if let Some(ref date_str) = args.date {
                if let Ok(target_date) = NaiveDate::parse_from_str(date_str, "%Y-%m-%d") {
                    if e.timestamp.with_timezone(&Local).date_naive() != target_date {
                        return false;
                    }
                }
            }

            if let Some(ref proj) = args.project {
                if e.project.as_ref() != Some(proj) {
                    return false;
                }
            }

            match &e.event_type {
                EventType::Command { cmd } => cmd.to_lowercase().contains(&query_lower),
                EventType::Note { text } => text.to_lowercase().contains(&query_lower),
                EventType::ProjectDetected { name } => name.to_lowercase().contains(&query_lower),
                _ => false,
            }
        })
        .collect();

    if filtered.is_empty() {
        println!("No results found for '{}'", args.query);
        return Ok(());
    }

    println!("Found {} results:\n", filtered.len());

    for event in filtered.iter().take(50) {
        let time = event
            .timestamp
            .with_timezone(&Local)
            .format("%Y-%m-%d %H:%M:%S");
        let project_tag = event
            .project
            .as_ref()
            .map(|p| format!("[{}]", p.cyan()))
            .unwrap_or_default();

        let description = match &event.event_type {
            EventType::Command { cmd } => format!("ran {}", cmd.yellow()),
            EventType::Note { text } => format!("note: {}", text.green()),
            EventType::ProjectDetected { name } => format!("entered project {}", name.cyan()),
            _ => continue,
        };

        println!(
            "{} {} {}",
            time.to_string().dimmed(),
            project_tag,
            description
        );
    }

    Ok(())
}

pub fn stats(args: StatsArgs) -> Result<()> {
    let timeline_path = Config::timeline_path()?;

    if !timeline_path.exists() {
        println!("No activity history found.");
        return Ok(());
    }

    let contents = fs::read_to_string(&timeline_path)?;
    let all_events: Vec<Event> = contents
        .lines()
        .filter_map(|line| serde_json::from_str(line).ok())
        .collect();

    let now = Local::now();

    let (from, to) = if args.week {
        let start = now.date_naive() - chrono::Duration::days(now.date_naive().weekday() as i64);
        let end = now.date_naive();
        (start, end)
    } else if args.month {
        let start = NaiveDate::from_ymd_opt(now.year(), now.month(), 1).unwrap();
        let end = now.date_naive();
        (start, end)
    } else if let (Some(from_str), Some(to_str)) = (&args.from, &args.to) {
        let from = NaiveDate::parse_from_str(from_str, "%Y-%m-%d")
            .map_err(|_| anyhow::anyhow!("Invalid --from date format. Use YYYY-MM-DD"))?;
        let to = NaiveDate::parse_from_str(to_str, "%Y-%m-%d")
            .map_err(|_| anyhow::anyhow!("Invalid --to date format. Use YYYY-MM-DD"))?;
        (from, to)
    } else if let Some(from_str) = &args.from {
        let from = NaiveDate::parse_from_str(from_str, "%Y-%m-%d")
            .map_err(|_| anyhow::anyhow!("Invalid --from date format. Use YYYY-MM-DD"))?;
        (from, now.date_naive())
    } else {
        let thirty_days_ago = now.date_naive() - chrono::Duration::days(30);
        (thirty_days_ago, now.date_naive())
    };

    let events: Vec<&Event> = all_events
        .iter()
        .filter(|e| {
            let date = e.timestamp.with_timezone(&Local).date_naive();
            date >= from && date <= to
        })
        .collect();

    if events.is_empty() {
        println!("No activity found for the specified period.");
        return Ok(());
    }

    let mut project_time: HashMap<String, i64> = HashMap::new();
    let mut command_count: HashMap<String, usize> = HashMap::new();
    let mut total_commands = 0usize;
    let mut active_days: std::collections::HashSet<NaiveDate> = std::collections::HashSet::new();

    for event in &events {
        active_days.insert(event.timestamp.with_timezone(&Local).date_naive());

        if let EventType::Command { cmd } = &event.event_type {
            total_commands += 1;
            let cmd_name = cmd.split_whitespace().next().unwrap_or(cmd);
            *command_count.entry(cmd_name.to_string()).or_insert(0) += 1;
        }

        if let Some(ref project) = event.project {
            *project_time.entry(project.clone()).or_insert(0) += 1;
        }
    }

    println!("{}", "Activity Statistics".bold().cyan());
    println!(
        "  Period: {} to {}",
        from.format("%Y-%m-%d").to_string().yellow(),
        to.format("%Y-%m-%d").to_string().yellow()
    );
    println!();
    println!(
        "  {:<25} {}",
        "Total events:",
        events.len().to_string().yellow()
    );
    println!(
        "  {:<25} {}",
        "Total commands:",
        total_commands.to_string().yellow()
    );
    println!(
        "  {:<25} {}",
        "Active days:",
        active_days.len().to_string().yellow()
    );
    println!();

    println!("{}", "Most Active Projects:".bold());
    let mut projects: Vec<_> = project_time.iter().collect();
    projects.sort_by(|a, b| b.1.cmp(a.1));
    for (i, (project, count)) in projects.iter().take(5).enumerate() {
        println!("  {}. {} ({} activities)", i + 1, project.yellow(), count);
    }
    println!();

    println!("{}", "Most Used Commands:".bold());
    let mut commands: Vec<_> = command_count.iter().collect();
    commands.sort_by(|a, b| b.1.cmp(a.1));
    for (i, (cmd, count)) in commands.iter().take(10).enumerate() {
        println!("  {}. {} ({})", i + 1, cmd.green(), count);
    }

    Ok(())
}

pub fn timeline(args: TimelineArgs) -> Result<()> {
    let timeline_path = Config::timeline_path()?;

    if !timeline_path.exists() {
        println!("No activity history found.");
        return Ok(());
    }

    let contents = fs::read_to_string(&timeline_path)?;
    let events: Vec<Event> = contents
        .lines()
        .filter_map(|line| serde_json::from_str(line).ok())
        .collect();

    let filtered: Vec<&Event> = if args.today {
        let today = Local::now().date_naive();
        events
            .iter()
            .filter(|e| e.timestamp.with_timezone(&Local).date_naive() == today)
            .collect()
    } else if args.yesterday {
        let yesterday = Local::now().date_naive().pred_opt().unwrap();
        events
            .iter()
            .filter(|e| e.timestamp.with_timezone(&Local).date_naive() == yesterday)
            .collect()
    } else if let Some(ref date_str) = args.date {
        if let Ok(target_date) = NaiveDate::parse_from_str(date_str, "%Y-%m-%d") {
            events
                .iter()
                .filter(|e| e.timestamp.with_timezone(&Local).date_naive() == target_date)
                .collect()
        } else {
            eprintln!("Invalid date format. Use YYYY-MM-DD");
            return Ok(());
        }
    } else {
        events.iter().collect()
    };

    if filtered.is_empty() {
        println!("No activity found for the specified period.");
        return Ok(());
    }

    println!("{}", "Activity Timeline".bold().cyan());
    println!();

    for event in filtered.iter().rev().take(args.limit) {
        let time = event
            .timestamp
            .with_timezone(&Local)
            .format("%Y-%m-%d %H:%M:%S");
        let project = event
            .project
            .as_ref()
            .map(|p| format!("[{}]", p.cyan()))
            .unwrap_or_else(|| "".to_string());

        let label = match &event.event_type {
            EventType::Command { cmd } => format!("cmd  {}", cmd.yellow()),
            EventType::DirectoryChange { to, .. } => format!("cd   {}", to.blue()),
            EventType::SessionStart => format!("sess {}", "started".green()),
            EventType::SessionEnd => format!("sess {}", "ended".red()),
            EventType::IdleStart => format!("idle {}", "start".dimmed()),
            EventType::IdleEnd => format!("idle {}", "end".green()),
            EventType::Note { text } => format!("note {}", text.green()),
            EventType::ProjectDetected { name } => format!("proj {}", name.cyan()),
        };

        println!("{} {} {}", time.to_string().dimmed(), project, label);
    }

    Ok(())
}

pub fn resume() -> Result<()> {
    let timeline_path = Config::timeline_path()?;

    if !timeline_path.exists() {
        println!("No activity history found.");
        return Ok(());
    }

    let contents = fs::read_to_string(&timeline_path)?;
    let events: Vec<Event> = contents
        .lines()
        .filter_map(|line| serde_json::from_str(line).ok())
        .collect();

    let last_activity = events.iter().rev().find(|e| e.cwd.is_some());

    if let Some(event) = last_activity {
        let cwd = event.cwd.as_ref().unwrap();

        println!("{}", "Last Active Session:".bold().cyan());
        println!();

        if let Some(ref proj) = event.project {
            println!("  Project:      {}", proj.yellow());
        }

        println!("  Path:         {}", cwd.blue());
        println!(
            "  Time:         {}",
            event
                .timestamp
                .with_timezone(&Local)
                .format("%Y-%m-%d %H:%M:%S")
                .to_string()
                .dimmed()
        );

        let last_cmd = events
            .iter()
            .rev()
            .find(|e| matches!(e.event_type, EventType::Command { .. }));

        if let Some(cmd_event) = last_cmd {
            if let EventType::Command { cmd } = &cmd_event.event_type {
                println!("  Last command: {}", cmd.green());
            }
        }

        println!();
        println!("{}", cwd);
    } else {
        println!("No previous session found.");
    }

    Ok(())
}

pub fn today() -> Result<()> {
    let timeline_path = Config::timeline_path()?;

    if !timeline_path.exists() {
        println!("No activity recorded today.");
        return Ok(());
    }

    let contents = fs::read_to_string(&timeline_path)?;
    let today = Local::now().date_naive();

    let today_events: Vec<Event> = contents
        .lines()
        .filter_map(|line| serde_json::from_str::<Event>(line).ok())
        .filter(|e| e.timestamp.with_timezone(&Local).date_naive() == today)
        .collect();

    if today_events.is_empty() {
        println!("No activity recorded today.");
        return Ok(());
    }

    println!("{}", "Today's Summary".bold().cyan());
    println!();

    let mut projects = HashMap::new();
    let mut commands = 0;

    for event in &today_events {
        if matches!(event.event_type, EventType::Command { .. }) {
            commands += 1;
        }
        if let Some(ref proj) = event.project {
            *projects.entry(proj.clone()).or_insert(0) += 1;
        }
    }

    println!("  Events:   {}", today_events.len().to_string().yellow());
    println!("  Commands: {}", commands.to_string().green());
    println!("  Projects: {}", projects.len().to_string().cyan());

    if !projects.is_empty() {
        println!();
        println!("{}", "  Active Projects:".bold());
        for (proj, count) in projects.iter() {
            println!("    {} ({} activities)", proj.yellow(), count);
        }
    }

    Ok(())
}

pub fn projects() -> Result<()> {
    let timeline_path = Config::timeline_path()?;

    if !timeline_path.exists() {
        println!("No activity history found.");
        return Ok(());
    }

    let contents = fs::read_to_string(&timeline_path)?;
    let events: Vec<Event> = contents
        .lines()
        .filter_map(|line| serde_json::from_str(line).ok())
        .collect();

    let mut project_stats: HashMap<String, (usize, String)> = HashMap::new();

    for event in &events {
        if let Some(ref proj) = event.project {
            let entry = project_stats
                .entry(proj.clone())
                .or_insert((0, String::new()));
            entry.0 += 1;
            if let Some(ref cwd) = event.cwd {
                entry.1 = cwd.clone();
            }
        }
    }

    println!("{}", "Project Activity".bold().cyan());
    println!();

    if project_stats.is_empty() {
        println!("No projects tracked yet.");

        if let Some(config) = ProjWarp::load() {
            println!();
            println!("{}", "Available projects from projwarp:".dimmed());
            for (alias, path) in config.projects.iter() {
                println!("  {} -> {}", alias.yellow(), path.dimmed());
            }
        }
    } else {
        let mut projects: Vec<_> = project_stats.iter().collect();
        projects.sort_by(|a, b| b.1.0.cmp(&a.1.0));

        for (proj, (count, path)) in projects {
            println!("  {} ({} activities)", proj.yellow().bold(), count);
            println!("    {}", path.dimmed());
            println!();
        }
    }

    Ok(())
}

use chrono::Datelike;
