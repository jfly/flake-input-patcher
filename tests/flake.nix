{
  description = "Tests for flake-input-patcher";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    flake-input-patcher.url = "path:../.";
    dep1.url = "path:./dep1";
  };

  outputs =
    unpatchedInputs:
    let
      # Unfortunately, this utility requires hardcoding a single system. See
      # "Known issues" in ../README.md.
      system = "x86_64-linux";

      patcher = unpatchedInputs.flake-input-patcher.lib.${system};

      inputs = patcher.patch unpatchedInputs {
        # Patching a direct dependency:
        dep1.patches = [
          ./dep1-int-to-str.patch
        ];

        # Patching an indirect dependency:
        dep1.inputs.systems.patches = [
          ./systems.patch
        ];

        # Patching an indirect dependency that is a subdir flake:
        dep1.inputs.subdirFlake.patches = [
          ./new-file.patch
        ];
      };

      inherit (inputs.nixpkgs) lib;
    in
    {
      tests = {
        testDirectDependency = {
          expr = inputs.dep1.value;
          expected = "you've been patched!";
        };

        testTransitiveDependencyDirectAccess = {
          expr = inputs.dep1.directAccessSystem;
          expected = "you've been patched!";
        };

        testTransitiveDependencyIndirectAccess = {
          expr = inputs.dep1.indirectAccessSystem;
          expected = "you've been patched!";
        };

        testSubdirFlakeReadme = {
          expr = inputs.dep1.subdirFlakeReadme;
          expected = "patched this new file into existence!\n";
        };
      };
      failedTests = lib.debug.runTests inputs.self.tests;
    };
}
