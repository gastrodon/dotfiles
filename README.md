# Dotfiles with NixOS Configuration

This repository contains dotfiles and NixOS system configuration for a minimal i3-based desktop environment.

## Contents

### NixOS System Configuration

Core NixOS configuration files for system installation:

- **configuration.nix** - Main system configuration
- **hardware-configuration.nix** - Hardware and disk configuration
- **module/** - Modular configuration components:
  - **users.nix** - User account setup (eva user)
  - **x11.nix** - X Window System configuration
  - **i3.nix** - i3 window manager setup
- **BOOTSTRAP.md** - Complete installation guide

### Configuration Planning Documentation

Documentation for porting existing dotfiles to Nix modules:

- **zsh.nix.md** - ZSH shell configuration plan
- **x11.nix.md** - X11 resources configuration plan
- **i3.nix.md** - i3 window manager configuration plan
- **polybar.nix.md** - Polybar status bar configuration plan
- **git.nix.md** - Git configuration plan
- **vscodium.nix.md** - VSCodium editor configuration plan
- **gh.nix.md** - GitHub CLI configuration plan
- **packages.nix.md** - System packages configuration plan
- **local-bin.nix.md** - Local binaries configuration plan

### Existing Dotfiles

Traditional dotfiles that can be used alongside or migrated to Nix:

- **.zshrc** - ZSH configuration
- **.zprofile** - ZSH profile (auto-startx)
- **.xinitrc** - X initialization (starts i3)
- **.Xresources** - X resources (colors, fonts)
- **.gitconfig** - Git configuration
- **.config/** - Application configurations
  - **i3/** - i3 window manager config
  - **polybar/** - Polybar status bar config
  - **VSCodium/** - Editor settings
  - **gh/** - GitHub CLI config
  - **oh-my-zsh/** - Shell theme customization

## Quick Start

### Installing NixOS

For a fresh NixOS installation with this configuration:

1. Boot from NixOS installation media
2. Follow the detailed instructions in **BOOTSTRAP.md**
3. The result will be a minimal system with:
   - User "eva" (no password initially)
   - X11 graphical environment
   - i3 window manager
   - Basic utilities

### Using Dotfiles on Existing System

To use the traditional dotfiles on an existing system:

```bash
cd ~
git clone https://github.com/gastrodon/dotfiles.git
cd dotfiles
./link
```

This will symlink all dotfiles to your home directory.

## System Features

The minimal NixOS configuration provides:

✅ **Disk Setup** - Simple single-partition layout on /dev/sda  
✅ **Swap File** - Configurable swap file sized to match system RAM  
✅ **User Eva** - Unprivileged user with sudo access  
✅ **X11** - Graphical window system  
✅ **i3** - Tiling window manager  
✅ **Auto-start X** - Login triggers graphical environment  

### Not Yet Included

The following are documented but not yet implemented:
- ZSH shell configuration
- Polybar status bar
- VSCodium editor
- Full application suite
- Home Manager integration

These can be added incrementally by implementing the corresponding `.nix.md` plans.

## Configuration Architecture

The NixOS configuration uses a modular approach:

```
configuration.nix           # Main entry point
├── hardware-configuration.nix
└── module/
    ├── users.nix          # User accounts
    ├── x11.nix            # X Window System  
    └── i3.nix             # Window manager
```

Benefits:
- **Modular** - Easy to enable/disable features
- **Declarative** - System state defined in config files
- **Reproducible** - Same config = same system
- **Version controlled** - Track changes over time

## Next Steps

After basic installation:

1. **Security** - Set a password: `passwd`
2. **Networking** - Configure WiFi if needed
3. **Packages** - Add more packages to configuration.nix
4. **Shell** - Implement ZSH configuration from zsh.nix.md
5. **Home Manager** - Consider using Home Manager for user-level config
6. **Dotfiles** - Migrate more dotfiles to Nix modules

## Resources

- [NixOS Manual](https://nixos.org/manual/nixos/stable/)
- [Nix Package Search](https://search.nixos.org/)
- [Home Manager](https://github.com/nix-community/home-manager)
- [NixOS Wiki](https://nixos.wiki/)

## License

Personal dotfiles - use at your own discretion.
