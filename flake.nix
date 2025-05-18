{
  description = " A work-in-progress runtime for Roblox on Linux using containers.";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flakelight = {
      url = "github:nix-community/flakelight";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nnl = {
      url = "github:daylinmorgan/nnl";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { self, flakelight, ... }@inputs:
    flakelight ./. (
      { outputs, ... }:
      {
        inherit inputs;
        systems = [
          "x86_64-linux"
          "i686-linux"
        ];

        perSystem =
          { system, ... }:
          {
            packages =
              let
                inherit (outputs.packages.${system}) default;
              in
              {
                equinox = default;
                equinox-debug = default.override {
                  release = false;
                };
              };
          };
      }
    );
}
