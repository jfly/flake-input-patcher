{
  inputs = {
    dep1 = {
      url = "path:../dep1";
      inputs.systems.follows = "systems";
    };

    systems.url = "github:nix-systems/aarch64-linux";
  };

  outputs =
    inputs:
    # This funky top-level `if` statement is to demonstrate that we can access one
    # of our own inputs while evaluating ourself. An early attempt at
    # implementing "follows" support caused infinite recursion here.
    if inputs.dep1.directAccessSystem == [ "aarch64-linux" ] then
      {
        systemFromDep1 = inputs.dep1.directAccessSystem;
      }
    else
      {
        tamperedSystems = true;
        systemFromDep1 = inputs.dep1.directAccessSystem;
      };
}
