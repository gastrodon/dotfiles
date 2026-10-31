{
  writeShellApplication,
  jq,
  coreutils,
  findutils,
}:
writeShellApplication {
  name = "claude-config-merge";
  runtimeInputs = [
    jq
    coreutils
    findutils
  ];
  text = ''
    base=""
    out=""
    while [ $# -gt 0 ]; do
      case "$1" in
        --base) base="$2"; shift 2 ;;
        --out) out="$2"; shift 2 ;;
        *) echo "claude-config-merge: unknown argument $1" >&2; exit 2 ;;
      esac
    done
    if [ -z "$base" ] || [ -z "$out" ]; then
      echo "usage: claude-config-merge --base <settings.json> --out <dir>" >&2
      exit 2
    fi
    mkdir -p "$out"

    raw=()
    if [ -n "''${CLAUDE_CONFIG_MERGE_SHARE_DIRS:-}" ]; then
      IFS=: read -r -a raw <<< "$CLAUDE_CONFIG_MERGE_SHARE_DIRS"
    else
      IFS=: read -r -a raw <<< "''${XDG_DATA_DIRS:-}"
      raw+=("$HOME/.nix-profile/share" "$HOME/.local/state/nix/profiles/profile/share" "$HOME/.local/state/nix/profile/share")
    fi

    dirs=()
    declare -A seen_dir=()
    for d in "''${raw[@]}"; do
      [ -n "$d" ] && [ -d "$d" ] || continue
      r="$(realpath "$d")"
      [ -z "''${seen_dir[$r]:-}" ] || continue
      seen_dir[$r]=1
      dirs+=("$r")
    done

    declare -A seen_file=()
    collect() {
      local sub="$1" d f r
      for d in "''${dirs[@]}"; do
        [ -d "$d/claude/$sub" ] || continue
        while IFS= read -r f; do
          r="$(realpath "$f")"
          [ -z "''${seen_file[$sub:$r]:-}" ] || continue
          seen_file[$sub:$r]=1
          echo "$r"
        done < <(find "$d/claude/$sub" -maxdepth 1 \( -type f -o -type l \) -name '*.json' | LC_ALL=C sort)
      done
    }

    mapfile -t mcp_files < <(collect mcp.d)
    mapfile -t settings_files < <(collect settings.d)

    declare -A owner=()
    for f in "''${mcp_files[@]}"; do
      jq -e . "$f" >/dev/null || { echo "claude-config-merge: invalid JSON in $f" >&2; exit 1; }
      while IFS= read -r name; do
        if [ -n "''${owner[$name]:-}" ]; then
          echo "claude-config-merge: duplicate MCP server '$name' in ''${owner[$name]} and $f" >&2
          exit 1
        fi
        owner[$name]="$f"
      done < <(jq -r '.mcpServers // {} | keys[]' "$f")
    done
    for f in "$base" "''${settings_files[@]}"; do
      jq -e . "$f" >/dev/null || { echo "claude-config-merge: invalid JSON in $f" >&2; exit 1; }
    done

    chmod 700 "$out"
    tmp="$(mktemp -d "$out/.tmp.XXXXXX")"
    trap 'rm -rf "$tmp"' EXIT

    jq -s --arg mode settings -f ${./merge.jq} "$base" "''${settings_files[@]}" > "$tmp/settings.json"

    if [ "''${#mcp_files[@]}" -gt 0 ]; then
      jq -s --arg mode mcp -f ${./merge.jq} "''${mcp_files[@]}" > "$tmp/mcp.json.full"
      if [ "$(jq '. | length' "$tmp/mcp.json.full")" -gt 0 ]; then
        jq '{mcpServers: .}' "$tmp/mcp.json.full" > "$tmp/mcp.json"
      fi
      rm -f "$tmp/mcp.json.full"
    fi

    : > "$tmp/plugin-dirs"
    declare -A seen_plugin=()
    for d in "''${dirs[@]}"; do
      [ -d "$d/claude/plugins" ] || continue
      while IFS= read -r p; do
        [ -f "$p/.claude-plugin/plugin.json" ] || continue
        pname="$(jq -r .name "$p/.claude-plugin/plugin.json")"
        [ -z "''${seen_plugin[$pname]:-}" ] || continue
        seen_plugin[$pname]=1
        realpath "$p" >> "$tmp/plugin-dirs"
      done < <(find "$d/claude/plugins" -mindepth 1 -maxdepth 1 \( -type d -o -type l \) | LC_ALL=C sort)
    done

    rm -f "$out/mcp.json"
    for f in settings.json mcp.json plugin-dirs; do
      [ -e "$tmp/$f" ] && mv "$tmp/$f" "$out/$f"
    done
    exit 0
  '';
}
