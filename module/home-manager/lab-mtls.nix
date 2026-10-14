# Client cert for WAN *.lab (LAB-182). The key is generated in and never leaves the TPM (tpm2-pkcs11 token `lab-mtls`).
{
  config,
  osConfig,
  pkgs,
  lib,
  hostname,
  ...
}:
let
  token = "lab-mtls";
  dir = "${config.home.homeDirectory}/.local/share/lab-mtls";
  module = "${lib.getLib osConfig.security.tpm2.pkcs11.package}/lib/libtpm2_pkcs11.so";
  uri = type: "pkcs11:token=${token};object=${hostname};type=${type}";

  # 1.2.0 encodes named curves as explicit params, which Go's x509 rejects
  pkcs11-provider = pkgs.pkcs11-provider.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [
      (pkgs.fetchpatch {
        url = "https://github.com/latchset/pkcs11-provider/commit/3deadf97def44d6a55e622a098bd186fe8110289.patch";
        includes = [ "src/obj/export.c" ];
        hash = "sha256-AtCoJ2dWbTGFP2VWKfKnTUgX65HW2MYUkUg+/uMyQC0=";
      })
    ];
  });

  # tpm2-pkcs11 hangs when the provider offloads digests to a second session
  opensslConf = (pkgs.formats.iniWithGlobalSection { }).generate "lab-mtls-openssl.cnf" {
    globalSection.openssl_conf = "openssl_init";
    sections = {
      openssl_init.providers = "provider_sect";
      provider_sect = {
        default = "default_sect";
        pkcs11 = "pkcs11_sect";
      };
      default_sect.activate = 1;
      pkcs11_sect = {
        module = "${pkcs11-provider}/lib/ossl-modules/pkcs11.so";
        pkcs11-module-path = module;
        pkcs11-module-block-operations = "digest";
        activate = 1;
      };
    };
  };

  tools = [
    pkgs.opensc
    pkgs.openssl
    pkgs.coreutils
    pkgs.gnugrep
    pkgs.gawk
  ];

  common = ''
    export TSS2_LOG=fapi+NONE
    p11() { pkcs11-tool --module "${module}" "$@" 2>/dev/null; }
    have_key() { p11 --token-label "${token}" --list-objects --type pubkey --label "${hostname}" | grep -q "label: *${hostname}$"; }
  '';

  csr = pkgs.writeShellApplication {
    name = "lab-mtls-csr";
    runtimeInputs = tools;
    text = ''
      ${common}
      umask 077
      mkdir -p "${dir}"
      chmod 700 "${dir}"
      store="''${TPM2_PKCS11_STORE:-$HOME/.tpm2_pkcs11}"
      mkdir -p "$store"
      chmod -R go-rwx "$store"

      if ! p11 --list-token-slots | grep -q "token label *: ${token}$"; then
        slot="$(p11 --list-token-slots | awk '/^Slot/ { id = $3 } /token state: *uninitialized/ { print id; exit }' | tr -d '():')"
        [[ -n "$slot" ]] || { echo "no uninitialized tpm2-pkcs11 slot" >&2; exit 1; }
        echo "Initialising token ${token}."
        echo "SO PIN: generate a strong one and store it in Bitwarden now; it is only for init and unblock."
        echo "User PIN: the one you type in Firefox, git and lab-s3."
        pkcs11-tool --module "${module}" --slot "$slot" --init-token --label "${token}"
        pkcs11-tool --module "${module}" --token-label "${token}" --login --login-type so --init-pin
      fi

      if ! have_key; then
        pkcs11-tool --module "${module}" --token-label "${token}" --login \
          --keypairgen --key-type EC:prime256v1 --label "${hostname}" --id 01
      fi

      out="${dir}/${hostname}.csr"
      OPENSSL_CONF=${opensslConf} openssl req -new -key "${uri "private"}" -subj "/CN=${hostname}" -out "$out"
      openssl req -in "$out" -noout -verify
      openssl req -in "$out" -noout -text | grep -q "ASN1 OID: prime256v1" || { echo "CSR is not a named P-256 key" >&2; exit 1; }
      echo "CSR: $out"
      echo "SPKI sha256: $(openssl req -in "$out" -noout -pubkey | openssl pkey -pubin -outform der | sha256sum | cut -d' ' -f1)"
    '';
  };

  installCert = pkgs.writeShellApplication {
    name = "lab-mtls-install-cert";
    runtimeInputs = tools;
    text = ''
      ${common}
      crt="''${1:?usage: lab-mtls-install-cert <crt>}"
      have_key || { echo "no ${hostname} key in token ${token}; run lab-mtls-csr" >&2; exit 1; }
      tmp="$(mktemp -d)"
      trap 'rm -rf "$tmp"' EXIT
      p11 --token-label "${token}" --read-object --type pubkey --label "${hostname}" -o "$tmp/pub.der"
      want="$(openssl pkey -pubin -inform der -in "$tmp/pub.der" -outform der | sha256sum | cut -d' ' -f1)"
      got="$(openssl x509 -in "$crt" -noout -pubkey | openssl pkey -pubin -outform der | sha256sum | cut -d' ' -f1)"
      [[ "$want" == "$got" ]] || { echo "certificate does not match the TPM key" >&2; exit 1; }
      openssl x509 -in "$crt" -outform der -out "$tmp/crt.der"
      if p11 --token-label "${token}" --list-objects --type cert | grep -q "label: *${hostname}$"; then
        pkcs11-tool --module "${module}" --token-label "${token}" --login --delete-object --type cert --label "${hostname}"
      fi
      pkcs11-tool --module "${module}" --token-label "${token}" --login \
        --write-object "$tmp/crt.der" --type cert --label "${hostname}" --id 01
    '';
  };
  # credentials reach curl only through a pipe on fd 3, never argv, env or disk
  s3 = pkgs.writeShellApplication {
    name = "lab-s3";
    runtimeInputs = [ pkgs.curl ];
    text = ''
      [[ $# -gt 0 ]] || { echo "usage: lab-s3 [curl args...] https://s3.lab.gastrodon.io/<bucket>/<key>" >&2; exit 1; }
      read -rp "Garage access key id: " ak </dev/tty
      read -rsp "Garage secret key: " sk </dev/tty
      echo >&2
      esc() { local v="''${1//\\/\\\\}"; printf '%s' "''${v//\"/\\\"}"; }
      OPENSSL_CONF=${opensslConf} TSS2_LOG=fapi+NONE curl --config /dev/fd/3 \
        --aws-sigv4 "aws:amz:garage:s3" \
        --cert "${uri "cert"}" --cert-type PROV \
        --key "${uri "private"}" --key-type PROV \
        "$@" 3< <(printf 'user = "%s:%s"\n' "$(esc "$ak")" "$(esc "$sk")")
    '';
  };
in
{
  home.packages = [
    csr
    installCert
    s3
  ];

  programs.firefox.policies.SecurityDevices.Add.${token} = module;

  programs.git = {
    package = pkgs.symlinkJoin {
      name = "git-lab-mtls";
      paths = [
        pkgs.git
        pkgs.git.doc
      ];
      nativeBuildInputs = [ pkgs.makeWrapper ];
      # only the http(s) transport loads the pkcs11 provider; hooks, helpers and ssh do not
      postBuild = ''
        wrapProgram $out/libexec/git-core/git-remote-http --set OPENSSL_CONF ${opensslConf} --set TSS2_LOG fapi+NONE
        ln -sfn git-remote-http $out/libexec/git-core/git-remote-https
        wrapProgram $out/bin/git --set GIT_EXEC_PATH $out/libexec/git-core
      '';
    };
    settings.http."https://git.lab.gastrodon.io/" = {
      sslCert = uri "cert";
      sslCertType = "PROV";
      sslKey = uri "private";
      sslKeyType = "PROV";
    };
  };
}
