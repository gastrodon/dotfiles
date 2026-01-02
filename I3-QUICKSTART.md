# i3 Module Quick Start Guide

This guide helps you bootstrap a complete i3 window manager environment on a fresh NixOS installation.

## What's Included

The i3 module (`module/i3.nix`) provides a complete desktop environment with:

### Login & Locking
- **LightDM** - Graphical login manager (configured in `module/x11.nix`)
- **i3lock** - Screen locker (use `Mod+Shift+x` or configure your own keybinding)

### Application Launcher
- **rofi** - Primary application launcher (recommended)
  - Launch with `Mod+d` (default i3 keybinding)
  - Modern, feature-rich menu
- **dmenu** - Fallback launcher
  - Simple and lightweight

### Terminal
- **alacritty** - Primary terminal emulator (GPU-accelerated)
  - Launch with `Mod+Enter` (default i3 keybinding)
  - Set as default via `$TERMINAL` environment variable
- **xterm** - Fallback terminal

### Essential Components
- **i3status** - Default status bar
- **i3blocks** - Alternative status bar (optional)
- **feh** - Set wallpapers and view images
- **scrot** - Take screenshots
- **picom** - Compositor (optional, for transparency/shadows)
- **dunst** - Desktop notifications
- **pavucontrol** - Audio volume control GUI
- **networkmanagerapplet** - Network manager system tray
- **pcmanfm** - File manager

## Quick Installation

### 1. Import the modules

Add to your `configuration.nix`:

```nix
{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./module/users.nix    # User configuration
    ./module/x11.nix      # X server + LightDM
    ./module/i3.nix       # i3 window manager + desktop tools
  ];
  
  # ... rest of your configuration
}
```

### 2. Rebuild the system

```bash
sudo nixos-rebuild switch
```

### 3. Reboot

```bash
sudo reboot
```

### 4. Log in via LightDM

After reboot:
1. You'll see the LightDM login screen
2. Enter your username and password
3. Select "i3" from the session menu (top right corner)
4. Log in

## First Use

When you first start i3, it will ask:
1. **Generate config file?** - Press Enter to accept
2. **Choose modifier key** - Press Enter to use Win/Super key (recommended)

### Essential Keybindings

- `Mod+Enter` - Open terminal (alacritty)
- `Mod+d` - Open application launcher (rofi)
- `Mod+Shift+q` - Close focused window
- `Mod+Shift+e` - Exit i3
- `Mod+Shift+r` - Reload i3 config
- `Mod+Shift+c` - Restart i3
- `Mod+[1-9]` - Switch to workspace 1-9
- `Mod+Shift+[1-9]` - Move window to workspace 1-9

## Configuration

### i3 Configuration

Your i3 config will be automatically created at: `~/.config/i3/config`

To customize:
```bash
# Edit the config
nano ~/.config/i3/config

# Reload i3 to apply changes
Mod+Shift+r
```

### Set a Wallpaper

```bash
# Set wallpaper with feh
feh --bg-scale /path/to/wallpaper.jpg

# Make it persistent - add to i3 config:
echo "exec --no-startup-id feh --bg-scale /path/to/wallpaper.jpg" >> ~/.config/i3/config
```

### Enable Compositor (Optional)

For transparency and shadows, uncomment in `module/i3.nix`:

```nix
services.picom = {
  enable = true;
  fade = true;
  shadow = true;
  fadeDelta = 4;
};
```

Then rebuild: `sudo nixos-rebuild switch`

## Troubleshooting

### Terminal won't open
- Check if alacritty is installed: `which alacritty`
- Try xterm as fallback: `Mod+Enter` then type `xterm`
- Check i3 config for terminal keybinding

### No application launcher
- Press `Mod+d` for rofi
- If rofi doesn't work, try dmenu with `Mod+Shift+d` (if configured)

### Screen is blank after login
- Switch to TTY: `Ctrl+Alt+F2`
- Check X logs: `cat ~/.local/share/xorg/Xorg.0.log`
- Verify i3 is installed: `which i3`

### LightDM not showing up
- Check if X11 and LightDM are enabled in your config
- Verify services: `systemctl status display-manager`

### Audio not working
- Open pavucontrol: `pavucontrol`
- Check if volume is muted
- Verify PulseAudio is running: `systemctl --user status pulseaudio`

## Customization Tips

### Use your existing i3 config

Copy your existing config from your dotfiles:
```bash
cp /path/to/dotfiles/.config/i3/config ~/.config/i3/config
```

### Switch to i3blocks

Edit `~/.config/i3/config` and change:
```
bar {
    status_command i3blocks
}
```

### Add startup applications

Add to `~/.config/i3/config`:
```
exec --no-startup-id nm-applet              # Network manager tray
exec --no-startup-id dunst                  # Notifications
exec --no-startup-id picom                  # Compositor
exec --no-startup-id feh --bg-scale ~/wallpaper.jpg
```

## What's Not Included

These are available in the repository but need separate setup:
- **Firefox** - Use `module/firefox.nix`
- **Custom dotfiles** - Use the `./link` script from the repository
- **ZSH shell** - Documented in `zsh.nix.md`
- **Polybar** - Documented in `polybar.nix.md`

## Next Steps

1. **Customize i3** - Edit `~/.config/i3/config`
2. **Set wallpaper** - Use `feh` to set your favorite wallpaper
3. **Add more modules** - Import `module/firefox.nix` for web browser
4. **Configure applications** - Set up your dotfiles
5. **Learn i3** - Check the official guide: https://i3wm.org/docs/userguide.html
