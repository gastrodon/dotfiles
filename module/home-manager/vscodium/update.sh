#!/usr/bin/env bash
# Bump every extension in extensions.json to the newest open-vsx release, pre-releases included.
set -euo pipefail

dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
pins="$dir/extensions.json"
api=https://open-vsx.org/api
tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT
cp "$pins" "$tmp"

for id in $(jq -r 'keys[]' "$pins"); do
  pub="${id%%.*}"
  name="${id#*.}"

  platform=universal
  if curl -fsS "$api/$pub/$name" | jq -e '.downloads["linux-x64"]' >/dev/null; then
    platform=linux-x64
  fi

  latest="$(curl -fsS "$api/-/query?extensionId=$id&targetPlatform=$platform" | jq -c ".extensions[0] // empty | {version, url: .files.download}")"
  version="$(jq -r ".version // empty" <<<"$latest")"
  url="$(jq -r ".url // empty" <<<"$latest")"
  [[ -n "$version" ]] || { echo "$id: no release found" >&2; exit 1; }

  old="$(jq -r --arg id "$id" '.[$id].version // ""' "$pins")"
  if [[ "$old" == "$version" ]]; then
    echo "$id $version (current)"
    continue
  fi

  hash="$(nix --extra-experimental-features 'nix-command flakes' store prefetch-file --json --name "$id.vsix" "$url" | jq -r .hash)"
  jq --arg id "$id" --arg v "$version" --arg u "$url" --arg h "$hash" \
    '.[$id] = {version: $v, url: $u, hash: $h}' "$tmp" >"$tmp.new"
  mv "$tmp.new" "$tmp"
  echo "$id ${old:-none} -> $version"
done

cp "$tmp" "$pins"
