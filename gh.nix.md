# GitHub CLI Configuration Nix Module

## Overview
This module manages the GitHub CLI (gh) tool configuration, including protocol preferences, editor selection, and behavior settings.

## Files Encompassed
- `.config/gh/config.yml` - GitHub CLI configuration file

## Module Location
`module/gh.nix`

## Key Configuration Areas

### Version
- Config schema version: 1

### Git Protocol
- Protocol: https (instead of ssh)
- Used for git operations through gh

### Editor
- Editor: codium (VSCodium)
- Used when creating issues, pull requests, etc.

### Prompt
- Interactive prompt: enabled
- Global setting for interactive confirmations

### Pager
- Pager: cat (disabled, shows full output without pagination)

### Aliases
- Currently empty, but structure exists for custom command aliases

### HTTP Settings
- Unix socket: not configured
- Uses default net/http.DefaultTransport

### Browser
- Not configured, will use environment default

## Home Manager Integration Points
- programs.gh.enable for GitHub CLI installation
- programs.gh.settings for declarative configuration
- programs.gh.settings.git_protocol for protocol choice
- programs.gh.settings.editor for editor preference
- programs.gh.settings.prompt for prompt behavior
- programs.gh.settings.pager for pager configuration
- programs.gh.extensions for gh extensions

## Dependencies
- gh - GitHub CLI tool
- git - For git operations
- codium (vscodium) - Configured editor
- Browser for opening URLs (uses system default)

## Notes
- HTTPS protocol is chosen over SSH, which affects authentication method
- Authentication requires GitHub token or credential helper
- Editor setting (codium) should align with VSCodium module
- Pager is disabled (set to 'cat'), showing full output immediately
- This is useful for scripting and piping output
- Aliases section is empty but available for future customization
- Consider adding useful aliases for common gh operations
- The configuration is minimal and straightforward
- Browser defaults to environment setting, no need to specify
- Prompt is enabled for safety, preventing accidental destructive operations
- Extensions can be managed through Home Manager's programs.gh.extensions
- Consider documenting authentication setup (gh auth login)
- The editor choice should be consistent with git editor and environment EDITOR
- Config schema version indicates compatibility with different gh versions
