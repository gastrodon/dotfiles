{ pkgs, ... }:
pkgs.writeShellApplication {
  name = "bao-kv-get";
  runtimeInputs = [
    pkgs.curl
    pkgs.jq
  ];
  text = ''
    path="$1"
    field="$2"
    bao_addr="http://192.168.0.17:8200"
    role_id="d69434cc-bbc9-6aae-4220-c00744c6d005"
    secret_id="$(< /run/secrets/bao/claude_mcp_approle_secret_id)"

    client_token="$(curl -sf -X POST "$bao_addr/v1/auth/approle/login" \
      -d "{\"role_id\":\"$role_id\",\"secret_id\":\"$secret_id\"}" \
      | jq -r '.auth.client_token')"

    curl -sf -H "X-Vault-Token: $client_token" \
      "$bao_addr/v1/secret/data/$path" \
      | jq -r ".data.data.$field"
  '';
}
