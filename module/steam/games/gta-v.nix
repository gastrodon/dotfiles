{
  config,
  pkgs,
  lib,
  ...
}:
let
  # dev-c.com's mod_security rejects a bare "Mozilla/5.0" UA and hotlinked zips without a referer.
  ua = "Mozilla/5.0 (X11; Linux x86_64; rv:130.0) Gecko/20100101 Firefox/130.0";

  install-scripthookv = pkgs.writeShellScriptBin "install-scripthookv" ''
    set -euo pipefail

    if [[ $# -lt 1 ]]; then
      echo "usage: install-scripthookv <game-dir> [scripthookv-zip]" >&2
      echo "  with no zip, downloads the latest from dev-c.com" >&2
      exit 1
    fi

    game_dir=$1
    zip=''${2:-}
    work=$(mktemp -d)
    trap 'rm -rf "$work"' EXIT

    if [[ -z "$zip" ]]; then
      page=https://www.dev-c.com/gtav/scripthookv/
      url=$(${pkgs.curl}/bin/curl -fsSL -A '${ua}' "$page" \
        | ${pkgs.gnugrep}/bin/grep -oE '/files/ScriptHookV_[0-9.]+_[0-9.]+\.zip' \
        | head -1)
      echo "fetching https://www.dev-c.com$url"
      zip=$work/shv.zip
      ${pkgs.curl}/bin/curl -fsSL -A '${ua}' -e "$page" -o "$zip" "https://www.dev-c.com$url"
    fi

    ${pkgs.unzip}/bin/unzip -q "$zip" -d "$work/x"

    # bin/ ships ScriptHookV.dll, NativeTrainer.asi, args.txt (-nobattleye) and both asi loaders:
    # xinput1_4.dll (Enhanced) and dinput8.dll (Legacy).
    cp -f "$work/x/bin/"* "$game_dir/"
    rm -f "$game_dir/dsound.dll" # old asi loader, conflicts with dinput8.dll

    echo "installed Script Hook V into: $game_dir"
    echo "the Lutris game config needs wine.overrides: xinput1_4 and dinput8 = n,b"
  '';
in
{
  # GTA V (Rockstar Games Launcher, Enhanced) via Lutris; single-player only. Manual steps: ../README.md.
  environment.systemPackages = [
    pkgs.lutris
    pkgs.winetricks
    install-scripthookv
  ];
}
