# ZSH Configuration Nix Module

## Overview
This module handles the ZSH shell configuration, including the main shell configuration, profile, and Oh-My-ZSH customizations.

## Files Encompassed
- `.zshrc` - Main ZSH configuration file with aliases, functions, environment variables, and shell options
- `.zprofile` - ZSH profile for auto-starting X server
- `.config/oh-my-zsh/` - Custom Oh-My-ZSH themes and configurations

## Module Location
`module/zsh.nix`

## Key Configuration Areas

### Environment Variables
- `ZSH` - Oh-My-ZSH installation path
- `DEVKITPRO`, `DEVKITARM`, `DEVKITPPC` - Development kit paths
- `EDITOR` - Default text editor (vim)
- `PATH` - Extended with local bin, cargo, go, and Android SDK paths
- `NVM_DIR` - Node Version Manager directory
- `DOTNET_CLI_TELEMETRY_OPTOUT` - .NET telemetry opt-out
- `RM_STAR_SILENT` - Disable ZSH removal warnings

### Shell Options
- `rm_star_silent` - Suppress confirmation for `rm *`

### Oh-My-ZSH Configuration
- Theme: liner
- Custom directory: `$HOME/.config/oh-my-zsh`

### Aliases
- `code` -> `codium` - VSCodium alias
- `aws` -> `python -m awscli` - AWS CLI via Python module

### Custom Functions
- `mkcd` - Create directory and cd into it
- `mkvenv` - Create Python virtual environment and activate
- `scrt` - Screenshot utility with Obsidian integration
- `fe` - Quick shell command editor
- `code-remote` - VSCodium remote connection helper
- Color functions (black, red, green, yellow, blue, magenta, cyan, white and their bright variants with background options)

## Home Manager Integration Points
- Programs.zsh for basic shell configuration
- Programs.oh-my-zsh for Oh-My-ZSH management
- Home.sessionVariables for environment variables
- Home.shellAliases for aliases
- Programs.zsh.initExtra for custom functions and setup scripts

## Dependencies
- zsh package
- oh-my-zsh
- vim (EDITOR)
- codium (VSCodium)
- Optional: nvm, cargo, go, Android SDK, python, awscli
- Optional: scrot, xdg-open for screenshot functionality

## Notes
- The Oh-My-ZSH liner theme needs to be available in the custom directory
- NVM initialization should be conditional on directory existence
- Custom functions should be preserved as-is in initExtra
- Consider extracting color functions to a separate helper module
- The .zprofile auto-startx functionality should be handled through display manager options or separate X11 module
