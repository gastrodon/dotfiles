{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.tpmClientCert;
  tool = pkgs.tpm-client-cert.override {
    tpm2-pkcs11 = config.security.tpm2.pkcs11.package;
    inherit (cfg) token;
  };
in
{
  options.tpmClientCert = {
    enable = lib.mkEnableOption "TPM-held client certificate tooling (tpm2-pkcs11)";
    token = lib.mkOption {
      type = lib.types.str;
      default = "client-cert";
      description = "PKCS#11 token label.";
    };
  };

  config = lib.mkIf cfg.enable {
    security.tpm2 = {
      enable = true;
      pkcs11.enable = true;
      tctiEnvironment.enable = true;
    };
    users.users.${config.identity.username}.extraGroups = [ config.security.tpm2.tssGroup ];
    environment.systemPackages = [ pkgs.tpm2-tools ];

    # the token PIN is typed into same-uid prompts; same-uid ptrace would read it
    boot.kernel.sysctl."kernel.yama.ptrace_scope" = lib.mkDefault 1;
    assertions = [
      {
        assertion = config.boot.kernel.sysctl."kernel.yama.ptrace_scope" >= 1;
        message = "tpm-client-cert needs kernel.yama.ptrace_scope >= 1 to protect the token PIN";
      }
    ];

    home-manager.users.${config.identity.username} = {
      home.packages = [ tool ];

      programs.firefox.policies.SecurityDevices.Add.${tool.token} = tool.module;

      programs.git.package = pkgs.symlinkJoin {
        name = "git-tpm-client-cert";
        paths = [
          pkgs.git
          pkgs.git.doc
        ];
        nativeBuildInputs = [ pkgs.makeWrapper ];
        # only the http(s) transport loads the pkcs11 provider; hooks, helpers and ssh do not
        postBuild = ''
          wrapProgram $out/libexec/git-core/git-remote-http --set OPENSSL_CONF ${tool.opensslConf} --set TSS2_LOG fapi+NONE
          ln -sfn git-remote-http $out/libexec/git-core/git-remote-https
          wrapProgram $out/bin/git --set GIT_EXEC_PATH $out/libexec/git-core
        '';
      };
    };
  };
}
