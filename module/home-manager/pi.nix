# pi — a separate coding-agent CLI (unrelated to Raspberry Pi hardware), packaged from
# earendil-works' standalone Linux x64 release tarball (Bun single-exec binary + sibling
# node_modules native addon + wasm asset — layout must stay intact, hence cp -r not select copies).
# pi-black is an unofficial package that routes pi's auth through a Claude subscription
# (OAuth) instead of API billing; ToS-gray, installed declaratively via settings.json.
#
# auth.json (~/.pi/agent/auth.json) is never touched here: `/login anthropic` is
# interactive and eva-only, and the resulting token is writable runtime state, not
# something sops/nix should own — same model as the Linear agent's own tokens.
{ pkgs, ... }:
let
  piVersion = "0.84.1";
  piBlackTag = "v0.84.1-cc2.1.224.4";

  # Yakitrak's Obsidian CLI, renamed notesmd-cli (upstream ceded the "obsidian-cli" name
  # to Obsidian's own official tool). Go binary, no running Obsidian app required — has
  # real content search (`notesmd-cli search-content`), unlike the app-URI-only original.
  notesmdCli = pkgs.buildGoModule {
    pname = "notesmd-cli";
    version = "0.3.6";
    src = pkgs.fetchFromGitHub {
      owner = "Yakitrak";
      repo = "notesmd-cli";
      rev = "v0.3.6";
      hash = "sha256-TubUNSpLvv3Q8dixeCf7otG6CSlb8haIGqkMFXAsqYI=";
    };
    vendorHash = null; # vendor/ directory ships in the repo
  };

  piPkg = pkgs.stdenv.mkDerivation {
    pname = "pi-coding-agent";
    version = piVersion;

    src = pkgs.fetchurl {
      url = "https://github.com/earendil-works/pi/releases/download/v${piVersion}/pi-linux-x64.tar.gz";
      sha256 = "5634d7ebd18274b63af3371e942f342d74bea012389575c1d1ff15ce6ca80c2f";
    };

    nativeBuildInputs = [ pkgs.autoPatchelfHook ];
    buildInputs = [ pkgs.stdenv.cc.cc.lib ]; # libgcc_s, for the clipboard native addon

    # Bun appends a payload after the ELF sections; stripping truncates it and breaks the binary.
    dontStrip = true;
    dontBuild = true;

    installPhase = ''
      runHook preInstall
      mkdir -p $out
      cp -r . $out/
      runHook postInstall
    '';
  };

  piSettings = (pkgs.formats.json { }).generate "pi-settings.json" {
    packages = [
      "git:github.com/paoloanzn/pi-black@${piBlackTag}"
    ];
  };

  # Global instructions, same role as CLAUDE.md — pi loads ~/.pi/agent/AGENTS.md at
  # startup (docs/usage.md). Nix is authoritative: overwritten on every launch, no
  # interactive editor writes here the way /settings does for settings.json.
  agentsFile = pkgs.writeText "pi-AGENTS.md" ''
    # Global instructions (stone)

    - Obsidian vault is at `~/notes` — plain markdown files, read/write directly. No REST API/MCP needed.
    - GitHub: use `gh` directly (already on PATH), not an MCP server.
    - server1/server2: use `ssh server1-agent` / `ssh server2-agent`, not `ssh server1`/`ssh server2` —
      these authenticate as `claude@`, matching the scoped access ssh-mcp already grants Claude Code,
      rather than eva's own login.
    - For searching/comprehending the vault (not just reading a known file), prefer
      `notesmd-cli search-content <query>` over grepping `~/notes` by hand.
    - This machine is NixOS: there's no ambient `apt`/`pip install`, and a binary missing
      from PATH (e.g. `python3`) usually just isn't installed rather than needing a package
      manager invocation. Reach for `, <command>` (comma, nix-community/comma) to run it
      once from nixpkgs without a permanent install — it's the fast path for one-off tools.
  '';

  # Re-asserts our declared packages/instructions on every launch, merging packages into
  # whatever settings.json already has (pi itself writes there via /settings and `pi install`)
  # rather than clobbering it. AGENTS.md has no interactive writer, so it's just overwritten.
  pi = pkgs.writeShellApplication {
    name = "pi";
    runtimeInputs = [
      pkgs.jq
      pkgs.git
      pkgs.ripgrep
      pkgs.nodejs_24
      pkgs.comma
    ];
    text = ''
      cfg="$HOME/.pi/agent"
      mkdir -p "$cfg"
      settings="$cfg/settings.json"
      [ -f "$settings" ] || echo '{}' > "$settings"
      tmp="$(mktemp)"
      jq --slurpfile d ${piSettings} '.packages = ((.packages // []) + $d[0].packages | unique)' "$settings" > "$tmp"
      mv "$tmp" "$settings"
      cp -f ${agentsFile} "$cfg/AGENTS.md"
      exec ${piPkg}/pi "$@"
    '';
  };
in
{
  home.packages = [
    pi
    notesmdCli
    pkgs.comma
  ];
}
