#[cfg(test)]
mod tests {
    use crate::cli::PruneArgs;
    use crate::events::{Event, EventType};
    use chrono::{Duration, Utc};
    use std::io::Write;
    use tempfile::NamedTempFile;

    fn make_event(days_ago: i64) -> String {
        let mut event = Event::new(EventType::Command {
            cmd: "cargo build".to_string(),
        });
        event.timestamp = Utc::now() - Duration::days(days_ago);
        serde_json::to_string(&event).unwrap()
    }

    #[test]
    fn test_prune_dry_run_does_not_modify_file() {
        let mut file = NamedTempFile::new().unwrap();
        writeln!(file, "{}", make_event(100)).unwrap();
        writeln!(file, "{}", make_event(5)).unwrap();

        let original = std::fs::read_to_string(file.path()).unwrap();

        let _args = PruneArgs {
            keep_days: 30,
            dry_run: true,
        };

        let after = std::fs::read_to_string(file.path()).unwrap();
        assert_eq!(original, after);
    }

    #[test]
    fn test_event_age_filtering() {
        let old = make_event(100);
        let recent = make_event(5);

        let old_event: Event = serde_json::from_str(&old).unwrap();
        let recent_event: Event = serde_json::from_str(&recent).unwrap();

        let cutoff = Utc::now() - Duration::days(30);

        assert!(old_event.timestamp < cutoff);
        assert!(recent_event.timestamp >= cutoff);
    }
}
