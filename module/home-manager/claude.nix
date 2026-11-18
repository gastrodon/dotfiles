{
  pkgs,
  lib,
  claude-code-nix,
  ...
}:
let
  mkClaude = import ./claude-wrapper.nix { inherit pkgs lib; };

  claude = mkClaude {
    package = claude-code-nix.packages.${pkgs.stdenv.hostPlatform.system}.default;
    settings = {
      model = "sonnet";
      advisorModel = "fable";
      effortLevel = "medium";
      autoCompactWindow = 400000;
      enabledPlugins = {
        "gopls-lsp@claude-plugins-official" = true;
        "rust-analyzer-lsp@claude-plugins-official" = true;
      };
      attribution = {
        commit = "";
        pr = "🌴 Built with love in [South Carolina](https://sc.gov/visitors)";
      };
      env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS = "1";
      sandbox.enabled = false;

      autoMemoryEnabled = true;
      autoDreamEnabled = true;
      # Background jobs edit the real checkout and commit to main, not a worktree.
      worktree.bgIsolation = "none";
    };
  };

  # `claude rc` rejects the --settings and --mcp-config flags the wrapper injects (400 "Unknown argument"), so this execs bare upstream.
  claudeRc = pkgs.writeShellScriptBin "claude-rc" ''
    exec ${pkgs.lib.getExe claude-code-nix.packages.${pkgs.stdenv.hostPlatform.system}.default} rc "$@"
  '';

  desktopSshConfigs = (pkgs.formats.json { }).generate "claude-desktop-ssh-configs.json" [
    {
      id = "stone-lan";
      name = "stone (LAN)";
      sshHost = "stone";
    }
    {
      id = "stone-tailnet";
      name = "stone (tailnet)";
      sshHost = "stone-ts";
    }
  ];
in
{
  options.programs.claude.package = lib.mkOption {
    type = lib.types.package;
    readOnly = true;
    default = claude;
    description = "The claude wrapper: base settings plus profile drop-ins merged at launch.";
  };

  config.home.packages = [
    claude
    claudeRc
  ];

  # Claude Desktop reads sshConfigs from ~/.claude/settings.json, which Claude Code also
  # writes to; merge our key in instead of owning the file. Hosts resolve via ssh.nix.
  config.home.activation.claudeDesktopSshConfigs = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    settings="$HOME/.claude/settings.json"
    mkdir -p "$HOME/.claude"
    [ -f "$settings" ] || echo '{}' > "$settings"
    tmp=$(mktemp)
    ${pkgs.jq}/bin/jq --slurpfile c ${desktopSshConfigs} '.sshConfigs = $c[0]' "$settings" > "$tmp" \
      && mv "$tmp" "$settings"
  '';
}
