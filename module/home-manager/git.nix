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
        url = {
          "git@github.com:" = {
            insteadOf = "https://github.com/";
          };
        };
      };

      ignores = [
        "result/*"
        ".ignore_*"
      ];
    };
  };
}
