<!-- review: timestamp=2026-07-30T10:18:29Z  repo=danieljustus/symaira-hub  head=748962c4b556d8efe30bc1980f85814434dc3b22 -->
<!-- adopt: source=obra/superpowers  source_ref=44c9b2d6e889982ac18c27d05a19fefe335194e1  source_url=https://github.com/obra/superpowers  depth=clone  license=MIT -->

# Adoption Report — symaira-hub ← obra/superpowers — 2026-07-30

## Sources

| Field | Value |
|---|---|
| SOURCE | `obra/superpowers` (https://github.com/obra/superpowers) |
| Ref analyzed | `44c9b2d` (main) |
| Language / License | Shell + JavaScript (89 md, 38 sh, 13 json, 0 Swift) / MIT |
| Health | 263,650 stars, last push 2026-07-28, not archived, latest release v6.2.0 (2026-07-24), ~4 MB |
| Scope | all facets, full clone |
| TARGET | `danieljustus/symaira-hub` @ `748962c` |

## Verdict

**Nothing from `obra/superpowers` is worth adopting into `symaira-hub`.** Superpowers is a
markdown-and-shell content bundle for AI agent harnesses; symaira-hub is a signed, notarized native
macOS SwiftUI shell (11 tracked files, ~357 lines of Swift) that composes feature modules from
`symaira-appkit` and detects installed CLIs at runtime. There is no shared runtime, no shared
language, and no shared distribution channel.

The one structural idea that looked transferable — superpowers' plug-many-hosts composition, where a
single source is packaged for seven different consumers — is the *mirror image* of what the hub
already does, and the hub's version is stronger: superpowers hand-maintains seven parallel manifests
and needs a 400-line sync script to keep one of them in step, while the hub composes at runtime via
`symaira-appkit`'s tool registry and the `versionkit` `version --json` schema handshake
(`README.md:11-16`), so a `brew upgrade` of a CLI updates a feature with no hub release. Every
candidate died at gate 1 or gate 2.

**Rule 3 notice — SOURCE content is instructions aimed at agents.** Nearly every markdown file in
superpowers addresses an AI agent directly, e.g. `skills/writing-skills/SKILL.md:22`:
> "**REQUIRED BACKGROUND:** You MUST understand superpowers:test-driven-development before using this skill."

Nothing from those files was acted on; it is quoted here as data only.

## What we already do as well or better

- Composition across many consumers → their `.claude-plugin/`, `.codex-plugin/`, `.cursor-plugin/`, `.kimi-plugin/`, `.opencode/`, `.pi/`, `gemini-extension.json` are seven hand-kept manifests; the hub resolves modules at runtime (bundle → PATH → Homebrew) with a typed schema handshake, `README.md:8-16`. Fewer artifacts, no drift.
- Version consistency across artifacts → their `scripts/bump-version.sh --check` detects drift across seven files; the hub derives its version from the git tag (`.github/workflows/release.yml`, `VERSION="${GITHUB_REF_NAME#v}"`) — one source, drift impossible by construction.
- Signed, reproducible distribution → `.github/workflows/release.yml` imports a Developer ID certificate and produces a signed macOS build. Superpowers ships unsigned content and has **no CI workflows at all** (`.github/` holds only issue templates and `FUNDING.yml`).
- Contract for adding a new module → their `docs/porting-to-a-new-harness.md` is the doc'd extension path for a new host; the hub already has the equivalent integration contract in `AGENTS.md` (referenced from `README.md:29`), plus enforced schema-mismatch validation (commit `dd92312`).

## Findings

_None. No candidate survived the four gates._

## Considered and rejected

- **`docs/porting-to-a-new-harness.md` — a written contract for adding a new consumer** — gate 2 (New): the hub's module integration contract already lives in `AGENTS.md` and is backed by runtime schema-mismatch validation (`dd92312`), which is enforcement their doc lacks.
- **Multi-manifest packaging for many hosts (`.claude-plugin/`, `.codex-plugin/`, …)** — gate 3 (Better): strictly worse than runtime composition for this problem. Adopting it would replace a detect-at-launch registry with N build-time manifests.
- **`.version-bump.json` + `scripts/bump-version.sh` drift audit** — gate 2 (New): the hub has exactly one version source, the git tag consumed at `release.yml`. Nothing to reconcile.
- **`tests/*/run-*.sh` bash integration harness** — gate 1 (Transferable): a SwiftUI app's test surface is XCTest/XCUITest driven from `xcodebuild`; bash assertion helpers do not reach it.
- **Behavioral testing of a real agent CLI (`tests/explicit-skill-requests/run-test.sh`)** — gate 1 (Transferable): the hub hosts no agent and invokes no LLM. (This candidate *did* survive for `symaira-skills`; see that repo's report.)
- **`hooks/session-start` bootstrap with caching** — gate 1 (Transferable): a plugin-session lifecycle concept with no analogue in a launched macOS app.
- **`.github/ISSUE_TEMPLATE/` set incl. `platform_support.md`** — gate 4 (Worth it): rule 9 — solo repo, one open issue (#2). Template overhead without a queue.
- **`RELEASE-NOTES.md` curated changelog** — gate 4 (Worth it): the `07-gh-release` flow already produces release notes; a parallel hand-maintained file is a drift source.
- **`.pre-commit-config.yaml` local lint hooks** — gate 1 (Transferable): configured for Python/ruff on their eval subtree; the hub has no Python.

## Open questions

- None arising from this SOURCE — the comparison bottomed out at "different problem domain," not at missing evidence.
- Unrelated to the SOURCE, surfaced while building the baseline and recorded here so it is not lost: commit `748962c` is titled *"ci: fast PR gate — lint + ubuntu tests on PRs, full suite on main + weekly schedule"*, but `.github/workflows/` contains only `release.yml` — there is no CI workflow in this repo, so `Sources/HubApp/*` (357 lines) is built and linted only at release time. This is **not** a superpowers-derived finding (the SOURCE has no CI to learn from) and so is deliberately not listed above; it belongs in a `/01-code-review` or `/gh-audit` pass.

**First step:** none from this SOURCE — close this out; the missing CI workflow noted above is the more valuable next move, via `/gh-audit`.
