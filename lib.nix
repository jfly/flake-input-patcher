{
  lib,
  fetchpatch,
  callPackage,
  ...
}:

let
  callFlake = callPackage ./call-flake.nix { };

  # Given a flake's unpatched inputs, lockFile, and a patchSpec, produce
  # `overrides` suitable for our callFlake function.
  # `overrides` is a mapping of node name (as found in the lockFile) to
  # `{ sourceInfo, patches ? [] }`.
  buildOverrides =
    {
      lockFile,
      unpatchedInputs,
      rootPatchSpec,
    }:
    let
      buildInputInfoByNodeName =
        {
          nodeName,
          unpatchedInput,
          patchSpec,
        }:
        let
          node = lockFile.nodes.${nodeName};
          nonFollowsInputs = lib.filterAttrs (
            inputName: nodeNameOrFollows:
            # Follows are lists of strings (such as ["dep1" "systems"]). We're
            # only interested in named nodes (strings).
            builtins.typeOf nodeNameOrFollows == "string"
          ) (node.inputs or { });
        in
        lib.mergeAttrsList (
          [
            {
              ${nodeName} = {
                input = unpatchedInput;
                patches = patchSpec.patches or [ ];
              };
            }
          ]
          ++ (lib.mapAttrsToList (
            inputName: nodeName:
            buildInputInfoByNodeName {
              inherit nodeName;
              unpatchedInput = unpatchedInput.inputs.${inputName};
              patchSpec = patchSpec.inputs.${inputName} or { };
            }
          ) nonFollowsInputs)
        );
      inputInfoByNodeName = buildInputInfoByNodeName {
        nodeName = lockFile.root;
        unpatchedInput = {
          inputs = unpatchedInputs;
        };
        patchSpec = {
          inputs = rootPatchSpec;
        };
      };
    in
    lib.mapAttrs (
      nodeName: node:
      let
        inputInfo = inputInfoByNodeName.${nodeName};
        inherit (inputInfo) input patches;
      in
      {
        inherit patches;
      }
      # Note: the root node does not have `sourceInfo` nor `outPath`. That's fine, we're
      # never going to apply patches to it (you can just edit your flake!).
      // lib.getAttrs [ "sourceInfo" "outPath" ] input
    ) lockFile.nodes;

  patchV1 = (callPackage ./lib-deprecated.nix { }).patch;
  patchV2 =
    {
      unpatchedInputs,
      patchSpec,
      flakePath,
    }:
    let
      inherit (unpatchedInputs) self;

      lockFile = builtins.fromJSON (builtins.readFile "${flakePath}/flake.lock");

      overrides = buildOverrides {
        inherit unpatchedInputs lockFile;
        rootPatchSpec = patchSpec;
      };
      patchedInputs = (callFlake lockFile overrides).inputs;
    in
    patchedInputs
    // {
      self = self // {
        inputs = patchedInputs;
      };
    };

  equalIgnoreOrder = l1: l2: lib.sort lib.lessThan l1 == lib.sort lib.lessThan l2;
in
{
  inherit fetchpatch;
  patch =
    arg:
    if
      equalIgnoreOrder (builtins.attrNames arg) [
        "unpatchedInputs"
        "patchSpec"
        "flakePath"
      ]
    then
      patchV2 arg
    else
      lib.warn ''
        You are using the deprecated form of flake-input-patcher's `patch` which does not
        support inputs follows.

        This will be dropped in favor of the new form, which takes exactly 1 argument:

          patcher.patch {
            inherit unpatchedInputs;
            flakePath = ./.;
            patchSpec = {
              # Patching a direct dependency:
              nixpkgs.patches = [
                (patcher.fetchpatch {
                  name = "k3s: use patched util-linuxMinimal";
                  url = "https://github.com/NixOS/nixpkgs/pull/407810.diff";
                  hash = "sha256-N8tzwSZB9d4Htvimy00+Jcw8TKRCeV8PJWp80x+VtSk=";
                })
              ];

              # Patching a transitive dependency:
              clan-core.inputs.data-mesher.patches = [
                 # ... More patches here ...
              ];
            };
          };
      '' (patchV1 arg);
}
