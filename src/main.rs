mod cli;
mod config;
mod events;
mod logger;
mod projwarp;
mod query;
mod session;
mod utils;

use anyhow::Result;
use clap::Parser;
use cli::{Cli, Command};

fn main() {
    if let Err(e) = run() {
        eprintln!("Error: {}", e);
        std::process::exit(1);
    }
}

fn run() -> Result<()> {
    let cli = Cli::parse();

    match cli.command {
        Command::Log(args) => logger::log_event(args)?,
        Command::Back(args) => query::time_travel(args)?,
        Command::Search(args) => query::search(args)?,
        Command::Stats(args) => query::stats(args)?,
        Command::Timeline(args) => query::timeline(args)?,
        Command::Note(args) => logger::add_note(args)?,
        Command::Resume => query::resume()?,
        Command::Today => query::today()?,
        Command::Sessions => session::list_sessions()?,
        Command::Projects => query::projects()?,
    }

    Ok(())
}
