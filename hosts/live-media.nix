# USB live-media ISO: bakes the target closure into the ISO; install behaviour is in installer-payload.nix.
{
  targetSystem,
  ...
}:
{
  imports = [ ./installer-payload.nix ];

  isoImage.storeContents = [ targetSystem.config.system.build.toplevel ];
}
