#!/usr/bin/env bash
# Validates registry.json: for every entry, re-derives the real pinned artifact's hash and
# confirms it matches wasmSha256. Catches a copy-paste/typo mistake in a pinned hash before it
# ships - the whole point of pinning is that it's checked against something, not just recorded.
#
# Two kinds of entry, hashed differently:
# - source/wrapper/metadata: the artifact is a .wasm binary, found via the manifest's own
#   "entry" field (same convention Concourse's own plugin_installer.rs uses) as a sibling of
#   manifestUrl.
# - theme: a data-only theme has no separate binary - the manifest itself *is* the whole
#   plugin, so wasmSha256 here is the hash of manifestUrl's own bytes directly. Also pinned via
#   a commit-SHA'd raw.githubusercontent.com URL rather than a tagged release asset - the
#   data-theme-plugins repo deliberately reuses one release tag ("themes") across every push
#   for a stable freeform-install URL, which makes that release asset's own URL equivalent to
#   "latest" (exactly what the check below rejects) - a specific commit is immutable regardless.
set -euo pipefail

fail=0

# Process substitution, not a pipe - a `| while read` runs the loop in a subshell, and
# `fail=1` set inside it wouldn't be visible after the loop ends.
while read -r entry; do
  id=$(echo "$entry" | jq -r '.id')
  kind=$(echo "$entry" | jq -r '.kind')
  manifest_url=$(echo "$entry" | jq -r '.manifestUrl')
  expected_sha=$(echo "$entry" | jq -r '.wasmSha256')

  echo "=== $id ==="

  if [[ "$manifest_url" == *"/releases/latest/"* ]]; then
    echo "FAIL: $id's manifestUrl points at releases/latest, not a pinned version tag"
    fail=1
    continue
  fi

  if [[ "$kind" == "theme" ]]; then
    actual_sha=$(curl -sL "$manifest_url" | sha256sum | cut -d' ' -f1)
  else
    manifest=$(curl -sL "$manifest_url")
    entry_file=$(echo "$manifest" | jq -r '.entry')
    wasm_url="${manifest_url%/*}/$entry_file"
    actual_sha=$(curl -sL "$wasm_url" | sha256sum | cut -d' ' -f1)
  fi

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
