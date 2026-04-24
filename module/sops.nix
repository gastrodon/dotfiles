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
    aichat-config = {
      owner = config.identity.username;
      path = "/home/${config.identity.username}/.config/aichat/config.yaml";
    };
  };

  system.activationScripts.sopsAgeKey = {
    text =
      let
        keyFile = "/home/${config.identity.username}/.config/sops/age/keys.txt";
        sshKey = "/home/${config.identity.username}/.ssh/id_ed25519";
        user = config.identity.username;
      in
      ''
        if [ ! -f "${keyFile}" ]; then
          mkdir -p "$(dirname ${keyFile})"
          ${pkgs.ssh-to-age}/bin/ssh-to-age -private-key < "${sshKey}" > "${keyFile}"
          chmod 600 "${keyFile}"
          chown ${user}:users "${keyFile}"
        fi
      '';
    deps = [ ];
  };

  environment.systemPackages = with pkgs; [
    age
    sops
    ssh-to-age
  ];
}
