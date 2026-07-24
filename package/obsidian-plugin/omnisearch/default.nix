{
  pkgs,
  lib,
  fetchurl,
}:

let
  version = "1.29.3";
  base = "https://github.com/scambier/obsidian-omnisearch/releases/download/${version}";
  mainJs = fetchurl {
    url = "${base}/main.js";
    hash = "sha256-2Hzt3+n8Qp/gtk89SAvkiMHkkfKInSQ3AGHTouWvz0w=";
  };
  manifest = fetchurl {
    url = "${base}/manifest.json";
    hash = "sha256-+bJ5HETqAuY0c4PNAnGTCfWXkus5Nh8yzKr8b0l1O3s=";
  };
  styles = fetchurl {
    url = "${base}/styles.css";
    hash = "sha256-gY5rNh5CarOoaKRSSiDfWmQWv2FIdrYe3jQND3jJ68g=";
  };
in
pkgs.runCommand "obsidian-omnisearch-${version}"
  {
    meta = with lib; {
      description = "Omnisearch — a search engine that just works, for Obsidian";
      homepage = "https://github.com/scambier/obsidian-omnisearch";
      license = licenses.gpl3Only;
      maintainers = [ ];
    };
  }
  ''
    mkdir -p $out
    cp ${mainJs} $out/main.js
    cp ${manifest} $out/manifest.json
    cp ${styles} $out/styles.css
  ''
