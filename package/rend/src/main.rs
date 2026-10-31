mod cmd;

use clap::{Parser, Subcommand};

#[derive(Parser, Debug)]
#[command(name = "rend")]
#[command(about = "Rendering utility for visual representations", long_about = None)]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand, Debug)]
enum Commands {
    Bars(cmd::BarsArgs),
}

fn main() {
    let cli = Cli::parse();

    match cli.command {
        Commands::Bars(args) => cmd::cmd_bars(args),
    }
    .unwrap();
}
