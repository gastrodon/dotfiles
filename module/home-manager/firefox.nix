{
  config,
  pkgs,
  identity,
  ...
}:

{
  programs.firefox = {
    enable = true;

    # home.stateVersion pins us to the legacy ~/.mozilla/firefox path already;
    # set explicitly to silence the 26.05 XDG-default warning without a profile move.
    configPath = ".mozilla/firefox";

    policies = {
      DisableTelemetry = true;
      DisableFirefoxStudies = true;
      DisablePocket = true;

      FirefoxSuggest = {
        SponsoredSuggestions = false;
        ImproveSuggest = false;
        Locked = true;
      };

      UserMessaging = {
        ExtensionRecommendations = false;
        FeatureRecommendations = false;
        MoreFromMozilla = false;
        SkipOnboarding = true;
        Locked = true;
      };

      DNSOverHTTPS = {
        Enabled = true;
        ProviderURL = "https://mozilla.cloudflare-dns.com/dns-query";
        # Split horizon: blocky answers *.gastrodon.io with home Traefik; Cloudflare would send it to the edge.
        ExcludedDomains = [ "gastrodon.io" ];
      };

      EnableTrackingProtection = {
        Value = true;
        Locked = true;
        Cryptomining = true;
        Fingerprinting = true;
      };

      Preferences = {
        "privacy.trackingprotection.socialtracking.enabled" = {
          Value = true;
          Status = "locked";
        };
        "browser.newtabpage.activity-stream.enabled" = {
          Value = false;
          Status = "locked";
        };
        "browser.newtabpage.enabled" = {
          Value = false;
          Status = "locked";
        };
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

      search = {
        force = true;
        default = "ddg";
      };

      extensions.packages = with pkgs.nur.repos.rycee.firefox-addons; [
        adnauseam
        bitwarden
        darkreader
        sponsorblock
      ];
    };
  };
}
