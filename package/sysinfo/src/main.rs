mod cmd;
mod lib;

use clap::{Parser, Subcommand};
use lib::OutputFormat;

#[derive(Parser, Debug)]
#[command(name = "sysinfo")]
#[command(about = "System information utility", long_about = None)]
struct Cli {
    #[arg(long, value_enum, default_value = "text")]
    format: OutputFormat,

    #[command(subcommand)]
    command: Option<Commands>,
}

#[derive(Subcommand, Debug)]
enum Commands {
    Battery,
}

#[tokio::main]
async fn main() {
    let cli = Cli::parse();

    match cli.command {
        Some(Commands::Battery) => cmd::cmd_battery(cli.format).await.unwrap(),
        None => cmd::cmd_help(cli.format).await.unwrap(),
    };
}
