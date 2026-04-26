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
      # "Known issues" in `../README.md`.
      system = "x86_64-linux";

      patcher = unpatchedInputs.flake-input-patcher.lib.${system};

      inputs = patcher.patch unpatchedInputs {
        # Patching a direct dependency:
        dep1.patches = [
          ./dep1-int-to-str.patch
          ./dep1-change-attrset.patch
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

        testDirectDependencyThroughSelf = {
          expr = inputs.self.inputs.dep1.set;
          expected = {
            new = "new";
          };
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

        # This is a bit confusing: `call-flake.nix` invokes the flake `outputs`
        # function with `inputs // { self = ...; }` [0], and includes `inputs`
        # (*without* `self`) in the final `result` [1].
        # This means the that calling the arguments to your flake `inputs` is
        # actually wrong, it's really `inputsWithSelf`, but AFAIK, people in
        # the ecosystem don't bother to make that distinction.
        # TL;DR: `inputs.self` must exist, but `inputs.self.inputs` must not.
        #
        # [0]: https://github.com/NixOS/nix/blob/2.34.6/src/libflake/call-flake.nix#L71
        # [1]: https://github.com/NixOS/nix/blob/2.34.6/src/libflake/call-flake.nix#L85
        testInputsDoNotIncludeSelf = {
          expr = inputs.self.inputs ? self;
          expected = false;
        };
      };
      failedTests = lib.debug.runTests inputs.self.tests;
    };
}
