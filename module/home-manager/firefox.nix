{
  config,
  pkgs,
  identity,
  ...
}:

{
  programs.firefox = {
    enable = true;

    policies = {
      DisableTelemetry = true;
      DisableFirefoxStudies = true;
      DisablePocket = true;

      DNSOverHTTPS = {
        Enabled = true;
        ProviderURL = "https://mozilla.cloudflare-dns.com/dns-query";
      };

      EnableTrackingProtection = {
        Value = true;
        Locked = true;
        Cryptomining = true;
        Fingerprinting = true;
      };

      Preferences = {
        "browser.newtabpage.activity-stream.showSponsored" = {
          Value = false;
          Status = "locked";
        };
        "browser.newtabpage.activity-stream.showSponsoredTopSites" = {
          Value = false;
          Status = "locked";
        };
        "dom.security.https_only_mode" = {
          Value = true;
          Status = "default";
        };
        "media.autoplay.default" = {
          Value = 1; # 0=allow, 1=block, 5=block audio
          Status = "default";
        };
      };
    };

    profiles.${identity.username} = {
      isDefault = true;

      extensions.packages = with pkgs.nur.repos.rycee.firefox-addons; [
        adnauseam
        darkreader
        sponsorblock
      ];

      settings = {
        "privacy.trackingprotection.enabled" = true;
        "privacy.trackingprotection.socialtracking.enabled" = true;
        "browser.newtabpage.activity-stream.showSponsored" = false;
        "browser.newtabpage.activity-stream.showSponsoredTopSites" = false;
        "dom.security.https_only_mode" = true;
        "media.autoplay.default" = 1;
      };
    };
  };
}
