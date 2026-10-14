{
  pkgs,
  identity,
  desktop,
  lib,
  ...
}:
let
  giteaVaultCredentialHelper = pkgs.writeShellApplication {
    name = "git-credential-gitea-vault";
    runtimeInputs = [
      pkgs.curl
      pkgs.jq
    ];
    text = ''
      # git calls credential helpers with get/store/erase; only "get" needs a
      # real answer here, and git feeds fields on stdin regardless of verb.
      cat >/dev/null
      if [[ "''${1:-}" != "get" ]]; then
        exit 0
      fi

      vault_addr="http://192.168.0.17:8200"
      role_id="c0cf6549-2121-bfa3-e2e9-6c4ed46b9b8b"
      secret_file=/run/secrets/bao/gitea_approle_secret_id
      curl_opts=(-sf --connect-timeout 3 --max-time 10)
      fail() { echo "git-credential-gitea-vault: $*" >&2; exit 1; }

      secret_id="$(< "$secret_file")" || fail "cannot read $secret_file"

      # secret_id and token go over stdin / fd 3, never argv
      client_token="$(jq -n --arg r "$role_id" --arg s "$secret_id" '{role_id: $r, secret_id: $s}' \
        | curl "''${curl_opts[@]}" -X POST "$vault_addr/v1/auth/approle/login" --data @- \
        | jq -er '.auth.client_token')" || fail "AppRole login failed at $vault_addr"

      token="$(curl "''${curl_opts[@]}" --config /dev/fd/3 "$vault_addr/v1/secret/data/claude/gitea" \
        3< <(printf 'header = "X-Vault-Token: %s"\n' "$client_token") \
        | jq -er '.data.data.api_token')" || fail "no api_token at secret/claude/gitea"

      echo "username=claude"
      echo "password=$token"
    '';
  };
in
{
  programs.git = {
    enable = true;

    settings = {
      user = {
        name = identity.name;
        email = identity.email;
      };

      core = {
        editor = "vim";
      };
      init = {
        defaultBranch = "main";
      };
      commit = {
        verbose = true;
      };
      diff = {
        wsErrorHighlight = "context,old";
      };
      branch = {
        sort = "-committerdate";
      };
      color = {
        ui = true;
      };
      url = lib.optionalAttrs desktop.hasPrivateKeys {
        "git@github.com:" = {
          insteadOf = "https://github.com/";
        };
      };

      credential = lib.optionalAttrs desktop.hasPrivateKeys {
        "http://192.168.0.17:3000" = {
          helper = "${giteaVaultCredentialHelper}/bin/git-credential-gitea-vault";
        };
      };
    };

    ignores = [
      "result/*"
      ".ignore_*"
      ".claude/"
      "HANDOFF.md"
    ];
  };
}
