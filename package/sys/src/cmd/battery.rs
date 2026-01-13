use serde::Serialize;
use sys::{Output, OutputFormat};
use upower_dbus::BatteryState;

fn serialize_battery_state<S>(state: &BatteryState, serializer: S) -> Result<S::Ok, S::Error>
where
    S: serde::Serializer,
{
    serializer.serialize_str(&format!("{:?}", state).to_lowercase())
}

#[derive(Debug, Clone, Serialize)]
struct BatteryInfo {
    energy: f64,
    energy_cap: f64,
    percent: f64,
    voltage: f64,
    #[serde(serialize_with = "serialize_battery_state")]
    state: BatteryState,
    is_present: bool,
}

pub async fn cmd_battery(fmt: OutputFormat) -> Result<(), Box<dyn std::error::Error>> {
    let connection = zbus::Connection::system().await?;
    let upower = upower_dbus::UPowerProxy::new(&connection).await?;
    let device = upower.get_display_device().await?;

    BatteryInfo {
        energy: device.energy().await?,
        energy_cap: device.energy_full().await?,
        percent: device.percentage().await?,
        voltage: device.voltage().await?,
        state: device.state().await?,
        is_present: device.is_present().await?,
    }
    .render(fmt);

    Ok(())
}
