use serde::Serialize;
use crate::lib::{Output, OutputFormat};
use upower_dbus::{BatteryState, DeviceProxy};

fn serialize_battery_state<S>(state: &BatteryState, serializer: S) -> Result<S::Ok, S::Error>
where
    S: serde::Serializer,
{
    serializer.serialize_str(&format!("{:?}", state).to_lowercase())
}

#[derive(Debug, Clone, Serialize)]
pub struct BatteryInfo {
    energy: f64,
    energy_full: f64,
    voltage: f64,
    #[serde(serialize_with = "serialize_battery_state")]
    state: BatteryState,
    percentage: f64,
    is_present: bool,
}

impl BatteryInfo {
    pub async fn from_device(device: &DeviceProxy<'_>) -> Result<Self, Box<dyn std::error::Error>> {
        Ok(Self {
            energy: device.energy().await?,
            energy_full: device.energy_full().await?,
            voltage: device.voltage().await?,
            state: device.state().await?,
            percentage: device.percentage().await?,
            is_present: device.is_present().await?,
        })
    }
}

pub async fn cmd_battery(fmt: OutputFormat) -> Result<(), Box<dyn std::error::Error>> {
    let connection = zbus::Connection::system().await?;
    let upower = upower_dbus::UPowerProxy::new(&connection).await?;
    let device = upower.get_display_device().await?;

    BatteryInfo::from_device(&device).await?.render(fmt);
    Ok(())
}
