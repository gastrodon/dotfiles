# mDNS via Avahi — cluster hosts resolve each other as <hostname>.local
# without hardcoded IPs. Also enables NSS mDNS so plain tools (ping, curl)
# work with .local names.
{ ... }:
{
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;

    publish = {
      enable = true;
      addresses = true;
      workstation = true;
    };
  };
}
