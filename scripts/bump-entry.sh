#!/usr/bin/env bash
# Given a plugin repo (owner/name) and a release tag, rewrites that entry's manifestUrl +
# wasmSha256 in registry.json to point at the new tag, hashing the real published asset
# (never trusting a self-reported hash). Run from repo root.
set -euo pipefail

repo="$1"
tag="$2"

if ! jq -e --arg repo "$repo" '.plugins[] | select(.repo == $repo)' registry.json >/dev/null; then
  echo "FAIL: no existing registry.json entry with repo == $repo (not adding new entries automatically)"
  exit 1
fi

manifest_url="https://github.com/$repo/releases/download/$tag/plugin.json"
manifest=$(curl -sfL "$manifest_url")
entry_file=$(echo "$manifest" | jq -r '.entry')
wasm_url="https://github.com/$repo/releases/download/$tag/$entry_file"
sha=$(curl -sfL "$wasm_url" | sha256sum | cut -d' ' -f1)

tmp=$(mktemp)
jq --arg repo "$repo" --arg url "$manifest_url" --arg sha "$sha" \
  '(.plugins[] | select(.repo == $repo).manifestUrl) = $url
   | (.plugins[] | select(.repo == $repo).wasmSha256) = $sha' \
  registry.json > "$tmp"
mv "$tmp" registry.json

id=$(jq -r --arg repo "$repo" '.plugins[] | select(.repo == $repo).id' registry.json)
echo "id=$id" >> "$GITHUB_OUTPUT"
echo "sha=$sha" >> "$GITHUB_OUTPUT"
echo "Updated $id -> $tag ($sha)"
