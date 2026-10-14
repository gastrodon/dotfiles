{
  pkgs,
  identity,
  desktop,
  lib,
  ...
}:
{
  programs.git = {
    enable = true;

    settings = {
      user = {
        name = identity.name;
        email = identity.email;
      };

      core = {
        editor = "vim";
      };
      init = {
        defaultBranch = "main";
      };
      commit = {
        verbose = true;
      };
      diff = {
        wsErrorHighlight = "context,old";
      };
      branch = {
        sort = "-committerdate";
      };
      color = {
        ui = true;
      };
      url = lib.optionalAttrs desktop.hasPrivateKeys {
        "git@github.com:" = {
          insteadOf = "https://github.com/";
        };
      };

      credential = lib.optionalAttrs desktop.hasPrivateKeys {
        "http://192.168.0.17:3000" = {
          helper = lib.getExe pkgs.git-credential-gitea-vault;
        };
      };
    };

    ignores = [
      "result/*"
      ".ignore_*"
      ".claude/"
      "HANDOFF.md"
    ];
  };
}
