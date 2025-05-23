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
    in
    {
      lib = lib.listToAttrs (
        map (
          system:
          let
            pkgs = inputs.nixpkgs.legacyPackages.${system};
          in
          lib.nameValuePair system (pkgs.callPackage ./lib.nix { })
        ) systems
      );
    };
}
