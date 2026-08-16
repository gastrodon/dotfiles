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

    free-code.url = "git+ssh://git@github.com/gastrodon/free-code?ref=refs/tags/0.2.6";

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

    ifunny-re = {
      url = "git+ssh://git@github.com/open-ifunny/app-tools";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-minecraft = {
      url = "github:Infinidoge/nix-minecraft";
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
      devenv,
      devenv-nixpkgs,
      disko,
      free-code,
      obsidian-local-rest-api,
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

      mkLiveMedia =
        { targetSystem, diskConfig }:
        nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = {
            inherit targetSystem diskConfig;
            substituter = null;
            diskoPkg = disko.packages.x86_64-linux.disko;
          };
          modules = [
            "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
            ./hosts/live-media.nix
          ];
        };

      # Thin PXE netboot image (see hosts/netboot.nix + installer-payload.nix).
      mkNetboot =
        { targetSystem, diskConfig, substituter }:
        nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = {
            inherit targetSystem diskConfig substituter;
            diskoPkg = disko.packages.x86_64-linux.disko;
          };
          modules = [
            "${nixpkgs}/nixos/modules/installer/netboot/netboot-minimal.nix"
            ./hosts/netboot.nix
          ];
        };

      # native builds hit cache.nixos.org (graphical hosts want this); cross builds miss cache but keep headless SD builds fast.
      mkRpiImage =
        {
          system,
          sdModule,
          configPath,
          native ? false,
        }:
        nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            "${nixpkgs}/nixos/modules/installer/sd-card/${sdModule}"
            configPath
            ./hosts/rpi/shared.nix
            home-manager.nixosModules.home-manager
          ]
          ++ nixpkgs.lib.optional (!native) { nixpkgs.buildPlatform = "x86_64-linux"; };
        };
    in
    {
      nixosConfigurations.stone = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit free-code obsidian-local-rest-api; };
        modules = [
          ./hosts/shared.nix
          ./hosts/stone/configuration.nix
          home-manager.nixosModules.home-manager
          nur.modules.nixos.default
          sops-nix.nixosModules.sops
          inputs.ifunny-re.nixosModules.waydroid
        ];
      };

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
          inputs.nix-minecraft.nixosModules.minecraft-servers
          { nixpkgs.overlays = [ inputs.nix-minecraft.overlays.default ]; }
        ];
      };

      # server gets one generic live-media ISO (no per-box autoinstall — that hardcodes a device, wrong-disk risk); stone/twink keep autoinstall ISOs.
      nixosConfigurations.server-live-media = mkLiveMedia {
        targetSystem = self.nixosConfigurations.server;
        diskConfig = ./hosts/server/disks.nix;
      };

      # Thin netboot chained from stone's PXE server; substituter = stone's nginx binary cache.
      nixosConfigurations.server-netboot = mkNetboot {
        targetSystem = self.nixosConfigurations.server;
        diskConfig = ./hosts/server/disks.nix;
        substituter = "http://192.168.0.77:8080/cache";
      };

      nixosConfigurations.stone-installer = mkInstaller {
        targetSystem = self.nixosConfigurations.stone;
        diskConfig = ./hosts/stone/disks.nix;
      };

      nixosConfigurations.twink-installer = mkInstaller {
        targetSystem = self.nixosConfigurations.twink;
        diskConfig = ./hosts/twink/disks.nix;
      };

      nixosConfigurations.twink = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit free-code obsidian-local-rest-api; };
        modules = [
          ./hosts/shared.nix
          ./hosts/twink/configuration.nix
          home-manager.nixosModules.home-manager
          nur.modules.nixos.default
          sops-nix.nixosModules.sops
          inputs.ifunny-re.nixosModules.waydroid
        ];
      };

      # RPi SD card images
      nixosConfigurations.rpi3b-plus = mkRpiImage {
        system = "aarch64-linux";
        sdModule = "sd-image-aarch64.nix";
        configPath = ./hosts/rpi3b-plus/configuration.nix;
      };

      nixosConfigurations.rpi4b = mkRpiImage {
        system = "aarch64-linux";
        sdModule = "sd-image-aarch64.nix";
        configPath = ./hosts/rpi4b/configuration.nix;
        native = true;
      };

      devShells.x86_64-linux.default = devenv.lib.mkShell {
        inherit inputs;
        pkgs = devenv-nixpkgs.legacyPackages.x86_64-linux;
        modules = [
          ./devenv.nix
          { devenv.root = builtins.toString ./.; }
        ];
      };

      packages.x86_64-linux =
        let
          pkgs = nixpkgs.legacyPackages.x86_64-linux;
          local = import ./package { inherit pkgs; lib = nixpkgs.lib; };
        in
        local.cmd // { inherit (local) sys rend; };

      apps.x86_64-linux = nixpkgs.lib.mapAttrs (name: pkg: {
        type = "app";
        program = "${pkg}/bin/${name}";
      }) self.packages.x86_64-linux;
    };
}
