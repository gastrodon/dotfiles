# Firefox Browser Configuration
# Configures Firefox web browser with system-level settings

{ config, pkgs, ... }:

{
  # Install Firefox
  environment.systemPackages = with pkgs; [
    firefox
  ];

  # Firefox policies configuration (optional)
  # These settings apply to all users and cannot be changed by users
  # Uncomment and customize as needed
  # 
  # programs.firefox = {
  #   enable = true;
  #   
  #   # Firefox policies - system-wide settings
  #   policies = {
  #     # Disable telemetry and data collection
  #     DisableTelemetry = true;
  #     DisableFirefoxStudies = true;
  #     DisablePocket = true;
  #     
  #     # Disable Firefox Accounts
  #     # DisableFirefoxAccounts = true;
  #     
  #     # Enable DNS over HTTPS
  #     DNSOverHTTPS = {
  #       Enabled = true;
  #       ProviderURL = "https://mozilla.cloudflare-dns.com/dns-query";
  #     };
  #     
  #     # Set default search engine
  #     # SearchEngines = {
  #     #   Default = "DuckDuckGo";
  #     # };
  #     
  #     # Privacy settings
  #     EnableTrackingProtection = {
  #       Value = true;
  #       Locked = false;
  #       Cryptomining = true;
  #       Fingerprinting = true;
  #     };
  #     
  #     # Disable password manager
  #     # PasswordManagerEnabled = false;
  #     
  #     # Homepage and new tab
  #     # Homepage = {
  #     #   URL = "about:home";
  #     #   Locked = false;
  #     # };
  #     
  #     # Extensions to install automatically
  #     # ExtensionSettings = {
  #     #   "uBlock0@raymondhill.net" = {
  #     #     installation_mode = "force_installed";
  #     #     install_url = "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi";
  #     #   };
  #     # };
  #     
  #     # Preferences - fine-grained settings
  #     Preferences = {
  #       # Disable sponsored content
  #       "browser.newtabpage.activity-stream.showSponsored" = {
  #         Value = false;
  #         Status = "locked";
  #       };
  #       "browser.newtabpage.activity-stream.showSponsoredTopSites" = {
  #         Value = false;
  #         Status = "locked";
  #       };
  #       
  #       # Enable HTTPS-only mode
  #       "dom.security.https_only_mode" = {
  #         Value = true;
  #         Status = "default";
  #       };
  #       
  #       # Disable autoplay
  #       "media.autoplay.default" = {
  #         Value = 5;  # 0=allow, 1=block, 5=block audio
  #         Status = "default";
  #       };
  #     };
  #   };
  #   
  #   # Preload extensions (optional)
  #   # package = pkgs.firefox.override {
  #   #   extraPrefs = ''
  #   #     // Custom preferences here
  #   #   '';
  #   # };
  # };

  # Note: For user-specific Firefox configuration, use Home Manager instead
  # This provides better control over profiles, bookmarks, extensions, etc.
  # See: https://nix-community.github.io/home-manager/options.html#opt-programs.firefox.enable
}
