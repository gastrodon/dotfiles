use clap::Args;
use serde::Serialize;
use std::fs;
use std::sync::OnceLock;
use sys::{Output, OutputFormat};

#[derive(Args, Debug)]
pub struct BacklightArgs {
    #[arg(short = 'w', long, allow_hyphen_values = true)]
    pub write: Option<String>,
}

const BACKLIGHT_PATH: &str = "/sys/class/backlight/intel_backlight";

static BRIGHT_CAP: OnceLock<f64> = OnceLock::new();

pub fn get_bright_cap() -> Result<f64, Box<dyn std::error::Error>> {
    if let Some(&cap) = BRIGHT_CAP.get() {
        return Ok(cap);
    }

    let cap = fs::read_to_string(format!("{}/max_brightness", BACKLIGHT_PATH))?
        .trim()
        .parse::<f64>()?;

    BRIGHT_CAP.set(cap).unwrap();
    Ok(cap)
}

pub fn get_bright_scale() -> Result<f64, Box<dyn std::error::Error>> {
    get_bright_cap().map(|v| v / 100.)
}

pub fn get_bright() -> Result<f64, Box<dyn std::error::Error>> {
    let bright = fs::read_to_string(format!("{}/actual_brightness", BACKLIGHT_PATH))?
        .trim()
        .parse::<f64>()?;
    Ok(bright)
}

fn compute_bright(arg: &str) -> Result<f64, Box<dyn std::error::Error>> {
    let current_bright = get_bright()?;
    let current_percentage = current_bright / get_bright_scale()?;

    let percentage = match arg.chars().next() {
        // +n%
        Some('+') => current_percentage + (arg[1..].parse::<f64>()?),
        // -n%
        Some('-') => current_percentage - arg[1..].parse::<f64>()?,
        // exact n%
        _ => arg.parse()?,
    };

    Ok(percentage)
}

#[derive(Debug, Clone, Serialize)]
struct BacklightStat {
    bright: f64,
    bright_cap: f64,
    percentage: f64,
}

async fn cmd_backlight_stat(fmt: OutputFormat) -> Result<(), Box<dyn std::error::Error>> {
    let bright = get_bright()?;
    let bright_cap = get_bright_cap()?;
    let percentage = bright / get_bright_scale()?;

    BacklightStat {
        bright,
        bright_cap,
        percentage,
    }
    .render(fmt);

    Ok(())
}

async fn cmd_backlight_write(
    fmt: OutputFormat,
    percentage: f64,
) -> Result<(), Box<dyn std::error::Error>> {
    if !(0.0..=100.0).contains(&percentage) {
        return Err(format!("Percentage must be in range [0, 100], got {}", percentage).into());
    }

    let bright_cap = get_bright_cap()?;
    let brightness = (percentage / 100.0) * bright_cap;

    fs::write(
        format!("{}/brightness", BACKLIGHT_PATH),
        format!("{}", brightness as u64),
    )
    .map_err(Into::into)
}

pub async fn cmd_backlight(
    fmt: OutputFormat,
    write: Option<String>,
) -> Result<(), Box<dyn std::error::Error>> {
    match write {
        Some(arg) => {
            let percentage = compute_bright(&arg)?;
            cmd_backlight_write(fmt, percentage).await
        }
        None => cmd_backlight_stat(fmt).await,
    }
}
