use clap::ValueEnum;
use serde::Serialize;

use crate::kv_ser;

#[derive(Debug, Clone, ValueEnum)]
pub enum OutputFormat {
    Text,
    Json,
}

pub trait Output: Serialize {
    fn render(&self, format: OutputFormat) where Self: Sized {
        match format {
            OutputFormat::Text => println!("{}", kv_ser::to_string(self).unwrap()),
            OutputFormat::Json => println!("{}", serde_json::to_string_pretty(&self).unwrap()),
        }
    }
}

impl<T: Serialize> Output for T {}
