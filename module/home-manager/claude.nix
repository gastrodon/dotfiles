{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.programs.claude;
  fmt = pkgs.formats.json { };

  mcpConfigFile = fmt.generate "claude-mcp-config.json" {
    mcpServers = cfg.mcpServers;
  };

  settingsFile = fmt.generate "claude-settings.json" cfg.settings;

  extraArgs = lib.concatStringsSep " " (
    [ "--mcp-config ${mcpConfigFile}" ]
    ++ lib.optional (cfg.settings != { }) "--settings ${settingsFile}"
    ++ lib.optional cfg.strictMcp "--strict-mcp-config"
  );

  wrappedClaude = pkgs.writeShellScriptBin "claude" ''
    exec ${lib.getExe cfg.package} ${extraArgs} "$@"
  '';
in
{
  options.programs.claude = {
    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.claude-code;
    };

    mcpServers = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = { };
      description = "MCP server definitions passed via --mcp-config.";
    };

    settings = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = { };
      description = "Claude settings passed via --settings.";
    };

    strictMcp = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "When true, only Nix-defined MCP servers are used (--strict-mcp-config).";
    };
  };

  config = {
    home.packages = [ wrappedClaude ];
    programs.zsh.shellAliases.c = "claude";
  };
}
