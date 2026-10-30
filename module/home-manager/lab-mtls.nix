# Client cert for WAN *.lab (LAB-182). The key lives in the TPM; tooling is lab/pkgs tpm-mtls.
{
  osConfig,
  pkgs,
  hostname,
  ...
}:
let
  tpm-mtls = pkgs.tpm-mtls.override { tpm2-pkcs11 = osConfig.security.tpm2.pkcs11.package; };
  inherit (tpm-mtls) token module opensslConf;
  uri = tpm-mtls.uri hostname;
in
{
  home.packages = [
    tpm-mtls
    (pkgs.lab-s3.override { inherit tpm-mtls; })
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
