{ pkgs, ... }:
pkgs.writeShellApplication {
  name = "bao-kv-get";
  runtimeInputs = [
    pkgs.curl
    pkgs.jq
  ];
  text = ''
    [[ $# -eq 2 ]] || { echo "usage: bao-kv-get <path> <field>" >&2; exit 2; }
    path="$1"
    field="$2"
    bao_addr="''${BAO_ADDR:-http://192.168.0.17:8200}"
    role_id="d69434cc-bbc9-6aae-4220-c00744c6d005"
    secret_file="/run/secrets/bao/claude_mcp_approle_secret_id"

    secret_id="$(< "$secret_file")" || { echo "bao-kv-get: cannot read $secret_file" >&2; exit 1; }

    client_token="$(curl -sf -X POST "$bao_addr/v1/auth/approle/login" \
      -d "{\"role_id\":\"$role_id\",\"secret_id\":\"$secret_id\"}" \
      | jq -er '.auth.client_token')" || { echo "bao-kv-get: AppRole login failed at $bao_addr" >&2; exit 1; }

    value="$(curl -sf -H "X-Vault-Token: $client_token" "$bao_addr/v1/secret/data/$path" \
      | jq -er --arg f "$field" '.data.data[$f]')" || { echo "bao-kv-get: no $path field $field" >&2; exit 1; }

    printf '%s\n' "$value"
  '';
}
