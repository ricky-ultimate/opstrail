use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::fs;
use std::path::PathBuf;

#[derive(Debug, Serialize, Deserialize)]
pub struct ProjWarpConfig {
    pub projects: HashMap<String, String>,
}

pub struct ProjWarp;

impl ProjWarp {
    pub fn load() -> Option<ProjWarpConfig> {
        let path = Self::config_path()?;

        if !path.exists() {
            return None;
        }

        let contents = fs::read_to_string(&path).ok()?;
        serde_json::from_str(&contents).ok()
    }

    pub fn resolve_project(path: &str) -> Option<String> {
        let config = Self::load()?;

        let normalized_path = path.replace('\\', "/");

        for (alias, project_path) in &config.projects {
            let normalized_project = project_path.replace('\\', "/");
            if normalized_path == normalized_project {
                return Some(alias.clone());
            }
        }

        for (alias, project_path) in &config.projects {
            let normalized_project = project_path.replace('\\', "/");
            if normalized_path.starts_with(&normalized_project) {
                return Some(alias.clone());
            }
        }

        None
    }

    #[allow(dead_code)]
    pub fn get_project_path(alias: &str) -> Option<String> {
        let config = Self::load()?;
        config.projects.get(alias).cloned()
    }

    fn config_path() -> Option<PathBuf> {
        let home = dirs::home_dir()?;
        Some(home.join(".projwarp.json"))
    }
}
