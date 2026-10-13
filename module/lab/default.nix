{ config, ... }:
{
  home-manager.users.${config.identity.username}.imports = [ ./home ];
}
