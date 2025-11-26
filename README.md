# Nix Home-Manager Dotfiles

This branch contains a Nix flake that manages dotfiles using home-manager. It replaces the functionality of the `link` script with a declarative Nix configuration.

## Prerequisites

1. Install Nix with flakes enabled:
   ```bash
   sh <(curl -L https://nixos.org/nix/install) --daemon
   ```

2. Enable flakes by adding to `~/.config/nix/nix.conf` or `/etc/nix/nix.conf`:
   ```
   experimental-features = nix-command flakes
   ```

3. Install home-manager:
   ```bash
   nix run home-manager/master -- init
   ```

## Installation

1. Clone this repository:
   ```bash
   git clone https://github.com/gastrodon/dotfiles.git
   cd dotfiles
   git checkout nix
   ```

2. Apply the configuration:
   ```bash
   home-manager switch --flake .#default
   ```

   Or if you haven't installed home-manager standalone yet:
   ```bash
   nix run home-manager/master -- switch --flake .#default
   ```

## What This Does

The flake:
- Installs all packages listed in `.config/custom/packages` (ported to Nix)
- Configures ZSH with all functions, aliases, and settings from `.zshrc`
- Configures Git with settings from `.gitconfig`
- Symlinks all dotfiles to their correct locations in `$HOME`:
  - `.Xresources`, `.xinitrc`, `.zprofile`
  - `.config/i3/`, `.config/polybar/`, `.config/VSCodium/`, etc.
  - `.local/bin/` scripts
- Compiles the `bright.rs` Rust program and installs it to `.local/bin/bright`
- Creates compatibility symlinks for VSCodium

## Updating

After making changes to the flake or dotfiles:

```bash
home-manager switch --flake .#default
```

## Structure

- `flake.nix` - Main flake definition with inputs and outputs
- `home.nix` - Home-manager configuration with all settings and file mappings
- `TODO_NIX.md` - Documents items that don't map easily to Nix

## Comparison to `link` Script

The original `link` script:
- Auto-discovers all files and directories
- Compiles `.rs` files on the fly
- Creates symlinks manually

The Nix flake:
- Explicitly declares which files to manage (more declarative)
- Builds Rust programs during home-manager activation
- Uses home-manager's built-in file management
- Installs all required packages via Nix
- Provides reproducibility and rollback capabilities

## Notes

- See `TODO_NIX.md` for items that need manual setup or don't translate directly to Nix
- The flake pins exact versions of all packages for reproducibility
- You can roll back to previous configurations with `home-manager generations`
- Some system-specific paths (DevKitPro, Android SDK) are not managed by Nix

## Troubleshooting

If you encounter issues:

1. Check flake validity:
   ```bash
   nix flake check
   ```

2. Show what would be built:
   ```bash
   home-manager build --flake .#default
   ```

3. View home-manager generations:
   ```bash
   home-manager generations
   ```

4. Rollback to previous generation:
   ```bash
   home-manager rollback
   ```
