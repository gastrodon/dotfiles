[
  {
    context = "Workspace";
    bindings = {
      "ctrl-p" = "command_palette::Toggle";
      "ctrl-o" = "file_finder::Toggle";
      "ctrl-t" = "workspace::NewFile";
      "ctrl-shift-alt-o" = "projects::OpenRemote";
      "ctrl-alt-o" = [
        "projects::OpenRemote"
        {
          from_existing_connection = false;
          create_new_window = false;
        }
      ];
      "ctrl-j" = "terminal_panel::ToggleFocus";
      "ctrl-shift-j" = "workspace::ToggleZoom";
    };
  }
  {
    context = "Terminal";
    bindings."ctrl-j" = "workspace::ToggleBottomDock";
  }
  {
    context = "Editor && mode == full";
    bindings = {
      "ctrl-enter" = "editor::NewlineBelow";
      "ctrl-shift-j" = "workspace::ToggleZoom";
    };
  }
  {
    context = "ProjectPanel";
    bindings = {
      "ctrl-n" = "project_panel::NewFile";
      "ctrl-shift-n" = "project_panel::NewDirectory";
    };
  }
]
