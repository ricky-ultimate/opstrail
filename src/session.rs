use crate::config::Config;
use crate::events::Event;
use anyhow::{Result, anyhow};
use chrono::{DateTime, Duration, Local, Utc};
use colored::*;
use serde::{Deserialize, Serialize};
use std::fs;
use uuid::Uuid;

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
            Err(anyhow!(
                "No active session. Start a session with: trail log --session-start"
            ))
        }
    }

    pub fn current_session_id_or_create() -> Result<String> {
        match Self::current_session_id() {
            Ok(id) => Ok(id),
            Err(_) => Self::new_session(),
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

    pub fn new_session() -> Result<String> {
        let session_id = Self::generate_session_id();
        let state = SessionState {
            current_session_id: session_id.clone(),
            session_start: Utc::now(),
            last_activity: Utc::now(),
        };
        Self::save_state(&state)?;
        Ok(session_id)
    }

    fn generate_session_id() -> String {
        Uuid::new_v4().to_string()
    }

    #[cfg(test)]
    pub fn generate_session_id_pub() -> String {
        Self::generate_session_id()
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

    let mut session_list: Vec<(String, Vec<&Event>)> = sessions.into_iter().collect();
    session_list.sort_by_key(|(_, events)| {
        events
            .first()
            .map(|e| e.timestamp)
            .unwrap_or(DateTime::<Utc>::MIN_UTC)
    });
    session_list.reverse();

    println!("{}", "Sessions".bold().cyan());
    println!();

    for (i, (_, events)) in session_list.iter().enumerate() {
        let start = events.first().map(|e| e.timestamp).unwrap();
        let end = events.last().map(|e| e.timestamp).unwrap();
        let duration = end - start;

        let start_local = start.with_timezone(&Local);
        let end_local = end.with_timezone(&Local);

        println!(
            "  {} {}  {}  {}",
            format!("#{}", i + 1).dimmed(),
            start_local.format("%Y-%m-%d %H:%M").to_string().yellow(),
            end_local.format("%H:%M").to_string().dimmed(),
            format!("{} events, {}m", events.len(), duration.num_minutes()).dimmed()
        );
    }

    Ok(())
}
