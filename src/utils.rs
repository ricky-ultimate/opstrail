use anyhow::{anyhow, Result};
use chrono::{DateTime, Duration, Local, Utc};

pub fn parse_relative_time(input: &str) -> Result<DateTime<Utc>> {
    let now = Utc::now();

    match input {
        "now" => Ok(now),
        "today" => {
            let local = Local::now();
            let today_start = local.date_naive().and_hms_opt(0, 0, 0).unwrap();
            Ok(today_start.and_local_timezone(Local).unwrap().with_timezone(&Utc))
        }
        "yesterday" => {
            let local = Local::now();
            let yesterday = local.date_naive().pred_opt().unwrap();
            let yesterday_start = yesterday.and_hms_opt(0, 0, 0).unwrap();
            Ok(yesterday_start.and_local_timezone(Local).unwrap().with_timezone(&Utc))
        }
        "last-session" => {
            Ok(now - Duration::hours(1))
        }
        s if s.ends_with('m') => {
            let mins: i64 = s.trim_end_matches('m').parse()
                .map_err(|_| anyhow!("Invalid time format: {}", s))?;
            Ok(now - Duration::minutes(mins))
        }
        s if s.ends_with('h') => {
            let hours: i64 = s.trim_end_matches('h').parse()
                .map_err(|_| anyhow!("Invalid time format: {}", s))?;
            Ok(now - Duration::hours(hours))
        }
        s if s.ends_with('d') => {
            let days: i64 = s.trim_end_matches('d').parse()
                .map_err(|_| anyhow!("Invalid time format: {}", s))?;
            Ok(now - Duration::days(days))
        }
        s if s.ends_with("w") => {
            let weeks: i64 = s.trim_end_matches('w').parse()
                .map_err(|_| anyhow!("Invalid time format: {}", s))?;
            Ok(now - Duration::weeks(weeks))
        }
        _ => Err(anyhow!("Unrecognized time format: {}", input))
    }
}

/// Format a duration in human-readable form
pub fn format_duration(duration: Duration) -> String {
    let total_secs = duration.num_seconds().abs();

    if total_secs < 60 {
        format!("{}s", total_secs)
    } else if total_secs < 3600 {
        let mins = total_secs / 60;
        format!("{}m", mins)
    } else if total_secs < 86400 {
        let hours = total_secs / 3600;
        let mins = (total_secs % 3600) / 60;
        if mins > 0 {
            format!("{}h {}m", hours, mins)
        } else {
            format!("{}h", hours)
        }
    } else {
        let days = total_secs / 86400;
        let hours = (total_secs % 86400) / 3600;
        if hours > 0 {
            format!("{}d {}h", days, hours)
        } else {
            format!("{}d", days)
        }
    }
}
