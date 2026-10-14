[
  {
    context = "Workspace";
    bindings = {
      "ctrl-p" = "command_palette::Toggle";
      "ctrl-o" = "file_finder::Toggle";
      "ctrl-t" = "workspace::NewFile";
      "ctrl-shift-alt-o" = "projects::OpenRemote";
    };
  }
  {
    context = "Workspace || Editor || Terminal";
    bindings = {
      "ctrl-j" = "terminal_panel::Toggle";
      "ctrl-shift-l" = "theme_selector::Toggle";
    };
  }
  {
    context = "Editor && mode == full";
    bindings."ctrl-enter" = "editor::NewlineBelow";
  }
  {
    context = "ProjectPanel";
    bindings = {
      "ctrl-n" = "project_panel::NewFile";
      "ctrl-shift-n" = "project_panel::NewDirectory";
    };
  }
]
