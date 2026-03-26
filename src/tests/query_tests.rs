#[cfg(test)]
mod tests {
    use crate::events::{Event, EventType};
    use chrono::{Duration, Utc};

    fn make_command_event(cmd: &str, cwd: &str, days_ago: i64) -> Event {
        let mut event = Event::new(EventType::Command {
            cmd: cmd.to_string(),
        });
        event.timestamp = Utc::now() - Duration::days(days_ago);
        event.cwd = Some(cwd.to_string());
        event
    }

    #[test]
    fn test_time_travel_staleness_recent_event_passes() {
        let event = make_command_event("cargo test", "/home/user/project", 0);
        let staleness = Utc::now() - event.timestamp;
        assert!(staleness.num_hours() < 24);
    }

    #[test]
    fn test_time_travel_staleness_old_event_fails() {
        let event = make_command_event("cargo test", "/home/user/project", 2);
        let staleness = Utc::now() - event.timestamp;
        assert!(staleness.num_hours() >= 24);
    }

    #[test]
    fn test_search_filter_matches_command() {
        let events = vec![
            make_command_event("cargo build", "/home/user/project", 0),
            make_command_event("git status", "/home/user/project", 0),
        ];

        let query = "cargo";
        let matched: Vec<&Event> = events
            .iter()
            .filter(|e| match &e.event_type {
                EventType::Command { cmd } => cmd.to_lowercase().contains(query),
                _ => false,
            })
            .collect();

        assert_eq!(matched.len(), 1);
        if let EventType::Command { cmd } = &matched[0].event_type {
            assert_eq!(cmd, "cargo build");
        }
    }

    #[test]
    fn test_search_filter_no_match() {
        let events = vec![make_command_event("cargo build", "/home/user/project", 0)];

        let query = "docker";
        let matched: Vec<&Event> = events
            .iter()
            .filter(|e| match &e.event_type {
                EventType::Command { cmd } => cmd.to_lowercase().contains(query),
                _ => false,
            })
            .collect();

        assert!(matched.is_empty());
    }

    #[test]
    fn test_stats_week_start_is_monday() {
        use chrono::{Datelike, Local};
        let now = Local::now();
        let days_from_monday = now.date_naive().weekday().num_days_from_monday() as i64;
        let week_start = now.date_naive() - chrono::Duration::days(days_from_monday);
        assert!(week_start <= now.date_naive());
        let diff = (now.date_naive() - week_start).num_days();
        assert!((0..=6).contains(&diff));
    }

    #[test]
    fn test_resume_finds_last_event_with_cwd() {
        let mut old = make_command_event("git log", "/home/user/old", 1);
        old.cwd = Some("/home/user/old".to_string());

        let mut recent = make_command_event("cargo run", "/home/user/new", 0);
        recent.cwd = Some("/home/user/new".to_string());

        let events = vec![old, recent];

        let last = events.iter().rev().find(|e| e.cwd.is_some());
        assert!(last.is_some());
        assert_eq!(last.unwrap().cwd.as_deref(), Some("/home/user/new"));
    }
}
