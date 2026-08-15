{
  config,
  pkgs,
  lib,
  ...
}:
let
  # F4SE targets runtime 1.10.163 (pre-Next-Gen); 0.7.x for Next-Gen 1.11.169 is Nexus-only.
  f4se = pkgs.stdenv.mkDerivation {
    pname = "f4se";
    version = "0.6.23";
    src = pkgs.fetchurl {
      url = "https://github.com/ianpatt/f4se/releases/download/v0.6.23/f4se_0_06_23.7z";
      sha256 = "0772mpxpwihgldha2mh6q126w2i7nnpsya3f96c0bi4gd2xmnmrr";
    };
    nativeBuildInputs = [ pkgs.p7zip ];
    unpackPhase = "7z x $src";
    installPhase = ''
      mkdir -p $out
      cp f4se_0_06_23/f4se_loader.exe $out/
      cp f4se_0_06_23/f4se_1_10_163.dll $out/
      cp f4se_0_06_23/f4se_steam_loader.dll $out/
      cp -r f4se_0_06_23/Data $out/
    '';
  };

  # Jackify automates Wabbajack modlist installs (needs Nexus Premium). It expects system Python +
  # pycryptodome; appimage-run injects both into the AppImage's FHS env.
  jackify =
    let
      src = pkgs.fetchurl {
        url = "https://github.com/Omni-guides/Jackify/releases/download/v0.6.0.1/Jackify.AppImage";
        sha256 = "040zgy5s6ykkiyvhmvsmjay5fmq16axfkdqd0ypzi11h89kpwrcr";
      };
      python = pkgs.python3.withPackages (ps: [ ps.pycryptodome ]);
      runner = pkgs.appimage-run.override {
        extraPkgs = _: [
          python
          pkgs.zstd
        ];
      };
    in
    pkgs.writeShellScriptBin "jackify" ''
      exec ${runner}/bin/appimage-run ${src} "$@"
    '';

  # Pinned Wabbajack modlists. The .wabbajack manifest is CDN/auth-gated (no fetchurl), so we pin
  # version + Wabbajack content hash (xxHash64 base64) here.
  # Update: bump from https://github.com/wabbajack-tools/mod-lists/blob/master/modlists.json
  modlists = {
    lifeInTheRuins = {
      title = "Life in the Ruins";
      machineURL = "life_in_the_ruins";
      version = "8.1.0";
      hash = "bvv52v4pc7Y=";
    };
  };

  # bWeaponDebris=0 in the Proton prefix ini — FleX hard-crashes on the 2080 Super. Also disable in-game (MO2 inis are separate).
  disable-weapon-debris = pkgs.writeShellScriptBin "fo4-disable-weapon-debris" ''
    set -euo pipefail
    ini="$HOME/.local/share/Steam/steamapps/compatdata/377160/pfx/drive_c/users/steamuser/My Documents/My Games/Fallout4/Fallout4Prefs.ini"
    if [[ ! -f "$ini" ]]; then
      echo "Not found: $ini"
      echo "Launch Fallout 4 once to create the Proton prefix, then re-run."
      exit 1
    fi
    if grep -qi 'bWeaponDebris' "$ini"; then
      sed -i 's/bWeaponDebris=.*/bWeaponDebris=0/i' "$ini"
    else
      sed -i '/\[Display\]/a bWeaponDebris=0' "$ini"
    fi
    echo "bWeaponDebris=0 set in: $ini"
    echo "Also disable it in-game (Options → Display) so MO2 profile inis are updated."
  '';

  install-modlists = pkgs.writeShellScriptBin "install-fo4-modlists" ''
    echo "=== Fallout 4 modlist install ==="
    echo ""
    echo "Pinned modlists:"
    echo "  Life in the Ruins  v${modlists.lifeInTheRuins.version}  (${modlists.lifeInTheRuins.machineURL})"
    echo "  Wabbajack hash: ${modlists.lifeInTheRuins.hash}"
    echo ""
    echo "Steps:"
    echo "  1. Make sure Fallout 4 is installed in Steam and launched once"
    echo "  2. Run: install-f4se"
    echo "  3. Run: jackify --cli"
    echo "     Select: ${modlists.lifeInTheRuins.title}"
    echo "     Version should match: ${modlists.lifeInTheRuins.version}"
    echo "  4. Follow Jackify prompts — it downloads Wabbajack, the modlist,"
    echo "     installs MO2, and configures the Proton prefix"
    echo "  5. Launch the game through MO2 (Jackify creates a Steam shortcut)"
    echo ""
    echo "To update: bump version + hash in module/steam/games/fallout-4.nix"
    echo "  source: https://github.com/wabbajack-tools/mod-lists/blob/master/modlists.json"
  '';
in
{
  # Fallout 4 (Steam 377160). GE-Proton. Launch opts: `f4se_loader.exe %command%` with F4SE, else `gamemoderun mangohud %command%`.
  environment.systemPackages = [
    (pkgs.writeShellScriptBin "install-f4se" ''
      set -euo pipefail
      game_dir="''${1:-$HOME/.local/share/Steam/steamapps/common/Fallout 4}"
      echo "Installing F4SE to: $game_dir"
      cp -f ${f4se}/f4se_loader.exe "$game_dir/"
      cp -f ${f4se}/f4se_1_10_163.dll "$game_dir/"
      cp -f ${f4se}/f4se_steam_loader.dll "$game_dir/"
      mkdir -p "$game_dir/Data"
      cp -rf ${f4se}/Data/. "$game_dir/Data/"
      echo "Done. Set Steam launch option to: f4se_loader.exe %command%"
    '')
    jackify
    disable-weapon-debris
    install-modlists
  ];
}
