# Contributing

Thanks for your interest!

1. Make your change.
2. Run the tests: `nix eval ./tests#failedTests --json | jq`
   This should return an empty array (no failed tests).
3. `nix fmt`
4. Send a PR!
