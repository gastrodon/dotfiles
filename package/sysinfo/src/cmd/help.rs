use serde::Serialize;
use std::collections::HashMap;
use crate::lib::{Output, OutputFormat};

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

    tools.insert(
        "battery".to_string(),
        ToolInfo {
            name: "battery".to_string(),
            summary: "Display battery information from UPower".to_string(),
            flags: HashMap::new(),
        },
    );

    HelpInfo {
        name: "sysinfo".to_string(),
        version: env!("CARGO_PKG_VERSION").to_string(),
        summary: "A tool to provide information about the system".to_string(),
        tools,
    }.render(fmt);

    Ok(())
}
