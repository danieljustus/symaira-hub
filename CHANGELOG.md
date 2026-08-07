# Changelog

All notable changes to Symaira Hub are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.3.0] - 2026-08-07

### Added
- Per-adapter discovery failures surfaced; source inspector model extracted (#71)
- Real symskills discovery adapter wired into the source inspector (#31)
- Symmemory source discovery wired into the hub (#32)
- Shared design-system components adopted across the UI (#34)
- First unit-test target and CI build/test jobs (#55)

### Changed
- Tool re-detection skipped within the refresh TTL (perf) (#66, #72)
- Shared discovery error mapping with stderr redaction (#69)
- SourceDecisionStore persistence debounced (#67, #70)
- Discovery binaries resolved via BinaryLocator with symskills schema handshake (#50)
- Duplicated subprocess code replaced with the shared CLIRunner (#49)
- Tool detection runs concurrently (perf) (#51)
- UI copy unified to English (#54)
- Discovery coverage gaps closed (#58)

### Fixed
- Feature modules pinned to tags; release pipeline repaired (#56)
- Source inspector stays reachable when nothing is pending (#53)
- Snooze is temporary — hidden now, reappears on next scan (#52)
- Release workflow notarization uses the correct notarytool API-key auth flow (#73)

### Security
- Module checkouts and action versions pinned to SHAs (supply-chain hardening) (#68)
- CodeQL action bumped (#35)

### Docs
- "Why Symaira Hub" section and JSON contract sample (#59)
- Install and usage sections with screenshot (#57)
- README badges and review-report gitignore entries (#48)

## [0.2.0] - 2026-07-31

### Added
- Pending-source inspector with Add/Ignore/Review-later decisions (#30)

### Changed
- Docs updated; app icon and branding assets added

### Fixed
- `mkdir -p Modules` before symlinking modules in the release workflow

### Docs
- Versioned source discovery contract v1 (#29)
- Squash-only merge strategy documented in CONTRIBUTING.md (#23)

### Security
- CodeQL action bumped from 3 to 4 (#22)

## [0.1.0] - 2026-07-30

### Added
- Initial Symaira Hub scaffolding — native macOS composition shell
- SymscopeFeature embedded as the first hub module
- Module detail view with local dev symlinks
- Schema-mismatch validation for embedded modules
- PR CI and lint workflows

### Security
- CodeQL analysis and Dependabot config (#21)

---

## Maintenance

- New changes are added under `[Unreleased]` as they land on `main`.
- At release time, rename `[Unreleased]` to the new version, add the release
  date, and open a fresh `[Unreleased]` section.
- Entries reference issue or PR numbers (`#NNN`) and are grouped by
  `Added` / `Changed` / `Fixed` / `Security` / `Docs`.
