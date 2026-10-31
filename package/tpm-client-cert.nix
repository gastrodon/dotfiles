# Client-cert tooling for a TPM-held key (tpm2-pkcs11 token): `tpm-client-cert csr`, `tpm-client-cert install-cert`.
# passthru carries the OpenSSL provider config and PKCS#11 URIs that consumers (git, curl, Firefox) need.
{
  lib,
  writeShellApplication,
  formats,
  fetchpatch,
  pkcs11-provider,
  tpm2-pkcs11,
  opensc,
  openssl,
  coreutils,
  gnugrep,
  gawk,
  token ? "tpm-client-cert",
}:
let
  module = "${lib.getLib tpm2-pkcs11}/lib/libtpm2_pkcs11.so";

  # 1.2.0 encodes named curves as explicit params, which Go's x509 rejects
  provider = pkcs11-provider.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [
      (fetchpatch {
        url = "https://github.com/latchset/pkcs11-provider/commit/3deadf97def44d6a55e622a098bd186fe8110289.patch";
        includes = [ "src/obj/export.c" ];
        hash = "sha256-AtCoJ2dWbTGFP2VWKfKnTUgX65HW2MYUkUg+/uMyQC0=";
      })
    ];
  });

  # tpm2-pkcs11 hangs when the provider offloads digests to a second session
  opensslConf = (formats.iniWithGlobalSection { }).generate "tpm-client-cert-openssl.cnf" {
    globalSection.openssl_conf = "openssl_init";
    sections = {
      openssl_init.providers = "provider_sect";
      provider_sect = {
        default = "default_sect";
        pkcs11 = "pkcs11_sect";
      };
      default_sect.activate = 1;
      pkcs11_sect = {
        module = "${provider}/lib/ossl-modules/pkcs11.so";
        pkcs11-module-path = module;
        pkcs11-module-block-operations = "digest";
        activate = 1;
      };
    };
  };
in
(writeShellApplication {
  name = "tpm-client-cert";
  runtimeInputs = [
    opensc
    openssl
    coreutils
    gnugrep
    gawk
  ];
  text = ''
    export TSS2_LOG=fapi+NONE
    label="''${TPM_CLIENT_CERT_LABEL:-$(uname -n)}"
    dir="''${TPM_CLIENT_CERT_DIR:-$HOME/.local/share/tpm-client-cert}"
    p11() { pkcs11-tool --module "${module}" "$@" 2>/dev/null; }
    have_key() { p11 --token-label "${token}" --list-objects --type pubkey --label "$label" | grep -q "label: *$label$"; }
    usage() { echo "usage: tpm-client-cert csr | install-cert <crt>   (key label: \$TPM_CLIENT_CERT_LABEL, default hostname)" >&2; exit 1; }

    csr() {
      umask 077
      mkdir -p "$dir"
      chmod 700 "$dir"
      store="''${TPM2_PKCS11_STORE:-$HOME/.tpm2_pkcs11}"
      mkdir -p "$store"
      chmod -R go-rwx "$store"

      if ! p11 --list-token-slots | grep -q "token label *: ${token}$"; then
        slot="$(p11 --list-token-slots | awk '/^Slot/ { id = $3 } /token state: *uninitialized/ { print id; exit }' | tr -d '():')"
        [[ -n "$slot" ]] || { echo "no uninitialized tpm2-pkcs11 slot" >&2; exit 1; }
        echo "Initialising token ${token}."
        echo "SO PIN: generate a strong one and store it in your password manager now; it is only for init and unblock."
        echo "User PIN: the one you type in Firefox, git and other PKCS#11 clients."
        pkcs11-tool --module "${module}" --slot "$slot" --init-token --label "${token}"
        pkcs11-tool --module "${module}" --token-label "${token}" --login --login-type so --init-pin
      fi

      if ! have_key; then
        pkcs11-tool --module "${module}" --token-label "${token}" --login \
          --keypairgen --key-type EC:prime256v1 --label "$label" --id 01
      fi

      out="$dir/$label.csr"
      OPENSSL_CONF=${opensslConf} openssl req -new -key "pkcs11:token=${token};object=$label;type=private" -subj "/CN=$label" -out "$out"
      openssl req -in "$out" -noout -verify
      openssl req -in "$out" -noout -text | grep -q "ASN1 OID: prime256v1" || { echo "CSR is not a named P-256 key" >&2; exit 1; }
      echo "CSR: $out"
      echo "SPKI sha256: $(openssl req -in "$out" -noout -pubkey | openssl pkey -pubin -outform der | sha256sum | cut -d' ' -f1)"
    }

    install_cert() {
      crt="''${1:?usage: tpm-client-cert install-cert <crt>}"
      have_key || { echo "no $label key in token ${token}; run tpm-client-cert csr" >&2; exit 1; }
      tmp="$(mktemp -d)"
      trap 'rm -rf "$tmp"' EXIT
      p11 --token-label "${token}" --read-object --type pubkey --label "$label" -o "$tmp/pub.der"
      want="$(openssl pkey -pubin -inform der -in "$tmp/pub.der" -outform der | sha256sum | cut -d' ' -f1)"
      got="$(openssl x509 -in "$crt" -noout -pubkey | openssl pkey -pubin -outform der | sha256sum | cut -d' ' -f1)"
      [[ "$want" == "$got" ]] || { echo "certificate does not match the TPM key" >&2; exit 1; }
      openssl x509 -in "$crt" -outform der -out "$tmp/crt.der"
      if p11 --token-label "${token}" --list-objects --type cert | grep -q "label: *$label$"; then
        pkcs11-tool --module "${module}" --token-label "${token}" --login --delete-object --type cert --label "$label"
      fi
      pkcs11-tool --module "${module}" --token-label "${token}" --login \
        --write-object "$tmp/crt.der" --type cert --label "$label" --id 01
    }

    [[ $# -gt 0 ]] || usage
    cmd="$1"
    shift
    case "$cmd" in
      csr) csr ;;
      install-cert) install_cert "$@" ;;
      *) usage ;;
    esac
  '';
}).overrideAttrs
  (old: {
    passthru = (old.passthru or { }) // {
      inherit token module opensslConf;
      pkcs11-provider = provider;
      uri = label: type: "pkcs11:token=${token};object=${label};type=${type}";
    };
  })
