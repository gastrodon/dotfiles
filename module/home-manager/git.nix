{ config, pkgs, ... }:

{
  home-manager.users.eva = {
    programs.git = {
      enable = true;

      settings = {
        user = {
          name = "eva";
          email = "mail@gastrodon.io";
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
