[
  {
    context = "Workspace";
    bindings = {
      "ctrl-p" = "command_palette::Toggle";
      "ctrl-o" = "file_finder::Toggle";
      "ctrl-t" = "agent::NewThread";
      "ctrl-shift-w" = "pane::CloseActiveItem";
      "ctrl-shift-o" = "multi_workspace::FocusWorkspaceSidebar";
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
      "alt-pagedown" = "multi_workspace::NextThread";
      "alt-pageup" = "multi_workspace::PreviousThread";
      "alt-end" = "multi_workspace::NextProject";
      "alt-home" = "multi_workspace::PreviousProject";
      "ctrl-w" = "git::Worktree";
      "ctrl-b" = "branches::OpenRecent";
      "alt-ctrl-shift-w" = null;
      "alt-ctrl-shift-b" = null;
    };
  }
  {
    # Editor binds alt-page{up,down} to editor::Page{Up,Down} and ctrl-shift-j to editor::JoinLines by default.
    context = "Editor";
    bindings = {
      "ctrl-shift-j" = "workspace::ToggleZoom";
      "alt-pagedown" = "multi_workspace::NextThread";
      "alt-pageup" = "multi_workspace::PreviousThread";
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
      "ctrl-shift-o" = "multi_workspace::FocusWorkspaceSidebar";
    };
  }
  {
    # Pane binds ctrl-w to pane::CloseActiveItem by default.
    context = "Pane";
    bindings."ctrl-w" = "git::Worktree";
  }
  {
    # A second ctrl+shift+o, now inside the sidebar, focuses its thread filter.
    context = "ThreadsSidebar";
    bindings."ctrl-shift-o" = "agents_sidebar::FocusSidebarFilter";
  }
  {
    context = "ProjectPanel";
    bindings = {
      "ctrl-n" = "project_panel::NewFile";
      "ctrl-shift-n" = "project_panel::NewDirectory";
    };
  }
]
