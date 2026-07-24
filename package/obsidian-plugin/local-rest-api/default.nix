# The obsidian-local-rest-api flake builds the plugin reproducibly (via bun2nix)
# and installs its artifacts under `$out/lib/`. The programs.obsidian HM module
# expects a plugin package whose `manifest.json` (and `main.js` / `styles.css`)
# sit at the package root, so re-layout the flake output accordingly.
{
  lib,
  runCommand,
  obsidianLocalRestApi,
}:

runCommand "obsidian-local-rest-api-${obsidianLocalRestApi.version or "plugin"}"
  {
    meta = with lib; {
      description = "Obsidian Local REST API with MCP server";
      homepage = "https://github.com/coddingtonbear/obsidian-local-rest-api";
      license = licenses.mit;
      maintainers = [ ];
    };
  }
  ''
    mkdir -p $out
    cp ${obsidianLocalRestApi}/lib/main.js $out/main.js
    cp ${obsidianLocalRestApi}/lib/manifest.json $out/manifest.json
    cp ${obsidianLocalRestApi}/lib/styles.css $out/styles.css
  ''
