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
