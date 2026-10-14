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
    curl_opts=(-sf --connect-timeout 3 --max-time 10)

    secret_id="$(< "$secret_file")" || { echo "bao-kv-get: cannot read $secret_file" >&2; exit 1; }

    # secret_id and token go over stdin / fd 3, never argv
    client_token="$(jq -n --arg r "$role_id" --arg s "$secret_id" '{role_id: $r, secret_id: $s}' \
      | curl "''${curl_opts[@]}" -X POST "$bao_addr/v1/auth/approle/login" --data @- \
      | jq -er '.auth.client_token')" || { echo "bao-kv-get: AppRole login failed at $bao_addr" >&2; exit 1; }

    body="$(curl "''${curl_opts[@]}" --config /dev/fd/3 "$bao_addr/v1/secret/data/$path" \
      3< <(printf 'header = "X-Vault-Token: %s"\n' "$client_token"))" \
      || { echo "bao-kv-get: cannot read secret/$path at $bao_addr" >&2; exit 1; }

    value="$(jq -er --arg f "$field" '.data.data[$f]' <<<"$body")" \
      || { echo "bao-kv-get: secret/$path has no field $field" >&2; exit 1; }

    printf '%s\n' "$value"
  '';
}
