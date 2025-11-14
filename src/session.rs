use crate::config::Config;
use crate::events::Event;
use anyhow::Result;
use chrono::{DateTime, Duration, Utc};
use serde::{Deserialize, Serialize};
use std::fs;

#[derive(Debug, Serialize, Deserialize)]
pub struct SessionState {
    pub current_session_id: String,
    pub session_start: DateTime<Utc>,
    pub last_activity: DateTime<Utc>,
}

pub struct SessionManager;

impl SessionManager {
    pub fn current_session_id() -> Result<String> {
        let state_path = Config::state_path()?;

        if state_path.exists() {
            let contents = fs::read_to_string(&state_path)?;
            let state: SessionState = serde_json::from_str(&contents)?;
            Ok(state.current_session_id)
        } else {
            let session_id = Self::generate_session_id();
            let state = SessionState {
                current_session_id: session_id.clone(),
                session_start: Utc::now(),
                last_activity: Utc::now(),
            };
            Self::save_state(&state)?;
            Ok(session_id)
        }
    }

    pub fn update_last_activity() -> Result<()> {
        let state_path = Config::state_path()?;

        if state_path.exists() {
            let contents = fs::read_to_string(&state_path)?;
            let mut state: SessionState = serde_json::from_str(&contents)?;
            state.last_activity = Utc::now();
            Self::save_state(&state)?;
        }

        Ok(())
    }

    pub fn check_idle() -> Result<bool> {
        let config = Config::load()?;
        let state_path = Config::state_path()?;

        if !state_path.exists() {
            return Ok(false);
        }

        let contents = fs::read_to_string(&state_path)?;
        let state: SessionState = serde_json::from_str(&contents)?;

        let idle_duration = Utc::now() - state.last_activity;
        let idle_threshold = Duration::minutes(config.idle_timeout_minutes as i64);

        Ok(idle_duration > idle_threshold)
    }

    fn generate_session_id() -> String {
        use std::time::{SystemTime, UNIX_EPOCH};
        let timestamp = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_secs();
        format!("session_{}", timestamp)
    }

    fn save_state(state: &SessionState) -> Result<()> {
        let state_path = Config::state_path()?;

        if let Some(parent) = state_path.parent() {
            fs::create_dir_all(parent)?;
        }

        let contents = serde_json::to_string_pretty(state)?;
        fs::write(&state_path, contents)?;

        Ok(())
    }
}

pub fn list_sessions() -> Result<()> {
    let timeline_path = Config::timeline_path()?;

    if !timeline_path.exists() {
        println!("No sessions recorded yet.");
        return Ok(());
    }

    let contents = fs::read_to_string(&timeline_path)?;
    let events: Vec<Event> = contents
        .lines()
        .filter_map(|line| serde_json::from_str(line).ok())
        .collect();

    use std::collections::HashMap;
    let mut sessions: HashMap<String, Vec<&Event>> = HashMap::new();

    for event in &events {
        if let Some(ref session_id) = event.session_id {
            sessions.entry(session_id.clone()).or_default().push(event);
        }
    }

    println!("Sessions:");
    for (_session_id, events) in sessions.iter() {
        let start = events.first().map(|e| e.timestamp).unwrap();
        let end = events.last().map(|e| e.timestamp).unwrap();
        let duration = end - start;

        println!(
            "  {} - {} ({} events, {} minutes)",
            start.format("%Y-%m-%d %H:%M"),
            end.format("%H:%M"),
            events.len(),
            duration.num_minutes()
        );
    }

    Ok(())
}
