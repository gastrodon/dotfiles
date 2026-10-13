# tea — Gitea's official CLI, for talking to our own Gitea server (not for
# running one). tea has no credential-helper concept like git does: a token
# has to live in its own ~/.config/tea/config.yml. So we fetch the same
# claude/gitea Bao credential the git push helper uses (git.nix) - cached via
# bao-kv-get-cached.nix - and sync it into a tea login at shell start,
# backgrounded so it never blocks the prompt. Delete-then-add because `tea
# login edit` has no non-interactive way to change a login's token; add also
# fails if the login already exists, so any stale entry has to go first.
{ pkgs, lib, ... }:
let
  baoKvGetCached = import ./bao-kv-get-cached.nix { inherit pkgs; };

  giteaAddr = "http://192.168.0.17:3000";
  giteaLoginName = "gastrodon-gitea";

  teaGiteaSync = pkgs.writeShellApplication {
    name = "tea-gitea-login-sync";
    runtimeInputs = [ pkgs.tea ];
    text = ''
      token="$(${baoKvGetCached}/bin/bao-kv-get-cached claude/gitea api_token 86400 2>/dev/null)" || exit 0
      [[ -z "$token" ]] && exit 0

      marker="''${XDG_CACHE_HOME:-$HOME/.cache}/bao-kv-get/tea-gitea-synced-token"
      mkdir -p "$(dirname "$marker")"

      if [[ -f "$marker" ]] && [[ "$(cat "$marker")" == "$token" ]]; then
        exit 0
      fi

      tea login delete ${giteaLoginName} >/dev/null 2>&1 || true
      if tea login add --name ${giteaLoginName} --url ${giteaAddr} --token "$token" --no-version-check >/dev/null 2>&1; then
        printf '%s' "$token" > "$marker"
        chmod 600 "$marker"
      fi
    '';
  };
in
{
  home.packages = [ pkgs.tea ];

  programs.zsh.initContent = lib.mkOrder 550 ''
    ${teaGiteaSync}/bin/tea-gitea-login-sync >/dev/null 2>&1 &!
  '';
}
