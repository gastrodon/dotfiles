{ pkgs, ... }:
{
  fe = pkgs.writeShellScriptBin "fe" ''
    FE_SH_SESSION="$${FE_SH_SESSION:-/tmp/fe.sh}"
    touch "$FE_SH_SESSION"
    $${EDITOR:-vim} "$FE_SH_SESSION"
    if [ -f "$FE_SH_SESSION" ]; then
      eval "$(cat "$FE_SH_SESSION")"
    fi
  '';

  scrt = pkgs.writeShellScriptBin "scrt" ''
    disc="$1"
    shift
    f="$HOME/Pictures/scrot/$disc-$(${pkgs.coreutils}/bin/date +'%d-%m-%Y-%_H-%M-%S').png"
    ${pkgs.scrot}/bin/scrot --select --ignorekeyboard "$f"
    echo "$f"
  '';
}
