use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Event {
    pub timestamp: DateTime<Utc>,
    pub event_type: EventType,
    pub cwd: Option<String>,
    pub project: Option<String>,
    pub session_id: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "type", rename_all = "snake_case")]
pub enum EventType {
    Command { cmd: String },
    DirectoryChange { from: String, to: String },
    SessionStart,
    SessionEnd,
    IdleStart,
    IdleEnd,
    Note { text: String },
    ProjectDetected { name: String },
}

impl Event {
    pub fn new(event_type: EventType) -> Self {
        Self {
            timestamp: Utc::now(),
            event_type,
            cwd: None,
            project: None,
            session_id: None,
        }
    }

    pub fn with_cwd(mut self, cwd: String) -> Self {
        self.cwd = Some(cwd);
        self
    }

    pub fn with_project(mut self, project: String) -> Self {
        self.project = Some(project);
        self
    }

    pub fn with_session(mut self, session_id: String) -> Self {
        self.session_id = Some(session_id);
        self
    }
}

impl EventType {
    #[allow(dead_code)]
    pub fn display_name(&self) -> &str {
        match self {
            EventType::Command { .. } => "command",
            EventType::DirectoryChange { .. } => "cd",
            EventType::SessionStart => "session_start",
            EventType::SessionEnd => "session_end",
            EventType::IdleStart => "idle_start",
            EventType::IdleEnd => "idle_end",
            EventType::Note { .. } => "note",
            EventType::ProjectDetected { .. } => "project",
        }
    }
}
