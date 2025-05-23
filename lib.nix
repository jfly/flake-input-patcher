{
  lib,
  fetchpatch,
  applyPatches,
  ...
}:

let
  importFlake =
    { src, inputs }:
    let
      flake = import (src + "/flake.nix");

      outputs = src // (flake.outputs (inputs // { self = outputs; }));
    in
    outputs;

  patchInputs =
    {
      unpatchedInputs,
      patchSpecByInputName,
    }:
    lib.mapAttrs (
      name: unpatchedInput:
      patchInput {
        inherit name;
        inherit unpatchedInput;
        patchSpec = patchSpecByInputName.${name} or { };
      }
    ) unpatchedInputs;

  patchInput =
    {
      name,
      unpatchedInput,
      patchSpec,
    }:
    let
      patchSpecByInputName = patchSpec.inputs or { };
      patches = patchSpec.patches or [ ];

      patchedInputs = patchInputs {
        unpatchedInputs = unpatchedInput.inputs;
        patchSpecByInputName = patchSpecByInputName;
      };

      patchedSrc = applyPatches {
        name = "${name}-patched";
        patches = patches;
        src = unpatchedInput;
      };
    in
    if patchSpecByInputName == { } && patches == [ ] then
      unpatchedInput
    else
      importFlake {
        src = patchedSrc;
        inputs = patchedInputs;
      };
in

{
  inherit fetchpatch;
  patch =
    unpatchedInputs: patchSpecByInputName:
    patchInputs { inherit unpatchedInputs patchSpecByInputName; };
}
