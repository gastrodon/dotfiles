{ pkgs, ... }:
{
  programs.gh = {
    enable = true;

    settings = {
      version = "1";
      git_protocol = "ssh";
      editor = "";
      prompt = "enabled";
      prefer_editor_prompt = "disabled";
      pager = "less";
      aliases = { };
      http_unix_socket = "";
      browser = "firefox";
      color_labels = "enabled";
      accessible_colors = "disabled";
      accessible_prompter = "disabled";
      spinner = "enabled";
    };
  };
}
