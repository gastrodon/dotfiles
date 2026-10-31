mod cmd;

use clap::{Parser, Subcommand};
use sys::OutputFormat;

#[derive(Parser, Debug)]
#[command(name = "sys")]
#[command(about = "System information utility", long_about = None)]
struct Cli {
    #[arg(long, value_enum, default_value = "text")]
    format: OutputFormat,

    #[command(subcommand)]
    command: Option<Commands>,
}

#[derive(Subcommand, Debug)]
enum Commands {
    Backlight(cmd::BacklightArgs),
    Battery,
}

#[tokio::main]
async fn main() {
    let cli = Cli::parse();

    match cli.command {
        Some(Commands::Backlight(args)) => cmd::cmd_backlight(cli.format, args.write).await,
        Some(Commands::Battery) => cmd::cmd_battery(cli.format).await,
        None => cmd::cmd_help(cli.format).await,
    }
    .unwrap();
}
