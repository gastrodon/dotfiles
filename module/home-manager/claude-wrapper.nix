{ pkgs, lib }:
{
  settings,
  package,
}:
let
  baseSettings = (pkgs.formats.json { }).generate "claude-base-settings.json" settings;
in
pkgs.writeShellScriptBin "claude" ''
  dir="''${XDG_RUNTIME_DIR:-}"
  if [ -d "$dir" ]; then
    dir="$dir/claude"
    mkdir -p "$dir"
  else
    dir="$(mktemp -d)"
  fi
  ${lib.getExe pkgs.claude-config-merge} --base ${baseSettings} --out "$dir" || exit 1
  args=(--settings "$dir/settings.json")
  if [ -e "$dir/mcp.json" ]; then
    args+=(--mcp-config "$dir/mcp.json")
  fi
  while IFS= read -r p; do
    args+=(--plugin-dir "$p")
  done < "$dir/plugin-dirs"
  exec ${lib.getExe package} "''${args[@]}" "$@"
''
