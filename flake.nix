{
  description = "Eva's NixOS configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    flake-utils.url = "github:numtide/flake-utils";

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nur.url = "github:nix-community/NUR";

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-minecraft = {
      url = "github:Infinidoge/nix-minecraft";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Not follows'd on purpose: nixpkgs' claude-code lags upstream npm releases by
    # weeks-to-months (missing models/features in the CLI menus). This flake tracks
    # the npm package directly and updates fast; pin it to nixpkgs and we're back
    # to the same staleness problem.
    claude-code-nix.url = "github:sadjow/claude-code-nix";

    # Official Claude Desktop Linux beta (EVA-592). Follows our nixpkgs, unlike
    # claude-code-nix above — this one already pins its own upstream .deb hash.
    claude-desktop-nix = {
      url = "github:nmcbride/claude-desktop-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    lab-pkgs = {
      url = "git+http://192.168.0.17:3000/lab/pkgs.git";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Source only: cluster-node takes lab/nix-modules' edge-tunnel module until the EVA-441 cutover.
    lab-nix-modules = {
      url = "git+http://192.168.0.17:3000/lab/nix-modules.git";
      flake = false;
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      sops-nix,
      nur,
      disko,
      claude-code-nix,
      claude-desktop-nix,
      ...
    }@inputs:
    let
      labPkgs = { nixpkgs.overlays = [ inputs.lab-pkgs.overlays.default ]; };

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
        {
          targetSystem,
          diskConfig,
          substituter,
        }:
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

    in
    {
      nixosConfigurations.stone = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit claude-code-nix claude-desktop-nix; };
        modules = [
          ./hosts/shared.nix
          ./hosts/stone/configuration.nix
          home-manager.nixosModules.home-manager
          labPkgs
          nur.modules.nixos.default
          sops-nix.nixosModules.sops
        ];
      };

      # The diskless netboot cluster node (EVA-298/299). One image, all three
      # OptiPlexes. RAM-budget rationale: see wiki (Diskless netboot node
      # image) or hosts/cluster-node/configuration.nix.
      nixosConfigurations.cluster-node = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./hosts/cluster-node/configuration.nix
          "${inputs.lab-nix-modules}/module/edge-tunnel.nix"
          { services.edgeTunnel.enable = true; }
        ];
      };

      nixosConfigurations.server = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit claude-code-nix; };
        modules = [
          ./hosts/shared.nix
          ./hosts/server/configuration.nix
          home-manager.nixosModules.home-manager
          labPkgs
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
        specialArgs = { inherit claude-code-nix claude-desktop-nix; };
        modules = [
          ./hosts/shared.nix
          ./hosts/twink/configuration.nix
          home-manager.nixosModules.home-manager
          labPkgs
          nur.modules.nixos.default
          sops-nix.nixosModules.sops
        ];
      };

      # Build capabilities per host (source of truth for ./build script validation)
      buildCapabilities = {
        stone = { };
        twink = { };
        server = { servePxe = true; };
      };
    };
}
