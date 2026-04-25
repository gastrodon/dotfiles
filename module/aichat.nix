{ config, lib, ... }:
{
  sops.secrets = lib.optionalAttrs (builtins.pathExists ../secrets.yaml) {
    "aichat/model" = { };
    "aichat/client_type" = { };
    "aichat/client_name" = { };
    "aichat/api_base" = { };
    "aichat/api_key" = { };
    "aichat/model_name" = { };
  };

  programs.aichat = lib.mkIf (builtins.pathExists ../secrets.yaml) {
    enable = true;
    user = config.identity.username;

    settings = {
      model = config.sops.placeholder."aichat/model";
      clients = [
        {
          type = config.sops.placeholder."aichat/client_type";
          name = config.sops.placeholder."aichat/client_name";
          api_base = config.sops.placeholder."aichat/api_base";
          api_key = config.sops.placeholder."aichat/api_key";
          models = [ { name = config.sops.placeholder."aichat/model_name"; } ];
        }
      ];
    };
  };
}
