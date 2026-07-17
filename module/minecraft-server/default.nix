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

  # MCP server bundle that runs inside KubeJS (TS → es2015 IIFE). Serves
  # MCP Streamable-HTTP on :25580 from the game JVM via tinyserver.
  # See package/mcp-kubejs/README.md for the interface.
  mcp-kubejs = import ../../package/mcp-kubejs { inherit pkgs lib; };
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
      # Pin Java 21: nix-minecraft's neoforgeServers default jre_headless
      # resolved to OpenJDK 25 here, which is well past what this
      # NeoForge build's ModLauncher/ASM/Mixin stack supports for MC
      # 1.21.1 (officially a Java 21 target). That mismatch crashed the
      # JVM ~5s into boot, before Log4j even initialized (nothing lands
      # in logs/latest.log; the real error only ever hit the now-gone
      # tmux pane).
      package = pkgs.neoforgeServers.neoforge-1_21_1.override {
        jre_headless = pkgs.jdk21_headless;
      };
      jvmOpts = "-Xmx12G -Xms4G";

      symlinks = {
        # Pack contents. mods/, config/, configureddefaults/ are all
        # read-only and never mutated by the running server.
        "mods" = "${createplus}/mods";
        "config" = "${createplus}/config";
        "configureddefaults" = "${createplus}/configureddefaults";

        # KubeJS scripts. server_scripts/ auto-loads on world start;
        # /kubejs reload server_scripts hot-reloads. The rest of kubejs/
        # (cache/, logs/) is created by KubeJS at runtime in the writable
        # data dir alongside this symlink.
        "kubejs/server_scripts/mcp_server.js" = "${mcp-kubejs}/mcp_server.js";
      };

      serverProperties = {
        # Bind by mDNS name — avahi publishes ${hostname}.local and
        # nss-mdns lets the JVM resolve it to the LAN interface. Keeps
        # us off loopback and off the WAN without a hardcoded IP.
        server-ip = "${config.networking.hostName}.local";
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
        simulation-distance = 12;

        # Trusted players only — kill spawn protection so we can build
        # anywhere near 0,0, and disable PvP so Daniel-vs-eva collisions
        # can't hurt anyone during scripted experiments.
        spawn-protection = 0;
        pvp = false;

        # Many Create/mod scenarios trigger the flight check (elytra,
        # jetpacks, contraption rides). Allow it rather than kicking.
        allow-flight = true;

        # Create contraptions and heavy modded chunkloads can blow past
        # the 60s watchdog; -1 disables the kill so the server doesn't
        # self-terminate mid-tick during long recipe processing.
        max-tick-time = -1;
      };

      whitelist = { };
      operators = { };
      bannedPlayers = { };
    };
  };

  # MCP endpoint served from inside the game JVM (kubejs/server_scripts).
  # LAN-only trust model: the box has no WAN exposure, so an unauthed
  # HTTP port here is bounded to the home network.
  networking.firewall.allowedTCPPorts = [ 25580 ];
}
