use serde::Serialize;
use std::collections::HashMap;
use sys::{Output, OutputFormat};

#[derive(Debug, Serialize)]
pub struct FlagInfo {
    pub summary: String,
}

#[derive(Debug, Serialize)]
pub struct ToolInfo {
    pub name: String,
    pub summary: String,
    pub flags: HashMap<String, FlagInfo>,
}

#[derive(Debug, Serialize)]
pub struct HelpInfo {
    pub name: String,
    pub version: String,
    pub summary: String,
    pub tools: HashMap<String, ToolInfo>,
}

pub async fn cmd_help(fmt: OutputFormat) -> Result<(), Box<dyn std::error::Error>> {
    let mut tools = HashMap::new();

    let mut backlight_flags = HashMap::new();
    backlight_flags.insert(
        "-w, --write".to_string(),
        FlagInfo {
            summary: "Write brightness percentage: n (set to n%), +n (increase by n%), -n (decrease by n%)".to_string(),
        },
    );

    tools.insert(
        "backlight".to_string(),
        ToolInfo {
            name: "backlight".to_string(),
            summary: "Display backlight information (bright, bright_cap, percentage)".to_string(),
            flags: backlight_flags,
        },
    );

    tools.insert(
        "battery".to_string(),
        ToolInfo {
            name: "battery".to_string(),
            summary: "Display battery information from UPower (energy, energy_cap, percent, voltage, state, is_present)".to_string(),
            flags: HashMap::new(),
        },
    );

    HelpInfo {
        name: "sys".to_string(),
        version: env!("CARGO_PKG_VERSION").to_string(),
        summary: "A tool to provide information about the system".to_string(),
        tools,
    }.render(fmt);

    Ok(())
}
