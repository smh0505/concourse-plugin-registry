#!/usr/bin/env bash
# Validates registry.json: for every entry, fetches the manifest at manifestUrl, derives the
# sibling .wasm URL from its own "entry" field (same convention Concourse's own
# plugin_installer.rs uses), downloads it, and confirms the real hash matches wasmSha256.
# Catches a copy-paste/typo mistake in a pinned hash before it ships - the whole point of
# pinning is that it's checked against something, not just recorded.
set -euo pipefail

fail=0

# Process substitution, not a pipe - a `| while read` runs the loop in a subshell, and
# `fail=1` set inside it wouldn't be visible after the loop ends.
while read -r entry; do
  id=$(echo "$entry" | jq -r '.id')
  manifest_url=$(echo "$entry" | jq -r '.manifestUrl')
  expected_sha=$(echo "$entry" | jq -r '.wasmSha256')

  echo "=== $id ==="

  if [[ "$manifest_url" == *"/releases/latest/"* ]]; then
    echo "FAIL: $id's manifestUrl points at releases/latest, not a pinned version tag"
    fail=1
    continue
  fi

  manifest=$(curl -sL "$manifest_url")
  entry_file=$(echo "$manifest" | jq -r '.entry')
  wasm_url="${manifest_url%/*}/$entry_file"

  actual_sha=$(curl -sL "$wasm_url" | sha256sum | cut -d' ' -f1)

  if [[ "$actual_sha" != "$expected_sha" ]]; then
    echo "FAIL: $id hash mismatch"
    echo "  expected: $expected_sha"
    echo "  actual:   $actual_sha"
    fail=1
  else
    echo "OK: $actual_sha"
  fi
done < <(jq -c '.plugins[]' registry.json)

exit $fail
