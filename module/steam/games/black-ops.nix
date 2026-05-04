{
  config,
  pkgs,
  lib,
  ...
}:
let
  wine = pkgs.wineWow64Packages.staging;

  plutonium-exe = pkgs.fetchurl {
    url = "https://cdn.plutonium.pw/updater/plutonium.exe";
    hash = "sha256-hdHRyk1Ygdm5iSjCAG+w7sllXicF/nQIjm+XShlwPw8=";
  };

  plutonium-setup = pkgs.writeShellScriptBin "plutonium-setup" ''
    set -euo pipefail

    WINEPREFIX="''${WINEPREFIX:-$HOME/.wine-plutonium}"
    export WINEARCH=win64
    export WINEPREFIX
    export WINE="${wine}/bin/wine"
    export WINESERVER="${wine}/bin/wineserver"

    sentinel="$WINEPREFIX/.setup-done"

    if [[ -f "$sentinel" ]]; then
      echo "prefix already set up at $WINEPREFIX — delete $sentinel to redo"
      exit 0
    fi

    echo "initializing Wine prefix..."
    "${wine}/bin/wineboot" --init

    echo "installing dependencies (this takes a while)..."
    "${pkgs.winetricks}/bin/winetricks" --unattended \
      corefonts \
      vcrun2005 vcrun2008 vcrun2012 vcrun2019 \
      d3dcompiler_42 d3dcompiler_43 d3dcompiler_47 \
      xact xact_x64 xinput

    touch "$sentinel"

    echo ""
    echo "setup complete. launch Plutonium with:"
    echo "  plutonium"
  '';

  plutonium = pkgs.writeShellScriptBin "plutonium" ''
    set -euo pipefail

    export WINEARCH=win64
    export WINEPREFIX="''${WINEPREFIX:-$HOME/.wine-plutonium}"
    export DXVK_CONFIG="dxvk.numCompilerThreads=2"

    launcher="$WINEPREFIX/drive_c/users/$USER/AppData/Local/Plutonium/bin/plutonium-launcher-win32.exe"

    if [[ -f "$launcher" ]]; then
      exec "${wine}/bin/wine" "$launcher"
    else
      exec "${wine}/bin/wine" "${plutonium-exe}"
    fi
  '';
in
{
  # Call of Duty: Black Ops 1 (Steam App ID: 42700)
  #
  # Steam (vanilla):
  #   Proton: GE-Proton (Proton 5.0 fails CEG DRM; GE-Proton passes it)
  #   Launch options: MANGOHUD=1 gamemoderun %command%
  #   Controller: Steam Input ON for GCN adapter
  #
  # Plutonium (community client, T5 — bypasses CEG DRM entirely):
  #   1. Register at plutonium.pw
  #   2. Run `plutonium-setup` once to initialize the Wine prefix
  #   3. Run `plutonium` to launch (exe is fetched declaratively from cdn.plutonium.pw)
  #   Game files: ~/.local/share/Steam/steamapps/common/Call of Duty Black Ops

  environment.systemPackages = [
    wine
    pkgs.winetricks
    plutonium-setup
    plutonium
  ];
}
