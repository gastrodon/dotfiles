{
  config,
  pkgs,
  lib,
  ...
}:
{
  services.factorio = {
    enable = true;
    package = pkgs.factorio-headless;

    game-name = "silly goose";
    description = "silly gooses with tools";

    port = 34197;
    bind = "0.0.0.0";
    public = false;
    lan = true;
    requireUserVerification = true;
    autosave-interval = 10;

    saveName = "silly-goose";
    game-password = "foobar2000";
    admins = [ ];
  };

  networking.firewall = {
    allowedUDPPorts = [ 34197 ];
  };
}
