# Wraps bao-kv-get with an on-disk TTL cache under ~/.cache/bao-kv-get, so
# shell-init-time secret fetches don't pay a live AppRole login (~500-600ms,
# largely bcrypt hashing the secret_id) on every single new terminal. Falls
# back to a stale cached value if Bao is unreachable, same "start clean"
# guarantee bao-kv-get itself gives.
#
# Usage: bao-kv-get-cached <path> <field> [ttl_seconds=86400]
{ pkgs, ... }:
let
  baoKvGet = import ./bao-kv-get.nix { inherit pkgs; };
in
pkgs.writeShellApplication {
  name = "bao-kv-get-cached";
  text = ''
    path="$1"
    field="$2"
    ttl="''${3:-86400}"

    cache_dir="''${XDG_CACHE_HOME:-$HOME/.cache}/bao-kv-get"
    mkdir -p "$cache_dir"
    chmod 700 "$cache_dir"
    cache_file="$cache_dir/''${path//\//_}_$field"

    if [[ -f "$cache_file" ]]; then
      age=$(( $(date +%s) - $(stat -c %Y "$cache_file") ))
      if (( age < ttl )); then
        cat "$cache_file"
        exit 0
      fi
    fi

    if value="$(${baoKvGet}/bin/bao-kv-get "$path" "$field" 2>/dev/null)" && [[ -n "$value" ]]; then
      tmp="$(mktemp "$cache_file.XXXXXX")"
      printf '%s' "$value" > "$tmp"
      mv -f "$tmp" "$cache_file"
      printf '%s\n' "$value"
    elif [[ -f "$cache_file" ]]; then
      cat "$cache_file"
    else
      echo "bao-kv-get-cached: $path $field unavailable and not cached" >&2
      exit 1
    fi
  '';
}
