# Actual Budget — self-hosted, privacy-focused budgeting app.
{ ... }:
{
  services.actual = {
    enable = true;
    openFirewall = true;
  };
}
