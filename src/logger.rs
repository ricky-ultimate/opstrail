use crate::cli::{LogArgs, NoteArgs};
use crate::config::Config;
use crate::events::{Event, EventType};
use crate::projwarp::ProjWarp;
use crate::session::SessionManager;
use anyhow::Result;
use std::fs::OpenOptions;
use std::io::Write;

pub fn log_event(args: LogArgs) -> Result<()> {
    let config = Config::load()?;
    let timeline_path = Config::timeline_path()?;

    let event_type = if args.session_start {
        EventType::SessionStart
    } else if args.session_end {
        EventType::SessionEnd
    } else if args.idle_start {
        EventType::IdleStart
    } else if args.idle_end {
        EventType::IdleEnd
    } else if let Some(cmd) = args.cmd {
        EventType::Command { cmd }
    } else {
        return Ok(());
    };

    let mut event = Event::new(event_type);

    if let Some(cwd) = args.cwd.or(std::env::current_dir().ok().map(|p| p.to_string_lossy().to_string())) {
        let project = if config.enable_projwarp_integration {
            args.project.or_else(|| ProjWarp::resolve_project(&cwd))
        } else {
            args.project
        };

        event = event.with_cwd(cwd);
        if let Some(proj) = project {
            event = event.with_project(proj);
        }
    }

    let session_id = SessionManager::current_session_id()?;
    event = event.with_session(session_id);

    write_event(&timeline_path, &event)?;

    SessionManager::update_last_activity()?;

    Ok(())
}

pub fn add_note(args: NoteArgs) -> Result<()> {
    let timeline_path = Config::timeline_path()?;

    let cwd = std::env::current_dir()
        .ok()
        .map(|p| p.to_string_lossy().to_string());

    let project = if let Some(ref cwd) = cwd {
        ProjWarp::resolve_project(cwd)
    } else {
        None
    };

    let mut event = Event::new(EventType::Note { text: args.text.clone() });

    if let Some(cwd) = cwd {
        event = event.with_cwd(cwd);
    }

    if let Some(project) = project {
        event = event.with_project(project);
    }

    let session_id = SessionManager::current_session_id()?;
    event = event.with_session(session_id);

    write_event(&timeline_path, &event)?;

    println!("Note added: {}", args.text);

    Ok(())
}

fn write_event(path: &std::path::Path, event: &Event) -> Result<()> {
    if let Some(parent) = path.parent() {
        std::fs::create_dir_all(parent)?;
    }

    let mut file = OpenOptions::new()
        .create(true)
        .append(true)
        .open(path)?;

    let json = serde_json::to_string(event)?;
    writeln!(file, "{}", json)?;

    Ok(())
}
