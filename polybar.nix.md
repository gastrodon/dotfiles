# Polybar Configuration Nix Module

## Overview
This module manages the Polybar status bar configuration, which serves as an alternative to i3bar for displaying system information in a customizable and aesthetically pleasing way.

## Files Encompassed
- `.config/polybar/config` - Main polybar configuration file
- `.config/polybar/scripts/` - Directory containing status scripts:
  - `gen_battery.sh` - Battery status generation script
  - `gen_vpn.sh` - VPN status generation script
  - `gen_wifi.sh` - WiFi status generation script
  - Additional helper scripts for polybar modules

## Module Location
`module/polybar.nix`

## Key Configuration Areas

### Bar Configuration
- Bar name: `top`
- Monitor: Dynamic via environment variable `${env:MONITOR:}`
- Font: iosevka term ss04, size 10
- Position: top of screen
- Padding configuration

### Color Scheme
- Light purple (highlights): #B48EAD
- Light gray (separators): #444444
- Light red (muted/error states): #8E5A48

### Modules Layout
- Left: `workspaces` - i3 workspace indicator
- Right: `bt_device spacer wifi spacer volume spacer battery0 spacer date`

### Module Definitions

#### Built-in Modules
- `date` - Date and time display (format: HH:MM | MM-DD-YYYY)
- `volume` - PulseAudio volume control with bar visualization
  - Different colors for normal and muted states

#### Custom Script Modules
- `spacer` - Visual separator using pipe character (│)
- `battery0` - Battery status for primary battery
- `wifi` - WiFi connection status
- `vpn` - VPN connection status
- `bt_device` - Bluetooth device status (implied from layout)

### Script Integration
- Scripts generate formatted output with color codes
- Uses polybar formatting syntax (%{F#color}...%{F-})
- Scripts located in `.config/polybar/scripts/`

## Home Manager Integration Points
- services.polybar.enable for service management
- services.polybar.config for declarative configuration
- services.polybar.script for launch script
- services.polybar.package for polybar package selection
- home.file for deploying custom scripts
- systemd.user.services for polybar as a service

## Dependencies
- polybar - Status bar
- Font: iosevka term ss04
- pulseaudio or pipewire - For volume module
- NetworkManager - For WiFi status
- acpi or sysfs - For battery information
- Shell utilities (grep, awk, sed) for script processing
- Optional: openvpn or wireguard for VPN status
- Optional: bluetoothctl for Bluetooth device status

## Notes
- The configuration uses environment variable for monitor selection, useful for multi-monitor setups
- Color scheme follows a specific aesthetic (purple/gray theme)
- Scripts need to be executable and properly path-resolved
- Battery script takes a parameter (0) indicating which battery to monitor
- Consider whether this replaces i3bar or runs alongside it
- Module margins and spacing are carefully configured
- The bar is positioned at the top with custom padding
- Custom script modules provide flexibility but require maintenance
- Polybar's formatting syntax differs from i3bar, scripts are polybar-specific
- Scripts may need adjustment for different system configurations
- Consider whether to convert scripts to Nix expressions for better integration
- Ensure scripts handle missing dependencies gracefully
