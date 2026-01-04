{
  config,
  lib,
  pkgs,
  ...
}:
let
  sshPubKey = builtins.readFile /home/eva/.ssh/id_ed25519.pub;
in
{
  options.identity = {
    username = lib.mkOption {
      type = lib.types.str;
      default = "eva";
      description = "The system username";
    };

    name = lib.mkOption {
      type = lib.types.str;
      default = "Eva Harris";
      description = "The user's full name";
    };

    email = lib.mkOption {
      type = lib.types.str;
      default = "mail@gastrodon.io";
      description = "The user's email address";
    };

    sshPubKey = lib.mkOption {
      type = lib.types.str;
      description = "GPG public key identifier (optional)";
      default = sshPubKey;
      description = "SSH public key content";
    };
  };

  config.identity = {
    inherit sshPubKey;
    username = "eva";
    name = "Eva Harris";
    email = "mail@gastrodon.io";
  };
}
