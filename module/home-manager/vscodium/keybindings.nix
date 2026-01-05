let
  # Convert compact keybinding format to full format
  # Format: "command" = { key = "..."; when = "..."; replaces = "..."; };
  # - key: required
  # - when: optional, context to  which to restrict command usage
  # - replaces: optional, auto-generates unbinding for old command
  mkKeybinding =
    command: value:
    let
      key = value.key;
      when = value.when or null;
      replaces = value.replaces or null;

      mainBinding = {
        inherit command key;
      }
      // (if when != null then { inherit when; } else { });

      replaceBinding =
        if replaces != null then
          [
            {
              command = "-${replaces}";
              inherit key;
            }
          ]
        else
          [ ];
    in
    replaceBinding ++ [ mainBinding ];

  mkKeybindings =
    bindings: builtins.concatLists (builtins.attrValues (builtins.mapAttrs mkKeybinding bindings));

  keybindingData = {
    "openremotessh.openEmptyWindowInCurrentWindow" = {
      key = "ctrl+alt+o";
      replaces = "workbench.action.remote.showMenu";
    };

    "workbench.action.showCommands" = {
      key = "ctrl+p";
    };
    "workbench.action.quickOpen" = {
      key = "ctrl+o";
    };
    "workbench.action.createTerminalEditor" = {
      key = "ctrl+t";
    };
    "workbench.action.remote.showMenu" = {
      key = "ctrl+shift+alt+o";
    };
    "workbench.action.zoomReset" = {
      key = "ctrl+0";
      replaces = "workbench.action.focusSideBar";
    };
    "-workbench.action.zoomReset" = {
      key = "ctrl+numpad0";
    };
    "workbench.action.toggleLightDarkThemes" = {
      key = "ctrl+shift+l";
    };

    "explorer.newFile" = {
      key = "ctrl+n";
      replaces = "workbench.action.files.newUntitledFile";
    };
    "explorer.newFolder" = {
      key = "ctrl+shift+n";
      replaces = "workbench.action.newWindow";
    };

    "editor.action.insertLineAfter" = {
      key = "ctrl+enter";
    };
    "-editor.action.selectHighlights" = {
      key = "ctrl+shift+l";
      when = "editorFocus";
    };

    "-github.copilot.generate" = {
      key = "ctrl+enter";
      when = "editorTextFocus && github.copilot.activated && !commentEditorFocused && !inInteractiveInput && !interactiveEditorFocused";
    };

    "merge-conflict.next" = {
      key = "alt+pagedown";
      when = "!isMergeEditor";
    };
    "merge-conflict.previous" = {
      key = "alt+pageup";
    };

    "workbench.action.togglePanel" = {
      key = "ctrl+j";
      when = "panelFocus";
    };
    "workbench.action.terminal.focus" = {
      key = "ctrl+j";
      when = "!panelFocus";
    };
    "workbench.action.toggleAuxiliaryBar" = {
      key = "ctrl+shift+b";
      when = "roo-cline.SidebarProvider.active && !editorFocus && !terminalFocus";
    };
    "roo-cline.focusInput" = {
      key = "ctrl+shift+b";
      when = "editorFocus || terminalFocus || !textInputFocus";
    };
  };
in
mkKeybindings keybindingData
