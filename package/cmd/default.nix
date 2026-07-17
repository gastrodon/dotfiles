{ pkgs, ... }:
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
