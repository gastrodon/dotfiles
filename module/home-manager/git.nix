{ pkgs, identity, ... }:

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
}
