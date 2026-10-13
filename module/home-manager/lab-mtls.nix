# Client cert for WAN *.lab (LAB-182). Key and cert live only under ~/.local/share/lab-mtls; nothing here reads them at eval time.
{
  config,
  pkgs,
  lib,
  hostname,
  identity,
  ...
}:
let
  dir = "${config.home.homeDirectory}/.local/share/lab-mtls";
  cert = "${dir}/${hostname}.crt";
  key = "${dir}/${hostname}.key";
  nick = "lab-mtls-${hostname}";
  profile = "${config.home.homeDirectory}/${config.programs.firefox.configPath}/${
    config.programs.firefox.profiles.${identity.username}.path
  }";

  csr = pkgs.writeShellApplication {
    name = "lab-mtls-csr";
    runtimeInputs = [
      pkgs.openssl
      pkgs.coreutils
    ];
    text = ''
      umask 077
      mkdir -p -m 700 "${dir}"
      if [[ ! -e "${key}" ]]; then
        tmp="$(mktemp "${dir}/.key.XXXXXX")"
        trap 'rm -f "$tmp"' EXIT
        openssl genpkey -algorithm EC -pkeyopt ec_paramgen_curve:P-256 -out "$tmp"
        # ln refuses an existing target, so a racing key is never clobbered
        ln "$tmp" "${key}"
      fi
      chmod 600 "${key}"
      openssl req -new -key "${key}" -subj "/CN=${hostname}" -out "${dir}/${hostname}.csr"
      echo "CSR: ${dir}/${hostname}.csr"
    '';
  };

  firefoxImport = pkgs.writeShellApplication {
    name = "lab-mtls-firefox-import";
    runtimeInputs = [
      pkgs.openssl
      pkgs.nssTools
      pkgs.coreutils
    ];
    text = ''
      if [[ ! -r "${key}" || ! -r "${cert}" || ! -e "${profile}/cert9.db" ]]; then
        exit 0
      fi
      db="sql:${profile}"
      want="$(openssl x509 -in "${cert}" -noout -fingerprint -sha256 | cut -d= -f2)"
      if have="$(certutil -L -d "$db" -n "${nick}" -a 2>/dev/null | openssl x509 -noout -fingerprint -sha256 2>/dev/null | cut -d= -f2)"; then
        [[ "$have" == "$want" ]] && exit 0
        certutil -F -d "$db" -n "${nick}"
      fi
      umask 077
      tmp="$(mktemp -d "''${XDG_RUNTIME_DIR:-/tmp}/lab-mtls.XXXXXX")"
      trap 'rm -rf "$tmp"' EXIT
      openssl pkcs12 -export -inkey "${key}" -in "${cert}" -name "${nick}" -passout pass: -out "$tmp/p.p12"
      pk12util -i "$tmp/p.p12" -d "$db" -W "" -K ""
    '';
  };
in
{
  home.packages = [
    csr
    firefoxImport
    pkgs.rclone
  ];

  # rclone.conf stays out of the store; its s3.lab remote sets override.client_cert and override.client_key to these absolute paths
  programs.git.settings.http."https://git.lab.gastrodon.io/" = {
    sslCert = cert;
    sslKey = key;
  };

  home.activation.labMtlsFirefox = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run ${firefoxImport}/bin/lab-mtls-firefox-import
  '';
}
