{
  inputs.systems.url = "github:nix-systems/x86_64-linux";

  # A flake that resides in a subdir of a git repo.
  inputs.subdirFlake.url = "github:nix-systems/nix-systems?dir=examples/simple";

  outputs =
    {
      self,
      systems,
      subdirFlake,
    }:
    {
      value = import ./value.nix;
      directAccessSystem = import systems;
      indirectAccessSystem = import self.inputs.systems;
      subdirFlakeReadme = builtins.readFile "${subdirFlake}/new-file-from-patch.md";
    };
}
