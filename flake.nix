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

    nix-index-database = {
      url = "github:nix-community/nix-index-database";
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

    # Source only: stone joins the lab cluster via lab/nix-modules' stone-join (nomad-client + pxe-boot-server).
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

    in
    {
      nixosConfigurations.stone = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit claude-code-nix claude-desktop-nix; };
        modules = [
          ./hosts/shared.nix
          ./hosts/stone/configuration.nix
          "${inputs.lab-nix-modules}/module/stone-join.nix"
          home-manager.nixosModules.home-manager
          labPkgs
          { home-manager.sharedModules = [ inputs.nix-index-database.homeModules.nix-index ]; }
          nur.modules.nixos.default
          sops-nix.nixosModules.sops
        ];
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
          { home-manager.sharedModules = [ inputs.nix-index-database.homeModules.nix-index ]; }
          nur.modules.nixos.default
          sops-nix.nixosModules.sops
        ];
      };

      # Build capabilities per host (source of truth for ./build script validation)
      buildCapabilities = {
        stone = { };
        twink = { };
      };
    };
}
