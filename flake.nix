{
  description = "Eva's NixOS configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";

    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nur.url = "github:nix-community/NUR";

    free-code.url = "git+ssh://git@github.com/gastrodon/free-code";
    free-code.inputs.nixpkgs.follows = "nixpkgs";

    devenv.url = "github:cachix/devenv";
    devenv-nixpkgs.url = "github:cachix/devenv-nixpkgs/rolling";

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      sops-nix,
      nur,
      free-code,
      devenv,
      devenv-nixpkgs,
      disko,
      ...
    }@inputs:
    let
      mkInstaller =
        { targetSystem, diskConfig }:
        nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = {
            inherit free-code targetSystem diskConfig;
            diskoPkg = disko.packages.x86_64-linux.disko;
          };
          modules = [
            "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
            ./hosts/installer.nix
          ];
        };
    in
    {
      # Desktop build target (stone)
      nixosConfigurations.stone = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit free-code; };
        modules = [
          ./hosts/shared.nix
          ./hosts/stone/configuration.nix
          home-manager.nixosModules.home-manager
          nur.modules.nixos.default
          sops-nix.nixosModules.sops
        ];
      };

      # Server build target (server)
      nixosConfigurations.server = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit free-code; };
        modules = [
          ./hosts/shared.nix
          ./hosts/server/configuration.nix
          home-manager.nixosModules.home-manager
          nur.modules.nixos.default
          sops-nix.nixosModules.sops
          disko.nixosModules.disko
        ];
      };

      # Server installer ISO
      nixosConfigurations.server-installer = mkInstaller {
        targetSystem = self.nixosConfigurations.server;
        diskConfig = ./hosts/server/disks.nix;
      };

      # Laptop build target (twink)
      nixosConfigurations.twink = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit free-code; };
        modules = [
          ./hosts/shared.nix
          ./hosts/twink/configuration.nix
          home-manager.nixosModules.home-manager
          nur.modules.nixos.default
          sops-nix.nixosModules.sops
        ];
      };

      devShells.x86_64-linux.default = devenv.lib.mkShell {
        inherit inputs;
        pkgs = devenv-nixpkgs.legacyPackages.x86_64-linux;
        modules = [ ./devenv.nix ];
      };
    };
}
