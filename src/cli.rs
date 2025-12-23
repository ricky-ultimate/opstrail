use clap::{Parser, Subcommand, Args};

#[derive(Parser, Debug)]
#[command(name = "trail")]
#[command(author = "リッキー")]
#[command(version = "0.1.0")]
#[command(about = "Terminal activity time-machine", long_about = None)]
pub struct Cli {
    #[command(subcommand)]
    pub command: Command,
}

#[derive(Subcommand, Debug)]
pub enum Command {
    /// Log an event (used by shell integration)
    Log(LogArgs),

    /// Time-travel to a previous location
    Back(BackArgs),

    /// Search through activity history
    Search(SearchArgs),

    /// Show activity statistics
    Stats(StatsArgs),

    /// Show activity timeline
    Timeline(TimelineArgs),

    /// Add a note to your timeline
    Note(NoteArgs),

    /// Resume where you left off
    Resume,

    /// Show today's activity summary
    Today,

    /// List all sessions
    Sessions,

    /// Show project activity
    Projects,
}

#[derive(Args, Debug)]
pub struct LogArgs {
    /// Type of event to log
    #[arg(long)]
    pub event: Option<String>,

    /// Command that was executed
    #[arg(long)]
    pub cmd: Option<String>,

    /// Current working directory
    #[arg(long)]
    pub cwd: Option<String>,

    /// Project name (if known)
    #[arg(long)]
    pub project: Option<String>,

    /// Mark session start
    #[arg(long)]
    pub session_start: bool,

    /// Mark session end
    #[arg(long)]
    pub session_end: bool,

    /// Mark idle start
    #[arg(long)]
    pub idle_start: bool,

    /// Mark idle end
    #[arg(long)]
    pub idle_end: bool,
}

#[derive(Args, Debug)]
pub struct BackArgs {
    /// Time to travel back (e.g., "1h", "30m", "yesterday", "last-session")
    pub when: String,
}

#[derive(Args, Debug)]
pub struct SearchArgs {
    /// Search query
    pub query: String,

    /// Limit to today
    #[arg(long)]
    pub today: bool,

    /// Limit to specific project
    #[arg(long)]
    pub project: Option<String>,

    /// Limit to specific date (YYYY-MM-DD)
    #[arg(long)]
    pub date: Option<String>,
}

#[derive(Args, Debug)]
pub struct StatsArgs {
    /// Show stats for specific date range
    #[arg(long)]
    pub from: Option<String>,

    #[arg(long)]
    pub to: Option<String>,

    /// Show weekly stats
    #[arg(long)]
    pub week: bool,

    /// Show monthly stats
    #[arg(long)]
    pub month: bool,
}

#[derive(Args, Debug)]
pub struct TimelineArgs {
    /// Show timeline for today
    #[arg(long)]
    pub today: bool,

    /// Show timeline for yesterday
    #[arg(long)]
    pub yesterday: bool,

    /// Show timeline for specific date (YYYY-MM-DD)
    #[arg(long)]
    pub date: Option<String>,

    /// Limit number of entries
    #[arg(long, short = 'n', default_value = "50")]
    pub limit: usize,
}

#[derive(Args, Debug)]
pub struct NoteArgs {
    /// Note content
    pub text: String,
}
