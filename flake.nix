{
  description = "Utility to patch flake inputs";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    systems.url = "github:nix-systems/default";
  };

  outputs =
    inputs:
    let
      systems = import inputs.systems;
      inherit (inputs.nixpkgs) lib;
      eachSystem =
        cb:
        lib.listToAttrs (
          map (
            system:
            let
              pkgs = inputs.nixpkgs.legacyPackages.${system};
              value = cb { inherit pkgs; };
            in
            lib.nameValuePair system value
          ) systems
        );
    in
    {
      formatter = eachSystem ({ pkgs, ... }: pkgs.nixfmt-tree);
      lib = eachSystem ({ pkgs, ... }: pkgs.callPackage ./lib.nix { });
    };
}
