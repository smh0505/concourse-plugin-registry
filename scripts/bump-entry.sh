#!/usr/bin/env bash
# Given a registry entry's id and a ref (a version tag for source/wrapper/metadata kinds, a
# commit SHA for theme kind), rewrites that entry's manifestUrl + wasmSha256 in registry.json,
# hashing the real published/pinned artifact (never trusting a self-reported hash). Matched by
# id, not repo - data-theme-plugins hosts multiple themes (multiple registry entries) under one
# repo, so repo alone can no longer identify a single entry the way it could when every plugin
# repo mapped 1:1 to one registry entry. repo itself is read from the matched entry, not passed
# in separately, since registry.json already knows it once the entry is found by id.
set -euo pipefail

id="$1"
ref="$2"

entry=$(jq -c --arg id "$id" '.plugins[] | select(.id == $id)' registry.json)
if [[ -z "$entry" ]]; then
  echo "FAIL: no existing registry.json entry with id == $id (not adding new entries automatically)"
  exit 1
fi

repo=$(echo "$entry" | jq -r '.repo')
kind=$(echo "$entry" | jq -r '.kind')

if [[ "$kind" == "theme" ]]; then
  # ref is a commit SHA. data-theme-plugins reuses one release tag ("themes") across every
  # push, so a tagged-release asset URL would be equivalent to releases/latest - pin against
  # the immutable commit instead. id doubles as the theme's folder name under themes/.
  manifest_url="https://raw.githubusercontent.com/$repo/$ref/themes/$id/manifest.json"
  sha=$(curl -sfL "$manifest_url" | sha256sum | cut -d' ' -f1)
else
  # ref is a version tag (e.g. v0.3.2).
  manifest_url="https://github.com/$repo/releases/download/$ref/plugin.json"
  manifest=$(curl -sfL "$manifest_url")
  entry_file=$(echo "$manifest" | jq -r '.entry')
  wasm_url="https://github.com/$repo/releases/download/$ref/$entry_file"
  sha=$(curl -sfL "$wasm_url" | sha256sum | cut -d' ' -f1)
fi

tmp=$(mktemp)
jq --arg id "$id" --arg url "$manifest_url" --arg sha "$sha" \
  '(.plugins[] | select(.id == $id).manifestUrl) = $url
   | (.plugins[] | select(.id == $id).wasmSha256) = $sha' \
  registry.json > "$tmp"
mv "$tmp" registry.json

echo "id=$id" >> "$GITHUB_OUTPUT"
echo "sha=$sha" >> "$GITHUB_OUTPUT"
echo "Updated $id -> $ref ($sha)"
