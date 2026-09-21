{
  pkgs,
  identity,
  desktop,
  lib,
  ...
}:
let
  # Fetches the gitea/claude_token KV secret from Vault via AppRole at the
  # moment git actually needs it — nothing cached to disk, nothing in the
  # Nix store but the (non-sensitive) role_id. secret_id comes from
  # /run/secrets/vault/gitea_approle_secret_id (module/claude-code.nix),
  # sops-decrypted at activation from secrets.yaml. See
  # vault-bootstrap-gitea-token.sh for how the AppRole itself was set up.
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

      vault_addr="http://192.168.0.58:8200"
      role_id="c0cf6549-2121-bfa3-e2e9-6c4ed46b9b8b"
      secret_id="$(< /run/secrets/vault/gitea_approle_secret_id)"

      client_token="$(curl -sf -X POST "$vault_addr/v1/auth/approle/login" \
        -d "{\"role_id\":\"$role_id\",\"secret_id\":\"$secret_id\"}" \
        | jq -r '.auth.client_token')"

      token="$(curl -sf -H "X-Vault-Token: $client_token" \
        "$vault_addr/v1/secret/data/gitea/claude_token" \
        | jq -r '.data.data.token')"

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
    ];
  };
}
