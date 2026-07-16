{ pkgs, ... }:
{
  services.minecraft-servers = {
    enable = true;
    eula = true;
    openFirewall = true;

    servers.sandbox = {
      enable = true;
      package = pkgs.minecraftServers.vanilla-1_21_9;
      jvmOpts = "-Xmx12G -Xms2G";

      serverProperties = {
        server-port = 25565;
        motd = "eva's sandbox";
        difficulty = "normal";
        gamemode = "survival";
        max-players = 8;
        white-list = false;
        online-mode = true;
        enable-command-block = true;
        view-distance = 12;
      };

      # Empty blocklist for now — no whitelist restrictions, no bans.
      whitelist = { };
      operators = { };
      bannedPlayers = { };
    };
  };
}
