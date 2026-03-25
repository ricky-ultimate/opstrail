use crate::cli::{ConfigArgs, ConfigSetArgs, ConfigSubcommand};
use anyhow::{anyhow, Context, Result};
use colored::*;
use serde::{Deserialize, Serialize};
use std::fs;
use std::path::PathBuf;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Config {
    pub idle_timeout_minutes: u64,
    pub enable_projwarp_integration: bool,
    #[serde(default)]
    pub auto_cd: AutoCdConfig,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AutoCdConfig {
    #[serde(default = "default_true")]
    pub back: bool,
    #[serde(default = "default_true")]
    pub resume: bool,
}

fn default_true() -> bool {
    true
}

impl Default for AutoCdConfig {
    fn default() -> Self {
        Self {
            back: true,
            resume: true,
        }
    }
}

impl Default for Config {
    fn default() -> Self {
        Self {
            idle_timeout_minutes: 10,
            enable_projwarp_integration: true,
            auto_cd: AutoCdConfig::default(),
        }
    }
}

impl Config {
    pub fn load() -> Result<Self> {
        let path = Self::config_path()?;

        if path.exists() {
            let contents = fs::read_to_string(&path).context("Failed to read config file")?;
            let config: Config =
                serde_json::from_str(&contents).context("Failed to parse config file")?;
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

pub fn handle_config_command(args: ConfigArgs) -> Result<()> {
    match args.subcommand {
        ConfigSubcommand::Show => show_config(),
        ConfigSubcommand::Set(set_args) => set_config(set_args),
    }
}

fn show_config() -> Result<()> {
    let config = Config::load()?;
    let path = Config::config_path()?;

    println!("{}", "Current Configuration".bold().cyan());
    println!("{}", path.display().to_string().dimmed());
    println!();
    println!(
        "  {:<35} {}",
        "idle_timeout_minutes",
        config.idle_timeout_minutes.to_string().yellow()
    );
    println!(
        "  {:<35} {}",
        "enable_projwarp_integration",
        config.enable_projwarp_integration.to_string().yellow()
    );
    println!(
        "  {:<35} {}",
        "auto_cd.back",
        config.auto_cd.back.to_string().yellow()
    );
    println!(
        "  {:<35} {}",
        "auto_cd.resume",
        config.auto_cd.resume.to_string().yellow()
    );

    Ok(())
}

fn set_config(args: ConfigSetArgs) -> Result<()> {
    let mut config = Config::load()?;

    match args.key.as_str() {
        "idle_timeout_minutes" => {
            let val: u64 = args
                .value
                .parse()
                .map_err(|_| anyhow!("Value must be a positive integer"))?;
            config.idle_timeout_minutes = val;
        }
        "enable_projwarp_integration" => {
            let val: bool = args
                .value
                .parse()
                .map_err(|_| anyhow!("Value must be true or false"))?;
            config.enable_projwarp_integration = val;
        }
        "auto_cd.back" => {
            let val: bool = args
                .value
                .parse()
                .map_err(|_| anyhow!("Value must be true or false"))?;
            config.auto_cd.back = val;
        }
        "auto_cd.resume" => {
            let val: bool = args
                .value
                .parse()
                .map_err(|_| anyhow!("Value must be true or false"))?;
            config.auto_cd.resume = val;
        }
        _ => {
            return Err(anyhow!(
                "Unknown config key: {}. Valid keys: idle_timeout_minutes, enable_projwarp_integration, auto_cd.back, auto_cd.resume",
                args.key
            ));
        }
    }

    config.save()?;
    println!("Set {} = {}", args.key.green(), args.value.yellow());

    Ok(())
}
