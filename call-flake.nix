# This file was copied from nix itself, and tweaked to support patches.
# <https://github.com/NixOS/nix/blob/2.34.6/src/libflake/call-flake.nix>

{ applyPatches }:

# This is a helper to callFlake() to lazily fetch flake inputs.

# The contents of the JSON lock file, parsed.
lockFile:

# A mapping of lock file node IDs to { sourceInfo, patches ? [] } attrsets,
# - "${sourceInfo.outPath}/flake.nix" must exist
# - `patches` is a list of patches to apply to the flake source code before
#    importing it.
overrides:

let
  inherit (builtins) mapAttrs;

  # Resolve a input spec into a node name. An input spec is
  # either a node name, or a 'follows' path from the root
  # node.
  resolveInput =
    inputSpec: if builtins.isList inputSpec then getInputByPath lockFile.root inputSpec else inputSpec;

  # Follow an input attrpath (e.g. ["dwarffs" "nixpkgs"]) from the
  # root node, returning the final node.
  getInputByPath =
    nodeName: path:
    if path == [ ] then
      nodeName
    else
      getInputByPath
        # Since this could be a 'follows' input, call resolveInput.
        (resolveInput lockFile.nodes.${nodeName}.inputs.${builtins.head path})
        (builtins.tail path);

  allNodes = mapAttrs (
    key: node:
    let
      override = overrides.${key};

      inherit (override) sourceInfo patches;
      unpatchedOutPath = override.outPath;

      outPath =
        if patches == [ ] then
          unpatchedOutPath
        else
          applyPatches {
            name = "${key}-patched";
            patches = patches;
            src = unpatchedOutPath;
          };

      flake = import (outPath + "/flake.nix");

      inputs = mapAttrs (inputName: inputSpec: allNodes.${resolveInput inputSpec}.result) (
        node.inputs or { }
      );

      outputs = flake.outputs (inputs // { self = result; });

      result =
        outputs
        # We add the sourceInfo attribute for its metadata, as they are
        # relevant metadata for the flake. However, the outPath of the
        # sourceInfo does not necessarily match the outPath of the flake,
        # as the flake may be in a subdirectory of a source.
        # This is shadowed in the next //
        // sourceInfo
        // {
          # This shadows the sourceInfo.outPath
          inherit outPath;

          inherit inputs;
          inherit outputs;
          inherit sourceInfo;
          _type = "flake";
        };

    in
    {
      inherit inputs;
      result =
        if node.flake or true then
          assert builtins.isFunction flake.outputs;
          result
        else
          sourceInfo // { inherit sourceInfo outPath; };

      inherit outPath sourceInfo;
    }
  ) lockFile.nodes;

in
allNodes.${lockFile.root}
