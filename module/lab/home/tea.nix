# tea has no credential helper, so a user timer syncs the claude/gitea Bao token into a tea login.
# Delete-then-add: `tea login edit` cannot change a token non-interactively.
{ pkgs, lib, ... }:
let
  giteaAddr = "http://192.168.0.17:3000";
  giteaLoginName = "gastrodon-gitea";

  teaGiteaSync = pkgs.writeShellApplication {
    name = "tea-gitea-login-sync";
    runtimeInputs = [
      pkgs.tea
      pkgs.coreutils
    ];
    text = ''
      token="$(${lib.getExe pkgs.bao-kv-get-cached} claude/gitea api_token 86400 2>/dev/null)" || exit 0
      [[ -z "$token" ]] && exit 0

      marker="''${XDG_CACHE_HOME:-$HOME/.cache}/bao-kv-get/tea-gitea-synced-sha256"
      mkdir -p "$(dirname "$marker")"
      digest="$(printf '%s' "$token" | sha256sum | cut -d' ' -f1)"

      if [[ -f "$marker" ]] && [[ "$(< "$marker")" == "$digest" ]]; then
        exit 0
      fi

      tea login delete ${giteaLoginName} >/dev/null 2>&1 || true
      if tea login add --name ${giteaLoginName} --url ${giteaAddr} --token "$token" --no-version-check >/dev/null 2>&1; then
        printf '%s' "$digest" > "$marker"
      fi
    '';
  };
in
{
  home.packages = [ pkgs.tea ];

  systemd.user.services.tea-gitea-login-sync = {
    Unit.Description = "Sync the Bao Gitea token into tea's login";
    Service = {
      Type = "oneshot";
      ExecStart = lib.getExe teaGiteaSync;
    };
  };

  systemd.user.timers.tea-gitea-login-sync = {
    Unit.Description = "Keep tea's Gitea login current";
    Timer = {
      OnStartupSec = "30s";
      OnUnitActiveSec = "1h";
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
