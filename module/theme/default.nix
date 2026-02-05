{ pkgs, ... }:
let
  theme-toggle = pkgs.writeShellScriptBin "theme-toggle" ''
    STATE_FILE="$HOME/.config/theme-state"
    VSCODIUM_SETTINGS="$HOME/.config/VSCodium/User/settings.json"
    GHOSTTY_CONFIG="$HOME/.config/ghostty/config"
    
    # Solarized Dark colors
    DARK_BG="002b36"
    DARK_FG="839496"
    DARK_BLACK="073642"
    DARK_RED="dc322f"
    DARK_GREEN="859900"
    DARK_YELLOW="b58900"
    DARK_BLUE="268bd2"
    DARK_MAGENTA="d33682"
    DARK_CYAN="2aa198"
    DARK_WHITE="eee8d5"
    DARK_BRIGHT_BLACK="586e75"
    DARK_BRIGHT_RED="cb4b16"
    DARK_BRIGHT_GREEN="586e75"
    DARK_BRIGHT_YELLOW="657b83"
    DARK_BRIGHT_BLUE="839496"
    DARK_BRIGHT_MAGENTA="6c71c4"
    DARK_BRIGHT_CYAN="93a1a1"
    DARK_BRIGHT_WHITE="fdf6e3"
    
    # Solarized Light colors
    LIGHT_BG="fdf6e3"
    LIGHT_FG="657b83"
    LIGHT_BLACK="eee8d5"
    LIGHT_RED="dc322f"
    LIGHT_GREEN="859900"
    LIGHT_YELLOW="b58900"
    LIGHT_BLUE="268bd2"
    LIGHT_MAGENTA="d33682"
    LIGHT_CYAN="2aa198"
    LIGHT_WHITE="073642"
    LIGHT_BRIGHT_BLACK="93a1a1"
    LIGHT_BRIGHT_RED="cb4b16"
    LIGHT_BRIGHT_GREEN="93a1a1"
    LIGHT_BRIGHT_YELLOW="839496"
    LIGHT_BRIGHT_BLUE="657b83"
    LIGHT_BRIGHT_MAGENTA="6c71c4"
    LIGHT_BRIGHT_CYAN="586e75"
    LIGHT_BRIGHT_WHITE="002b36"
    
    # Read current theme state
    if [ -f "$STATE_FILE" ]; then
      CURRENT=$(cat "$STATE_FILE")
    else
      CURRENT="dark"
    fi
    
    # Toggle theme
    if [ "$CURRENT" = "dark" ]; then
      NEW_THEME="light"
    else
      NEW_THEME="dark"
    fi
    
    echo "Switching from $CURRENT to $NEW_THEME theme..."
    
    # Update VSCodium theme
    update_vscodium_theme() {
      local theme=$1
      
      if [ "$theme" = "light" ]; then
        theme_name="Solarized Light"
      else
        theme_name="Solarized Dark"
      fi
      
      if [ -f "$VSCODIUM_SETTINGS" ]; then
        cp "$VSCODIUM_SETTINGS" "''${VSCODIUM_SETTINGS}.bak"
        
        if ${pkgs.jq}/bin/jq --arg theme "$theme_name" \
           '.["workbench.colorTheme"] = $theme' \
           "$VSCODIUM_SETTINGS" > "''${VSCODIUM_SETTINGS}.tmp"; then
          mv "''${VSCODIUM_SETTINGS}.tmp" "$VSCODIUM_SETTINGS"
          rm "''${VSCODIUM_SETTINGS}.bak"
        else
          mv "''${VSCODIUM_SETTINGS}.bak" "$VSCODIUM_SETTINGS"
          echo "ERROR: Failed to update VSCodium theme" >&2
        fi
      fi
    }
    
    # Update ghostty theme
    update_ghostty_theme() {
      local theme=$1
      local config_dir="$HOME/.config/ghostty"
      
      # Ensure directory exists
      mkdir -p "$config_dir"
      
      if [ "$theme" = "light" ]; then
        BG=$LIGHT_BG
        FG=$LIGHT_FG
        BLACK=$LIGHT_BLACK
        RED=$LIGHT_RED
        GREEN=$LIGHT_GREEN
        YELLOW=$LIGHT_YELLOW
        BLUE=$LIGHT_BLUE
        MAGENTA=$LIGHT_MAGENTA
        CYAN=$LIGHT_CYAN
        WHITE=$LIGHT_WHITE
        BRIGHT_BLACK=$LIGHT_BRIGHT_BLACK
        BRIGHT_RED=$LIGHT_BRIGHT_RED
        BRIGHT_GREEN=$LIGHT_BRIGHT_GREEN
        BRIGHT_YELLOW=$LIGHT_BRIGHT_YELLOW
        BRIGHT_BLUE=$LIGHT_BRIGHT_BLUE
        BRIGHT_MAGENTA=$LIGHT_BRIGHT_MAGENTA
        BRIGHT_CYAN=$LIGHT_BRIGHT_CYAN
        BRIGHT_WHITE=$LIGHT_BRIGHT_WHITE
      else
        BG=$DARK_BG
        FG=$DARK_FG
        BLACK=$DARK_BLACK
        RED=$DARK_RED
        GREEN=$DARK_GREEN
        YELLOW=$DARK_YELLOW
        BLUE=$DARK_BLUE
        MAGENTA=$DARK_MAGENTA
        CYAN=$DARK_CYAN
        WHITE=$DARK_WHITE
        BRIGHT_BLACK=$DARK_BRIGHT_BLACK
        BRIGHT_RED=$DARK_BRIGHT_RED
        BRIGHT_GREEN=$DARK_BRIGHT_GREEN
        BRIGHT_YELLOW=$DARK_BRIGHT_YELLOW
        BRIGHT_BLUE=$DARK_BRIGHT_BLUE
        BRIGHT_MAGENTA=$DARK_BRIGHT_MAGENTA
        BRIGHT_CYAN=$DARK_BRIGHT_CYAN
        BRIGHT_WHITE=$DARK_BRIGHT_WHITE
      fi
      
      cat > "$GHOSTTY_CONFIG" << EOF
# Ghostty configuration - Theme: $theme
font-family = Fira Code
font-size = 13

background = $BG
foreground = $FG

palette = 0=$BLACK
palette = 1=$RED
palette = 2=$GREEN
palette = 3=$YELLOW
palette = 4=$BLUE
palette = 5=$MAGENTA
palette = 6=$CYAN
palette = 7=$WHITE
palette = 8=$BRIGHT_BLACK
palette = 9=$BRIGHT_RED
palette = 10=$BRIGHT_GREEN
palette = 11=$BRIGHT_YELLOW
palette = 12=$BRIGHT_BLUE
palette = 13=$BRIGHT_MAGENTA
palette = 14=$BRIGHT_CYAN
palette = 15=$BRIGHT_WHITE
EOF
    }
    
    # Apply updates
    update_vscodium_theme "$NEW_THEME"
    update_ghostty_theme "$NEW_THEME"
    
    # Note: i3 colors are managed via NixOS configuration and require a rebuild
    # For now, just notify about the theme change
    
    # Save new state
    mkdir -p "$(dirname "$STATE_FILE")"
    echo "$NEW_THEME" > "$STATE_FILE"
    
    ${pkgs.libnotify}/bin/notify-send "Theme" "Switched to $NEW_THEME mode"
  '';
in
{
  environment.systemPackages = [ theme-toggle ];
}
