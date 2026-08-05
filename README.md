# Symaira Hub

![Symaira Hub social preview](docs/assets/social-preview.png)

[![CI](https://github.com/danieljustus/symaira-hub/actions/workflows/ci.yml/badge.svg)](https://github.com/danieljustus/symaira-hub/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/danieljustus/symaira-hub)](https://github.com/danieljustus/symaira-hub/releases)
[![License](https://img.shields.io/badge/License-Apache--2.0-blue.svg)](LICENSE)

The native macOS control center for the [Symaira](https://symaira.com)
developer tools — one app, composed of modules that light up when the
matching CLI is installed.

- **Runtime composition, no hard dependencies:** the hub detects installed
  Symaira CLIs (bundle → PATH → Homebrew) and shows an install tile for the
  rest. Logic stays in the CLIs; `brew upgrade` updates features without a
  hub release.
- **Shared foundations:** built on [`symaira-appkit`](https://github.com/danieljustus/symaira-appkit)
  (design tokens, tool registry, binary discovery, `version --json` schema
  handshake).
- **Deliberately not included:** [Symaira Terminal](https://github.com/danieljustus/symaira-terminal)
  and Symaira EraseMe ship as standalone apps.

## Build

```bash
brew install xcodegen
xcodegen generate
xcodebuild -project SymairaHub.xcodeproj -scheme SymairaHub build
```

Requires macOS 14+, Xcode 16+.

## Status

Scaffolding: tool detection, dashboard, install tiles. Per-tool feature
modules are embedded incrementally — `symscope` and `symseek` are wired in
so far — see `AGENTS.md` for the integration contract.

## License

Apache-2.0
