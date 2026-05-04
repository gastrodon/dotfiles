{
  config,
  pkgs,
  lib,
  ...
}:
let
  # Fallout 4 Script Extender — targets runtime 1.10.163 (pre-Next-Gen)
  # F4SE 0.7.x (runtime 1.11.169, Next-Gen) is Nexus-only; update that manually.
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

  # Jackify — automates Wabbajack modlist installation on Linux.
  # Handles Wabbajack download, modlist install, Mod Organizer 2 setup, and
  # Steam shortcut/Proton prefix configuration. Requires Nexus Premium.
  #
  # Jackify uses system Python (not bundled); pycryptodome is an AUR-listed dep.
  # appimage-run provides both into the FHS environment the AppImage sees.
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

  # Pinned Wabbajack modlists.
  #
  # The .wabbajack manifest file is served via the Wabbajack CDN (requires the
  # client for auth) so it cannot be fetched with fetchurl. Instead we record
  # the version and Wabbajack content hash here as the source of truth.
  # To update: bump version + hash from https://github.com/wabbajack-tools/mod-lists/blob/master/modlists.json
  #
  # hash: xxHash64 (base64) that Wabbajack uses to verify the downloaded manifest.
  modlists = {
    lifeInTheRuins = {
      title = "Life in the Ruins";
      machineURL = "life_in_the_ruins";
      version = "8.1.0";
      hash = "bvv52v4pc7Y=";
    };
  };

  # Disables weapon debris in the Fallout 4 Proton prefix ini.
  # Weapon debris uses Nvidia FleX, which is unsupported on Turing (RTX 20xx+);
  # enabling it hard-crashes the game on the 2080 Super regardless of Proton version.
  # MO2 manages per-profile inis separately — disable it in-game after first launch too.
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

  # Prints the pinned modlist version and walks through the install steps.
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
  # Fallout 4 (Steam App ID: 377160)
  #
  # Proton: use GE-Proton — game Properties → Compatibility → enable → select GE-Proton
  # Launch options (with F4SE): f4se_loader.exe %command%
  # Launch options (without): gamemoderun mangohud %command%

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
