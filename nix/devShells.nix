{ inputs, ... }:
{
  default =
    { lib, ... }@pkgs:
    let
      nnl = inputs.nnl.packages.${pkgs.system}.default;

      buildPackages = with pkgs; [
        nim
        nimble
        nnl
        pkg-config
      ];
      libPackages = with pkgs; [
        glib
        libgbinder
        pcre2
        gtk4
        libadwaita
        curl
        sqlite
        (zlib-ng.override {
          withZlibCompat = true;
        })
        mimalloc
        libbacktrace
      ];
      binPackages = with pkgs; [
        lxc
        dnsmasq
        policycoreutils
      ];
    in
    {
      stdenv = lib.mkForce pkgs.clangStdenv;

      packages = buildPackages ++ binPackages;
      env = {
        LD_LIBRARY_PATH = lib.makeLibraryPath libPackages;
      };
    };
}
