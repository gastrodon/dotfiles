{
  description = "Eva's NixOS configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";

    flake-utils.url = "github:numtide/flake-utils";

    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nur.url = "github:nix-community/NUR";

    free-code.url = "git+ssh://git@github.com/gastrodon/free-code?ref=refs/tags/0.2.1";

    devenv.url = "github:cachix/devenv";
    devenv-nixpkgs.url = "github:cachix/devenv-nixpkgs/rolling";

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    obsidian-local-rest-api = {
      url = "github:auto-patcher/obsidian-local-rest-api";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      sops-nix,
      nur,
      devenv,
      devenv-nixpkgs,
      disko,
      free-code,
      ...
    }@inputs:
    let
      mkInstaller =
        { targetSystem, diskConfig }:
        nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = {
            inherit targetSystem diskConfig;
            diskoPkg = disko.packages.x86_64-linux.disko;
          };
          modules = [
            "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
            ./hosts/installer.nix
          ];
        };

      mkRpiImage =
        {
          system,
          sdModule,
          configPath,
        }:
        nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            "${nixpkgs}/nixos/modules/installer/sd-card/${sdModule}"
            configPath
            ./hosts/rpi/shared.nix
            { nixpkgs.buildPlatform = "x86_64-linux"; }
          ];
        };
    in
    {
      # Desktop build target (stone)
      nixosConfigurations.stone = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit free-code obsidian-local-rest-api; };
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
        specialArgs = { inherit free-code obsidian-local-rest-api; };
        modules = [
          ./hosts/shared.nix
          ./hosts/server/configuration.nix
          home-manager.nixosModules.home-manager
          nur.modules.nixos.default
          sops-nix.nixosModules.sops
          disko.nixosModules.disko
        ];
      };

      # Installer ISOs
      nixosConfigurations.server-installer = mkInstaller {
        targetSystem = self.nixosConfigurations.server;
        diskConfig = ./hosts/server/disks.nix;
      };

      nixosConfigurations.stone-installer = mkInstaller {
        targetSystem = self.nixosConfigurations.stone;
        diskConfig = ./hosts/stone/disks.nix;
      };

      nixosConfigurations.twink-installer = mkInstaller {
        targetSystem = self.nixosConfigurations.twink;
        diskConfig = ./hosts/twink/disks.nix;
      };

      # Laptop build target (twink)
      nixosConfigurations.twink = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit free-code obsidian-local-rest-api; };
        modules = [
          ./hosts/shared.nix
          ./hosts/twink/configuration.nix
          home-manager.nixosModules.home-manager
          nur.modules.nixos.default
          sops-nix.nixosModules.sops
        ];
      };

      # RPi SD card images
      nixosConfigurations.rpi2b = mkRpiImage {
        system = "armv7l-linux";
        sdModule = "sd-image-armv7l-multiplatform.nix";
        configPath = ./hosts/rpi2b/configuration.nix;
      };

      nixosConfigurations.rpi3b-plus = mkRpiImage {
        system = "aarch64-linux";
        sdModule = "sd-image-aarch64.nix";
        configPath = ./hosts/rpi3b-plus/configuration.nix;
      };

      nixosConfigurations.rpi4b = mkRpiImage {
        system = "aarch64-linux";
        sdModule = "sd-image-aarch64.nix";
        configPath = ./hosts/rpi4b/configuration.nix;
      };

      devShells.x86_64-linux.default = devenv.lib.mkShell {
        inherit inputs;
        pkgs = devenv-nixpkgs.legacyPackages.x86_64-linux;
        modules = [
          ./devenv.nix
          { devenv.root = builtins.toString ./.; }
        ];
      };
    };
}
