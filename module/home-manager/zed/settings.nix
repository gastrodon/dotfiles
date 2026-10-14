{
  base_keymap = "VSCode";

  telemetry = {
    diagnostics = false;
    metrics = false;
  };
  auto_update = false;
  edit_predictions.provider = "none";

  ui_font_size = 16;
  buffer_font_family = "Fira Code";
  buffer_font_size = 15;
  buffer_font_features.calt = true;

  theme = {
    mode = "dark";
    light = "Solarized Light";
    dark = "Solarized Dark";
  };

  tab_size = 2;
  wrap_guides = [
    96
    120
  ];
  format_on_save = "on";
  ensure_final_newline_on_save = true;
  remove_trailing_whitespace_on_save = true;
  seed_search_query_from_cursor = "never";

  preview_tabs.enabled = false;
  restore_on_startup = "none";
  when_closing_with_no_tabs = "close_window";
  title_bar.show_menus = false;

  load_direnv = "shell_hook";
}
