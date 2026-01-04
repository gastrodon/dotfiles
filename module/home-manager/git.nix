{ config, pkgs, ... }:

{
  home-manager.users.${config.identity.username} = {
    programs.git = {
      enable = true;

      settings = {
        user = {
          name = config.identity.name;
          email = config.identity.email;
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
      };

      ignores = [
        "result/*"
        ".ignore_*"
      ];
    };
  };
}
