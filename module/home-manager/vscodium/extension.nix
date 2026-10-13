pkgs:
let
  inherit (pkgs) lib;
  pins = builtins.fromJSON (builtins.readFile ./extensions.json);
in
id:
let
  pin = pins.${id} or (throw "vscodium extension ${id} is not in extensions.json");
  parts = lib.splitString "." id;
in
pkgs.vscode-utils.buildVscodeMarketplaceExtension {
  mktplcRef = {
    publisher = builtins.head parts;
    name = lib.concatStringsSep "." (builtins.tail parts);
    inherit (pin) version;
  };
  vsix = pkgs.fetchurl {
    name = "${id}.vsix";
    inherit (pin) url hash;
  };
}
