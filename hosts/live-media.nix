# USB live-media ISO for the server boxes. All install behaviour lives in the
# shared installer payload; this file only bakes the target closure into the
# ISO and pulls in the payload.
{
  targetSystem,
  ...
}:
{
  imports = [ ./installer-payload.nix ];

  isoImage.storeContents = [ targetSystem.config.system.build.toplevel ];
}
