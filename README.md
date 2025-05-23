# flake-input-patcher

Utility to patch flake inputs.

This can go away when nix supports patching flake inputs:
<https://github.com/NixOS/nix/issues/3920>.

## Usage

Usage in a `flake.nix`:

```nix
{
  inputs.flake-input-patcher.url = "github:jfly/flake-input-patcher";

  outputs =
    unpatchedInputs:
    let
      # Unfortunately, this utility requires hardcoding a single system. See
      # "Known issues" below.
      patcher = unpatchedInputs.flake-input-patcher.lib.x86_64-linux;

      inputs = patcher.patch unpatchedInputs {
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
           # ... more patches here ...
        ];
      };
    in
    ...
}
```

## Known issues

- We currently doesn't understand anything about input following, so you can
  end up in inconsistent states. For example, if you patch your top level
  `nixpkgs`, that doesn't affect transitive dependencies that follow that
  `nixpkgs`. Ideally we'd parse `flake.nix` and honor the follows.
- This relies upon system-specific utilities in nixpkgs (`fetchpatch` and
  `applyPatches`), which means you have to hardcode a system to make it work.
- This depends on IFD.
