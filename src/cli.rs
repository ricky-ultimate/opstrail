use clap::{Args, Parser, Subcommand};

#[derive(Parser, Debug)]
#[command(name = "trail")]
#[command(author = "リッキー")]
#[command(version = "0.1.2")]
#[command(about = "Terminal activity time-machine", long_about = None)]
pub struct Cli {
    #[command(subcommand)]
    pub command: Command,
}

#[derive(Subcommand, Debug)]
pub enum Command {
    Log(LogArgs),
    Back(BackArgs),
    Search(SearchArgs),
    Stats(StatsArgs),
    Timeline(TimelineArgs),
    Note(NoteArgs),
    Resume,
    Today,
    Sessions,
    Projects,
    Config(ConfigArgs),
    Prune(PruneArgs),
}

#[derive(Args, Debug)]
pub struct LogArgs {
    #[arg(long)]
    pub event: Option<String>,

    #[arg(long)]
    pub cmd: Option<String>,

    #[arg(long)]
    pub cwd: Option<String>,

    #[arg(long)]
    pub project: Option<String>,

    #[arg(long)]
    pub session_start: bool,

    #[arg(long)]
    pub session_end: bool,

    #[arg(long)]
    pub idle_start: bool,

    #[arg(long)]
    pub idle_end: bool,
}

#[derive(Args, Debug)]
pub struct BackArgs {
    pub when: String,
}

#[derive(Args, Debug)]
pub struct SearchArgs {
    pub query: String,

    #[arg(long)]
    pub today: bool,

    #[arg(long)]
    pub project: Option<String>,

    #[arg(long)]
    pub date: Option<String>,
}

#[derive(Args, Debug)]
pub struct StatsArgs {
    #[arg(long)]
    pub from: Option<String>,

    #[arg(long)]
    pub to: Option<String>,

    #[arg(long)]
    pub week: bool,

    #[arg(long)]
    pub month: bool,
}

#[derive(Args, Debug)]
pub struct TimelineArgs {
    #[arg(long)]
    pub today: bool,

    #[arg(long)]
    pub yesterday: bool,

    #[arg(long)]
    pub date: Option<String>,

    #[arg(long, short = 'n', default_value = "50")]
    pub limit: usize,
}

#[derive(Args, Debug)]
pub struct NoteArgs {
    pub text: String,
}

#[derive(Args, Debug)]
pub struct ConfigArgs {
    #[command(subcommand)]
    pub subcommand: ConfigSubcommand,
}

#[derive(Subcommand, Debug)]
pub enum ConfigSubcommand {
    Show,
    Set(ConfigSetArgs),
}

#[derive(Args, Debug)]
pub struct ConfigSetArgs {
    pub key: String,
    pub value: String,
}

#[derive(Args, Debug)]
pub struct PruneArgs {
    #[arg(long, default_value = "90")]
    pub keep_days: u64,

    #[arg(long)]
    pub dry_run: bool,
}
