{
  inputs = {
    dep1 = {
      url = "path:../dep1";
      inputs.systems.follows = "systems";
    };

    systems.url = "github:nix-systems/aarch64-linux";
  };

  outputs = inputs: {
    systemFromDep1 = inputs.dep1.directAccessSystem;
  };
}
