{ pkgs, lib, ... }:
let
  # Color map: name -> ANSI code
  colors = {
    black = "30";
    black-bg = "40";
    red = "31";
    red-bg = "41";
    green = "32";
    green-bg = "42";
    yellow = "33";
    yellow-bg = "43";
    blue = "34";
    blue-bg = "44";
    magenta = "35";
    magenta-bg = "45";
    cyan = "36";
    cyan-bg = "46";
    white = "37";
    white-bg = "47";

    "black!" = "90";
    "black-bg!" = "100";
    "red!" = "91";
    "red-bg!" = "101";
    "green!" = "92";
    "green-bg!" = "102";
    "yellow!" = "93";
    "yellow-bg!" = "103";
    "blue!" = "94";
    "blue-bg!" = "104";
    "magenta!" = "95";
    "magenta-bg!" = "105";
    "cyan!" = "96";
    "cyan-bg!" = "106";
    "white!" = "97";
    "white-bg!" = "107";
  };

  # Generate a color script for each color
  colorScripts = lib.mapAttrs (
    name: code:
    pkgs.writeShellScriptBin name ''
      echo -e "\e[${code}m$*\e[0m"
    ''
  ) colors;

in
{
  fe = pkgs.writeShellScriptBin "fe" ''
    # Edit and execute shell commands
    FE_SH_SESSION="$${FE_SH_SESSION:-/tmp/fe.sh}"

    # Create the file if it doesn't exist
    touch "$FE_SH_SESSION"

    # Open in editor
    $${EDITOR:-vim} "$FE_SH_SESSION"

    # Execute the contents
    if [ -f "$FE_SH_SESSION" ]; then
      eval "$(cat "$FE_SH_SESSION")"
    fi
  '';

  scrt = pkgs.writeShellScriptBin "scrt" ''
    disc="$1"
    if [[ "$disc" == "@obsidian" ]]; then
      shift
      f="$(${pkgs.coreutils}/bin/date +'%d-%m-%Y-%_H-%M-%S').png"

      ${pkgs.scrot}/bin/scrot --select --ignorekeyboard "$HOME/Documents/obsidian-vault/root/scrt/$f"
      ${pkgs.xdg-utils}/bin/xdg-open "obsidian://open?vault=root&file=scrt/$f"
    else
      shift
      f="$HOME/Pictures/scrot/$disc-$(${pkgs.coreutils}/bin/date +'%d-%m-%Y-%_H-%M-%S').png"
      ${pkgs.scrot}/bin/scrot --select --ignorekeyboard "$f"
      echo "$f"
    fi
  '';
}
// colorScripts
