{ callPackage, buildEnv }:
let
  equinox =
    let
      expr = import ../package.nix;
    in
    callPackage expr { };
  appimagetool =
    let
      file = builtins.fetchurl "https://github.com/nix-community/nix-bundle/raw/refs/heads/master/appimagetool.nix";
      expr = import file;
    in
    callPackage expr {};
  appDir = buildEnv {
    name = "equinox-AppDir";
    paths = [
      equinox
    ];
  };
in 1
