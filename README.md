# concourse-plugin-registry

A hand-curated list of plugins for [Concourse](https://github.com/smh0505/Concourse), covering
the two remaining bullets of Milestone 14 (plugin trust model):

- **Curated registry** - an alternative to freeform paste-any-URL, listing only plugins that
  have actually been reviewed.
- **Revocation** - pulling (or never adding) an entry here is the whole mechanism. No separate
  blocklist needed.

## What review actually means right now

Every entry here is one repo, `smh0505` (the same person who maintains Concourse itself and
every plugin currently listed). "Reviewed" means read the source of that specific pinned
version before adding it - this isn't a moderated community submission process, just an honest
record of what's actually been looked at. If/when this ever takes submissions from other
authors, this file's own honesty policy needs revisiting - it doesn't claim more than it does
today.

## What this does *not* replace

Freeform install-by-URL (paste any `plugin.json` link) still works in Concourse exactly as
before - this registry is an additional, more trustworthy path alongside it, not a required
gate. A plugin author doesn't need to be listed here to be installable.

This also does not replace Milestone 14's signing piece
(`actions/attest-build-provenance`, checked by every plugin repo's own CI and by Concourse on
install) - that proves an artifact really came from a given repo's CI. This registry answers a
different question: "has a human actually looked at this specific version." The two are
complementary, not redundant - signing without review just proves authenticity of something
nobody's read; review without signing has no way to detect the download being tampered with
after the fact.

## Format

`registry.json` - a flat list, one entry per reviewed plugin:

```json
{
  "id": "<matches the plugin's own plugin.json id>",
  "name": "<display name>",
  "kind": "source" | "wrapper" | "metadata" | "theme",
  "repo": "<owner>/<repo>",
  "manifestUrl": "<versioned release URL, never .../releases/latest/...>",
  "wasmSha256": "<sha256 of the pinned artifact, computed and pinned by hand>"
}
```

`manifestUrl` always points at a **specific, immutable version** - pointing at anything that
can change out from under it (`releases/latest/...`, a mutable tag) would mean silently
trusting whatever a plugin's author publishes next, with no review of it at all, defeating the
entire point of a curated list. Bumping which version is listed here is a deliberate, manual
edit - re-download, re-review, re-hash, re-pin. For `source`/`wrapper`/`metadata` entries this
is a tagged release asset (`releases/download/vX.Y.Z/...`); for `theme` entries it's a
**commit-SHA'd raw URL** instead (`raw.githubusercontent.com/<owner>/<repo>/<commit-sha>/<path>`)
- the `data-theme-plugins` repo deliberately reuses one release tag (`themes`) across every
push, for a stable freeform-install URL, which makes that release asset's own URL equivalent to
`latest`. A specific commit is immutable regardless of that repo's own release model.

`wasmSha256` is computed from the actual pinned artifact (not self-reported by the plugin's own
CI, and not the same thing as the Sigstore attestation's own hash) - Concourse checks a
downloaded plugin's real bytes against this pinned value before installing from this registry,
so content that doesn't match what was actually reviewed gets rejected outright, not just
flagged. For `source`/`wrapper`/`metadata` entries this is the sibling `.wasm` binary's hash;
for `theme` entries (no separate binary - the manifest *is* the whole plugin, `cssVariables`
and optionally a `cardVisual` AST) it's the hash of `manifestUrl`'s own bytes directly.

`theme` entries go through the same release-dispatch automation as every other kind -
`data-theme-plugins` dispatches per changed theme (diffing each push rather than
dispatching unconditionally, since one push there can touch any subset of its themes),
carrying a commit SHA as `ref` instead of a version tag. `bump-entry.sh` matches dispatches by
`id`, not `repo` - `data-theme-plugins` hosts multiple themes (multiple registry entries) under
one repo, unlike every other plugin repo's 1:1 mapping, so `repo` alone can no longer identify
a single entry the way it used to.
