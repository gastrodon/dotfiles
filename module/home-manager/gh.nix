{ config, pkgs, ... }:
{
  home-manager.users.eva = {
    programs.gh = {
      enable = true;

      settings = {
        version = "1";
        git_protocol = "https";
        editor = "vim";
        prompt = "enabled";
        pager = "less";
        aliases = { };
      };
    };
  };
}
