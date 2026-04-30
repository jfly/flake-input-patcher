{
  lib,
  fetchpatch,
  applyPatches,
  ...
}:

let
  # This logic is largely copied from nix itself, see
  # <https://github.com/NixOS/nix/blob/2.29.0/src/libflake/call-flake.nix>.
  # We can't use `builtins.getFlake` for two reasons:
  #  1. Nix treats this as an "unlocked" flake reference and errors out in pure
  #     mode. I suspect this is a bug, perhaps one that only arises when doing
  #     IFD like we're doing here.
  #  2. We need to load the flake with the given (possibly patched) inputs.
  importFlake =
    { src, inputs }:
    let
      flake = import (src + "/flake.nix");
      outPath = toString src;

      # I'm not sure what to do with `sourceInfo`. It normally comes from the
      # lockfile [0]. Copying the old value feels wrong.
      # I'm going to opt to leave it unset until something goes wrong.
      #
      # [0]: https://github.com/NixOS/nix/blob/2.29.0/src/libflake/call-flake.nix#L52-L63
      sourceInfo = {
        inherit outPath;
      };

      outputs = flake.outputs (inputs // { self = result; });

      result =
        outputs
        // sourceInfo
        // {
          inherit inputs;
          inherit outputs;
          inherit sourceInfo;
          _type = "flake";
        };
    in
    result;

  patchInputs =
    {
      unpatchedInputs,
      patchSpecByInputName,
      inputSpecByInputName,
    }:
    lib.mapAttrs (
      name: unpatchedInput:
      patchInput {
        inherit name;
        inherit unpatchedInput;
        patchSpec = patchSpecByInputName.${name} or { };
        inputSpec = inputSpecByInputName.${name} or { };
      }
    ) unpatchedInputs;

  patchInput =
    {
      name,
      unpatchedInput,
      patchSpec,
      inputSpec,
    }:
    let
      patchSpecByInputName = patchSpec.inputs or { };
      inputSpecByInputName = inputSpec.inputs or { };
      follows = inputSpec.follows or null;
      patches = patchSpec.patches or [ ];

      patchedInputs = patchInputs {
        unpatchedInputs = unpatchedInput.inputs;
        inherit
          patchSpecByInputName
          inputSpecByInputName
          ;
      };

      patchedSrc =
        if patches == [ ] then
          unpatchedInput
        else
          applyPatches {
            name = "${name}-patched";
            patches = patches;
            src = unpatchedInput;
          };
    in
    if follows != null then
      follows
    else
      importFlake {
        src = patchedSrc;
        inputs = patchedInputs;
      };

  resolveFollows =
    {
      inputSpec,
      patchedInputs,
    }:
    let
      resolveFollow =
        followList: patchedInputs:
        let
          firstFollow = builtins.head followList;
          restFollowList = builtins.tail followList;
        in
        if restFollowList == [ ] then
          patchedInputs.${firstFollow}
        else
          resolveFollow restFollowList patchedInputs.${firstFollow}.inputs;
    in
    {
      # <<< inputs = {
      # <<<   systems.follows = patchedInputs.dep1.inputs.systems;
      # <<<   dep1-wrapper.inputs.dep1.inputs.systems.follows = patchedInputs.systems;
      # <<< };
      inputs = lib.mapAttrs (
        inputName: inputSpec:
        let
          follows = inputSpec.follows or null;
        in
        if follows != null then
          {
            follows = resolveFollow (lib.splitString "/" follows) patchedInputs;
          }
        else
          resolveFollows {
            inherit inputSpec;
            patchedInputs = patchedInputs;
          }
      ) (inputSpec.inputs or { });
    };

  loadDeepInputSpec =
    {
      flake,
      prefix ? "",
    }:
    let
      prefixFollows =
        inputSpecs:
        lib.mapAttrs (
          inputName: inputSpec:
          let
            follows = inputSpec.follows or null;
          in
          if follows != null then
            {
              follows = prefix + follows;
            }
          else
            { inputs = prefixFollows (inputSpec.inputs or { }); }
        ) inputSpecs;
      inputSpecs = prefixFollows ((import "${flake}/flake.nix").inputs or { });
    in
    {
      inputs = lib.mapAttrs (
        inputName: inputSpec:
        let
          input = flake.inputs.${inputName};
        in
        # TODO <<< what if a "winner" wins by setting `url` (or types like
        # "github" [0], which don't even have a `url`). That should take
        # precedence over a `follows` deeper down, but with this naive
        # invocation of `lib.recursiveUpdate`, it does not.
        #
        # [0]: https://nix.dev/manual/nix/2.28/command-ref/new-cli/nix3-flake.html#types
        lib.recursiveUpdate (loadDeepInputSpec {
          flake = input;
          prefix = (if prefix == "" then inputName else "${prefix}/${inputName}") + "/";
        }) inputSpec
      ) inputSpecs;
    };
in

{
  inherit fetchpatch;
  patch =
    unpatchedInputsWithSelf: patchSpecByInputName:
    let
      self = unpatchedInputsWithSelf.self;
      unpatchedInputs = lib.removeAttrs unpatchedInputsWithSelf [ "self" ];

      deepInputSpec = loadDeepInputSpec { flake = self; };
      inputSpecByInputName =
        (resolveFollows {
          inputSpec = deepInputSpec;
          inherit patchedInputs;
        }).inputs;

      patchedInputs = patchInputs {
        inherit
          unpatchedInputs
          patchSpecByInputName
          inputSpecByInputName
          ;
      };
      patchedInputsWithSelf = patchedInputs // {
        self = self // {
          inputs = patchedInputs;
        };
      };
    in
    patchedInputsWithSelf;
}
