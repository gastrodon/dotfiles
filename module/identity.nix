{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.identity = {
    username = lib.mkOption {
      type = lib.types.str;
      default = "eva";
      description = "The system username";
    };

    name = lib.mkOption {
      type = lib.types.str;
      default = "Eva Harris";
      description = "The user's full name";
    };

    email = lib.mkOption {
      type = lib.types.str;
      default = "mail@gastrodon.io";
      description = "The user's email address";
    };
  };

  config.identity = {
    username = "eva";
    name = "Eva Harris";
    email = "mail@gastrodon.io";
  };
}
