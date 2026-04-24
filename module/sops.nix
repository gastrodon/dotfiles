{
  config,
  lib,
  pkgs,
  ...
}:
{
  # Age key derived from SSH host key — available on all machines without
  # distributing a separate key file.
  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

  # User-level age key for encrypting/decrypting secrets locally.
  sops.age.keyFile = "/home/${config.identity.username}/.config/sops/age/keys.txt";

  # sops-nix will create this path if it doesn't exist.
  sops.age.generateKey = false;

  sops.defaultSopsFile = lib.mkIf (builtins.pathExists ../secrets.yaml) ../secrets.yaml;

  sops.secrets = lib.optionalAttrs (builtins.pathExists ../secrets.yaml) {
    "aichat/model" = { };
    "aichat/client_type" = { };
    "aichat/client_name" = { };
    "aichat/api_base" = { };
    "aichat/api_key" = { };
    "aichat/model_name" = { };
  };

  sops.templates."aichat-config" = lib.mkIf (builtins.pathExists ../secrets.yaml) {
    owner = config.identity.username;
    path = "/home/${config.identity.username}/.config/aichat/config.yaml";
    content =
      let
        fmt = pkgs.formats.yaml { };
      in
      builtins.readFile (
        fmt.generate "aichat-config.yaml" {
          model = config.sops.placeholder."aichat/model";
          save_session = false;
          clients = [
            {
              type = config.sops.placeholder."aichat/client_type";
              name = config.sops.placeholder."aichat/client_name";
              api_base = config.sops.placeholder."aichat/api_base";
              api_key = config.sops.placeholder."aichat/api_key";
              models = [ { name = config.sops.placeholder."aichat/model_name"; } ];
            }
          ];
        }
      );
  };

  environment.systemPackages = with pkgs; [
    age
    sops
    ssh-to-age
  ];
}
