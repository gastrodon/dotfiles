{
  description = "Eva's NixOS configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";

    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nur.url = "github:nix-community/NUR";

    free-code.url = "git+ssh://git@github.com/gastrodon/free-code";
    free-code.inputs.nixpkgs.follows = "nixpkgs";

    devenv.url = "github:cachix/devenv";
    devenv-nixpkgs.url = "github:cachix/devenv-nixpkgs/rolling";
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      nur,
      free-code,
      devenv,
      devenv-nixpkgs,
      ...
    }@inputs:
    {
      nixosConfigurations.twink = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit free-code; };
        modules = [
          ./configuration.nix
          home-manager.nixosModules.home-manager
          nur.modules.nixos.default
        ];
      };

      devShells.x86_64-linux.default = devenv.lib.mkShell {
        inherit inputs;
        pkgs = devenv-nixpkgs.legacyPackages.x86_64-linux;
        modules = [ ./devenv.nix ];
      };
    };
}
