{
  pkgs,
  lib,
  config,
  ...
}:
let
  # Create+ modpack (Modrinth). NeoForge 1.21.1, alpha-f.
  #   project t1tOiUHZ ("create_plus"), version BSg2ZS8u ("6.0.0-alpha-f")
  # fetchModrinthModpack extracts the mrpack, downloads every file whose
  # env.server != "unsupported", and lays out mods/ + config/ + overrides.
  createplus-pack = pkgs.fetchModrinthModpack {
    url = "https://cdn.modrinth.com/data/t1tOiUHZ/versions/BSg2ZS8u/Create%2B%206.0.0%20Alpha%20f.mrpack";
    packHash = "sha256-wuyZsVoqb0FCc7ETTwwNbp+8j9dwTiRT26s/lqtcfNo=";
    side = "server";
  };

  # Extra jars we drop next to the pack's mods to give Claude a scripting
  # surface inside the game. The pack ships none of these.
  kubejs = pkgs.fetchurl {
    url = "https://cdn.modrinth.com/data/umyGl7zF/versions/F2nzeC19/kubejs-neoforge-2101.7.2-build.368.jar";
    hash = "sha256-AXZ7tnepxKjzGHF8TCG8p+fvgJlWA0A6VRBooOBk50A=";
  };
  rhino = pkgs.fetchurl {
    url = "https://cdn.modrinth.com/data/sk9knFPE/versions/cQ4POTah/rhino-2101.2.7-build.85.jar";
    hash = "sha256-4Omw547dOARAJmwPTqjUidrIUe8HWkVmpmptri97u2Y=";
  };
  ponderjs = pkgs.fetchurl {
    url = "https://github.com/AlmostReliable/ponderjs/releases/download/v1.21.1-neoforge-2.4.0/ponderjs-neoforge-1.21.1-2.4.0.jar";
    hash = "sha256-2ROcYZyw+goKMFgAHEypk+zflVyaqKgWQLwkcCtENGY=";
  };

  # Merge the extra jars into the pack derivation. addFiles clones the
  # tree via `cp -as` (recursive symlinks), so mods/ ends up containing
  # every pack mod plus our three additions, all pointing into the store.
  createplus = createplus-pack.addFiles {
    "mods/kubejs.jar" = kubejs;
    "mods/rhino.jar" = rhino;
    "mods/ponderjs.jar" = ponderjs;
  };
in
{
  services.minecraft-servers = {
    enable = true;
    eula = true;
    # Individual servers pin server-ip to the LAN address, so opening the
    # firewall globally is safe: nothing listens on the WAN side.
    openFirewall = true;

    servers.createplus = {
      enable = true;
      autoStart = true;
      package = pkgs.neoforgeServers.neoforge-1_21_1;
      jvmOpts = "-Xmx12G -Xms4G";

      symlinks = {
        # Pack contents. mods/, config/, configureddefaults/ are all
        # read-only and never mutated by the running server.
        "mods" = "${createplus}/mods";
        "config" = "${createplus}/config";
        "configureddefaults" = "${createplus}/configureddefaults";

        # KubeJS scripts. server_scripts/ auto-loads on world start;
        # /kubejs reload server_scripts hot-reloads. The rest of kubejs/
        # (cache/, logs/, mcp/) is created by KubeJS/the bridge at runtime
        # in the writable data dir alongside this symlink.
        "kubejs/server_scripts/mcp_bridge.js" = ./bridge/mcp_bridge.js;
      };

      serverProperties = {
        # Bind only to the LAN interface. No loopback, no WAN.
        server-ip = "192.168.0.116";
        server-port = 25565;

        motd = "eva's create+";
        difficulty = "normal";
        gamemode = "survival";
        max-players = 8;

        # Local-only server: skip Mojang auth so Daniel (the bot) and eva
        # can connect without credentials. Combined with the LAN-only bind
        # above, exposure is bounded to the home network.
        online-mode = false;
        enforce-secure-profile = false;

        white-list = false;
        enable-command-block = true;
        view-distance = 12;
      };

      whitelist = { };
      operators = { };
      bannedPlayers = { };
    };
  };

  # The KubeJS bridge reads and writes JSON under kubejs/mcp/{in,out}/.
  # Create the directories eagerly so the script can drop files on first
  # tick without racing world load. Group-writable so other users on this
  # box (e.g. the mcp-minecraft MCP server later) can drop request files.
  systemd.tmpfiles.rules = [
    "d /srv/minecraft/createplus/kubejs/mcp 0775 minecraft minecraft - -"
    "d /srv/minecraft/createplus/kubejs/mcp/in 0775 minecraft minecraft - -"
    "d /srv/minecraft/createplus/kubejs/mcp/out 0775 minecraft minecraft - -"
  ];
}
