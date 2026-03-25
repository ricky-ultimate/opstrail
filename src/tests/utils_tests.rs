#[cfg(test)]
mod tests {
    use crate::utils::parse_relative_time;
    use chrono::Utc;

    #[test]
    fn test_parse_minutes() {
        let before = Utc::now();
        let result = parse_relative_time("30m").unwrap();
        let after = Utc::now();
        let expected_min = before - chrono::Duration::minutes(30);
        let expected_max = after - chrono::Duration::minutes(30);
        assert!(result >= expected_min && result <= expected_max);
    }

    #[test]
    fn test_parse_hours() {
        let before = Utc::now();
        let result = parse_relative_time("2h").unwrap();
        let after = Utc::now();
        let expected_min = before - chrono::Duration::hours(2);
        let expected_max = after - chrono::Duration::hours(2);
        assert!(result >= expected_min && result <= expected_max);
    }

    #[test]
    fn test_parse_days() {
        let before = Utc::now();
        let result = parse_relative_time("7d").unwrap();
        let after = Utc::now();
        let expected_min = before - chrono::Duration::days(7);
        let expected_max = after - chrono::Duration::days(7);
        assert!(result >= expected_min && result <= expected_max);
    }

    #[test]
    fn test_parse_weeks() {
        let before = Utc::now();
        let result = parse_relative_time("2w").unwrap();
        let after = Utc::now();
        let expected_min = before - chrono::Duration::weeks(2);
        let expected_max = after - chrono::Duration::weeks(2);
        assert!(result >= expected_min && result <= expected_max);
    }

    #[test]
    fn test_parse_now() {
        let before = Utc::now();
        let result = parse_relative_time("now").unwrap();
        let after = Utc::now();
        assert!(result >= before && result <= after);
    }

    #[test]
    fn test_parse_invalid() {
        assert!(parse_relative_time("bogus").is_err());
        assert!(parse_relative_time("xm").is_err());
        assert!(parse_relative_time("").is_err());
    }
}
