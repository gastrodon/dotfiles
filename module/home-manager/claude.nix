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

      # A GUARDRAIL, NOT A BOUNDARY -- and the difference matters, so it is
      # written down rather than assumed.
      #
      # The agent runs as the `eva` OS user. sops looks for an age identity at
      # $HOME/.config/sops/age/keys.txt and finds eva's there -- the key that
      # is a recipient of every secrets file. So the agent can decrypt
      # everything, not by permission but by inheriting eva's identity whole.
      # (2026-09-21: it did exactly that, repeatedly, and printed plaintext.)
      #
      # This rule stops `sops` specifically. It does NOT stop anything else
      # that can read that file -- any shell command can cat the key and
      # decrypt by other means -- so it defends against habit and accident,
      # which is what actually went wrong, and against nothing deliberate.
      #
      # The real boundary is a different uid: the `claude` user exists
      # (module/claude-code.nix, no wheel, no sudo) but has no home-manager
      # profile or age identity of its own yet -- running the agent as that
      # user instead of eva isn't wired up, just no longer foreclosed.
      permissions.deny = [
        "Bash(sops:*)"
      ];
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
