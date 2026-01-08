{ palette, ... }:
{
  programs.rofi = {
    enable = true;
    
    theme = {
      "*" = {
        background = palette.background;
        background-alt = palette.black;
        foreground = palette.brightBlue;
        selected = palette.blue;
        active = palette.cyan;
        urgent = palette.red;
        border = palette.blue;
        text = palette.brightWhite;
      };

      window = {
        background-color = "var(background)";
        border = "2px";
        border-color = "var(border)";
        padding = 20;
      };

      mainbox = {
        border = 0;
        padding = 0;
      };

      message = {
        border = "2px 0 0";
        border-color = "var(border)";
        padding = "1px";
      };

      textbox = {
        text-color = "var(foreground)";
      };

      listview = {
        fixed-height = 0;
        border = "2px 0 0";
        border-color = "var(border)";
        spacing = "2px";
        scrollbar = false;
        padding = "2px 0 0";
      };

      element = {
        border = 0;
        padding = "2px";
      };

      "element-text" = {
        background-color = "inherit";
        text-color = "inherit";
      };

      "element.normal.normal" = {
        background-color = "var(background)";
        text-color = "var(foreground)";
      };

      "element.normal.urgent" = {
        background-color = "var(urgent)";
        text-color = "var(text)";
      };

      "element.normal.active" = {
        background-color = "var(active)";
        text-color = "var(text)";
      };

      "element.selected.normal" = {
        background-color = "var(selected)";
        text-color = "var(text)";
      };

      "element.selected.urgent" = {
        background-color = "var(urgent)";
        text-color = "var(text)";
      };

      "element.selected.active" = {
        background-color = "var(active)";
        text-color = "var(text)";
      };

      "element.alternate.normal" = {
        background-color = "var(background-alt)";
        text-color = "var(foreground)";
      };

      "element.alternate.urgent" = {
        background-color = "var(urgent)";
        text-color = "var(text)";
      };

      "element.alternate.active" = {
        background-color = "var(active)";
        text-color = "var(text)";
      };

      scrollbar = {
        width = 0;
        border = 0;
        handle-width = 0;
        padding = 0;
      };

      "mode-switcher" = {
        border = "2px 0 0";
        border-color = "var(border)";
      };

      inputbar = {
        spacing = 0;
        text-color = "var(foreground)";
        padding = "2px";
        children = [ "prompt" "textbox-prompt-sep" "entry" "case-indicator" ];
      };

      "case-indicator, entry, prompt, button" = {
        spacing = 0;
        text-color = "var(foreground)";
      };

      "button.selected" = {
        background-color = "var(selected)";
        text-color = "var(text)";
      };

      "textbox-prompt-sep" = {
        expand = false;
        str = ":";
        text-color = "var(foreground)";
        margin = "0 0.3em 0 0";
      };
    };
  };
}
