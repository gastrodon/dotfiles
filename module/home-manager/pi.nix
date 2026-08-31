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
  hosts = import ../hosts.nix;
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

  piModels = (pkgs.formats.json { }).generate "pi-models.json" {
    providers.ollama = {
      baseUrl = "http://127.0.0.1:11434/v1";
      api = "openai-completions";
      apiKey = "ollama";
      compat = {
        supportsDeveloperRole = false;
        supportsReasoningEffort = false;
      };
      # qwen3:8b, not qwen2.5-coder:7b: the coder model emits tool calls as prose
      # JSON rather than a tool_calls field, so pi never executes anything.
      models = [
        {
          id = "qwen3:8b";
          name = "Qwen3 8B (Stone)";
          reasoning = true;
          # Must match OLLAMA_CONTEXT_LENGTH on stone: ollama truncates silently
          # rather than erroring, and pi only compacts if it thinks the window is full.
          contextWindow = 40960;
          maxTokens = 8192;
        }
      ];
    };
  };

  # Global instructions, same role as CLAUDE.md — pi loads ~/.pi/agent/AGENTS.md at
  # startup (docs/usage.md). Nix is authoritative: overwritten on every launch, no
  # interactive editor writes here the way /settings does for settings.json.
  # Kept vendor-neutral: naming Claude Code/MCP here led local models to answer as Claude.
  agentsFile = pkgs.writeText "pi-AGENTS.md" ''
    # Global instructions (stone)

    ## Tools

    You have four tools: `read`, `write`, `edit`, and `bash`. That is the whole surface —
    there are no plugins or external tool servers. Anything that is not reading, writing or
    editing a file is a shell command through `bash`: listing, searching, git, running
    programs, network calls.

    - Read a file with `read`, not `cat`. Change one with `edit`, not `sed -i` or a rewrite.
    - `read` returns the file's raw text. It contains no line numbers, so never put line
      numbers or `12:` style prefixes in `oldText` -- they will not match.
    - `read` a file immediately before you `edit` it. `oldText` must match the file byte for
      byte and must appear exactly once: if it is not unique, extend it with the lines above
      and below until it is, rather than retrying the same text.
    - `newText` must repeat everything `oldText` contained except the part being changed,
      including any heading or context lines you added to make it unique.
    - `write` is for new files and full rewrites only; prefer `edit` on files that exist.
    - Search with `rg` and find with `fd` inside `bash`.
    - Put independent shell work in a single `bash` call instead of many round trips.

    ## This machine

    - Obsidian vault is at `~/notes` — plain markdown files, read and edit them directly.
      To search the vault by meaning rather than open a file you already know, use
      `notesmd-cli search-content <query>` instead of grepping `~/notes` by hand.
    - GitHub: `gh` is on PATH and already authenticated.
    - server1/server2: `ssh -i /run/secrets/claude-ssh-privkey-local claude@${hosts.server1}`
      / `claude@${hosts.server2}` -- never eva's own login.
    - Web access: `web search <query>` (title/url/snippet per result) and `web fetch <url>`
      (a page's rendered text). Don't try to curl or browse DuckDuckGo/Google directly --
      both block automated access; use `web` instead.
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
  ];

  # This module is imported only by stone, so Pi's local Ollama provider never
  # appears on the Nomad/Linear worker hosts.
  home.file.".pi/agent/models.json".source = piModels;
}
