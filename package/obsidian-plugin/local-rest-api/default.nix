# The flake installs plugin artifacts under $out/lib/; programs.obsidian expects manifest.json/main.js/styles.css at the package root — re-layout them here.
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
