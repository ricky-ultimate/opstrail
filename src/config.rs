use anyhow::{Context, Result};
use serde::{Deserialize, Serialize};
use std::fs;
use std::path::PathBuf;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Config {
    pub idle_timeout_minutes: u64,
    pub enable_projwarp_integration: bool,
}

impl Default for Config {
    fn default() -> Self {
        Self {
            idle_timeout_minutes: 10,
            enable_projwarp_integration: true,
        }
    }
}

impl Config {
    pub fn load() -> Result<Self> {
        let path = Self::config_path()?;

        if path.exists() {
            let contents = fs::read_to_string(&path)
                .context("Failed to read config file")?;
            let config: Config = serde_json::from_str(&contents)
                .context("Failed to parse config file")?;
            Ok(config)
        } else {
            let config = Self::default();
            config.save()?;
            Ok(config)
        }
    }

    pub fn save(&self) -> Result<()> {
        let path = Self::config_path()?;
        let dir = path.parent().unwrap();

        fs::create_dir_all(dir)?;

        let contents = serde_json::to_string_pretty(self)?;
        fs::write(&path, contents)?;

        Ok(())
    }

    pub fn config_path() -> Result<PathBuf> {
        let home = dirs::home_dir().context("Could not determine home directory")?;
        Ok(home.join(".opstrail").join("config.json"))
    }

    pub fn data_dir() -> Result<PathBuf> {
        let home = dirs::home_dir().context("Could not determine home directory")?;
        Ok(home.join(".opstrail"))
    }

    pub fn timeline_path() -> Result<PathBuf> {
        Ok(Self::data_dir()?.join("timeline.jsonl"))
    }

    pub fn state_path() -> Result<PathBuf> {
        Ok(Self::data_dir()?.join("state.json"))
    }
}
