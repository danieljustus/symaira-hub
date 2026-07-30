# Agent Instructions — symaira-hub

The native macOS **composition shell** of the Symaira ecosystem: ONE app that
surfaces the developer tools as modules. Decided GUI strategy (see
`../docs/AGENTS.md`): modules appear only when the matching CLI is installed
(runtime detection, never a hard dependency); `symaira-terminal` and
`symaira-eraseme` stay standalone; `symaira-desktop` is the Markdown-vault
product, NOT this hub.

## Build & Test

```bash
xcodegen generate
xcodebuild -project SymairaHub.xcodeproj -scheme SymairaHub build
```

- macOS 14+, Swift 6, XcodeGen. `symaira-appkit` is public now, so no
  `-scmProvider system` / system-git-credential workaround is needed.

## Architecture & Boundaries

- **All shared plumbing comes from symaira-appkit** (pinned exact in
  `project.yml`): SymairaTheme, SymairaToolKit (registry + BinaryLocator +
  ToolDetector + `version --json` schema handshake), SymairaUpdateCheck.
  Never add hub-local Theme/Process-runner/registry code.
- **Business logic lives in the CLIs.** The hub renders their `--json`
  output; `brew upgrade <tool>` updates features without a hub release.
  A module breaks only on schema_version changes — surface an upgrade hint,
  never crash.
- **Detection is never required**: a missing CLI renders an install tile
  (`brew install danieljustus/tap/<tool>`), nothing else.

## Module Integration Contract

Per-tool feature modules are embedded step by step. A tool repo qualifies
when it provides:

1. an **SPM library package** in its repo (e.g. `symaira-scope/client` →
   `SymscopeFeature` pattern) exposing its views/view-models WITHOUT app entry
   point, pinned here via exact version or local `path:` during development
   (merged hub code must reference a tag);
2. all shared plumbing via symaira-appkit;
3. a declared `expectedSchemaVersion` compared in `ToolDetailView` against
   the CLI's detected `version --json` schema (inline check, not a
   `ToolDetector` helper).

The hub then swaps the module placeholder in `ToolDetailView` for the
package's root view, gated on `row.isInstalled`. Until a tool repo ships
such a package, its thin standalone dev app remains the reference UI.

Embedded so far: `symscope` (`SymscopeFeature`) and `symseek`
(`SymseekFeature`), both wired as local `path:` dependencies under
`Modules/` (gitignored, symlinked locally). Neither is pinned to a tag yet
— required before merging to a release branch.

## Distribution (later)

One cask (`symhub`), one release train, one signing identity — this app is
the reason the per-tool clients do not get their own casks.
