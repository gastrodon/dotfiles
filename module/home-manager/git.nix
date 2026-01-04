{ config, pkgs, ... }:

{
  home-manager.users.${config.identity.username} = {
    programs.git = {
      enable = true;

      settings = {
        user = {
          name = config.identity.name;
          email = config.identity.email;
          signingKey = config.identity.email;
        };

        core = {
          editor = "vim";
        };
        init = {
          defaultBranch = "main";
        };
        commit = {
          verbose = true;
          gpgSign = true;
        };
        gpg = {
          format = "openpgp";
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
