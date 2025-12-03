# System Packages Nix Module

## Overview
This module manages the list of system packages that should be installed. It represents the declarative package manifest for the system.

## Files Encompassed
- `.config/custom/packages` - List of packages to be installed

## Module Location
`module/packages.nix`

## Package List

### Development Tools
- `gcc` - GNU Compiler Collection
- `gcc-libs` - GCC runtime libraries
- `go` - Go programming language
- `rust` - Rust programming language
- `rust-src` - Rust source code (for development)
- `zig` - Zig programming language
- `git` - Version control system

### Shell and Terminal
- `zsh` - Z shell
- `oh-my-zsh-git` - Oh-My-ZSH framework (git version)

### Window Manager and Desktop
- `i3` - i3 tiling window manager
- `i3blocks` - Status bar for i3
- `i3lock` - Screen locker for i3
- `i3status` - Status generator for i3
- `autotiling` - Automatic tiling for i3
- `rofi` - Application launcher and window switcher

### Editors and Development
- `vim` - Text editor
- `vscodium-bin` - Open-source build of VS Code (binary)

### Applications
- `firefox` - Web browser
- `obsidian` - Note-taking application

### Network and Security
- `curl` - HTTP client
- `wget` - File downloader
- `openssh` - SSH client and server
- `openssl` - SSL/TLS toolkit
- `openvpn` - VPN client

### System Utilities
- `sudo` - Execute commands as superuser
- `less` - Pager for viewing text
- `sed` - Stream editor
- `jq` - JSON processor
- `ripgrep` - Fast text search tool
- `lsof` - List open files
- `unzip` - Archive extraction
- `zip` - Archive creation
- `tldr` - Simplified man pages

### Fonts
- `ttf-firacode` - FiraCode font with ligatures

## Home Manager Integration Points
- home.packages for user-level packages
- environment.systemPackages for system-level packages (if using NixOS)
- Multiple options for organizing packages:
  - Single list in packages.nix
  - Categorized by module (dev tools in dev.nix, window manager in i3.nix, etc.)
  - Mixed approach: common packages centralized, specialized packages in respective modules

## Dependencies
This module has no dependencies itself, but represents dependencies for other modules:
- ZSH module depends on zsh, oh-my-zsh-git
- i3 module depends on i3, i3blocks, i3lock, i3status, autotiling, rofi
- Git module depends on git
- VSCodium module depends on vscodium-bin
- Development workflows depend on language toolchains (gcc, go, rust, zig)

## Notes
- The package list uses Arch Linux package names (e.g., oh-my-zsh-git, vscodium-bin)
- These will need to be mapped to NixOS package names:
  - `oh-my-zsh-git` → `oh-my-zsh` (Nix typically uses stable versions)
  - `vscodium-bin` → `vscodium`
  - `ttf-firacode` → `fira-code`
- Consider grouping packages by purpose or module
- Some packages might be better managed by their specific modules:
  - i3-related packages in i3.nix
  - Development tools might go in a dev.nix module
  - Fonts might go in fonts.nix
- Package versions are not specified, will use whatever is in nixpkgs
- Consider whether packages should be system-wide or user-specific
- Some packages (like obsidian) might be unfree and require allowUnfree configuration
- This represents the minimal viable package set, actual system may have more packages
- Consider adding documentation comments in the actual Nix file explaining why each package is needed
- Package overlays or custom package definitions might be needed for some packages not in nixpkgs
- Update mechanism for packages is different in Nix (nixos-rebuild or home-manager switch)
