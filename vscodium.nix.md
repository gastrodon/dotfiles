# VSCodium Configuration Nix Module

## Overview
This module manages VSCodium (the open-source build of Visual Studio Code) configuration, including editor settings, keybindings, extensions, and code snippets.

## Files Encompassed
- `.config/VSCodium/User/settings.json` - Editor settings and preferences
- `.config/VSCodium/User/keybindings.json` - Custom keyboard shortcuts
- `.config/VSCodium/User/extensions.json` - Extension recommendations and configuration
- `.config/VSCodium/User/snippets/` - Custom code snippets
  - `greek.code-snippets` - Greek character snippets

## Module Location
`module/vscodium.nix`

## Key Configuration Areas

### Editor Settings (settings.json)
- Theme and appearance customization
- Editor behavior (tab size, word wrap, etc.)
- Language-specific settings
- Extension configurations
- Integrated terminal settings
- Git integration settings
- File associations
- Formatting preferences

### Keybindings (keybindings.json)
- Custom keyboard shortcuts overriding defaults
- Command mappings
- Multi-cursor operations
- Navigation shortcuts

### Extensions (extensions.json)
- Recommended extensions for workspace
- Extension-specific settings
- Potentially a list of must-have extensions

### Code Snippets
- Greek characters snippet file for mathematical/scientific notation
- Custom snippets for frequent code patterns
- Language-specific snippet collections

## Home Manager Integration Points
- programs.vscode with vscodium package
- programs.vscode.enable for installation
- programs.vscode.package for specifying vscodium
- programs.vscode.userSettings for settings.json
- programs.vscode.keybindings for keybindings.json
- programs.vscode.extensions for managing extensions
- home.file for snippet files (since Home Manager doesn't directly manage snippets)

## Dependencies
- vscodium-bin or vscodium - The editor itself
- Extensions dependencies vary by extension
- Font packages for terminal and editor display
- Git for version control integration

## Notes
- The symbolic links created in the `link` script (.config/VSCodium - Insiders, Code - OSS) suggest compatibility handling for different VSCode/VSCodium installations
- These symlinks allow the configuration to work with multiple VSCode variants
- Extension management through Home Manager requires manual extension installation or using extensions list
- Consider using programs.vscode.extensions with specific extension IDs for reproducibility
- Snippet files need to be deployed via home.file since there's no direct Home Manager option
- Greek snippets suggest scientific or mathematical work
- Settings and keybindings should be reviewed for personal preferences that might need parameterization
- Some extensions may not be available in the Open VSX registry (VSCodium's extension marketplace)
- Consider documenting required extensions for full functionality
- Extension settings within settings.json need to match installed extensions
- The configuration might contain API keys or tokens in settings.json that should be handled securely
- Consider separating personal settings from general configuration
