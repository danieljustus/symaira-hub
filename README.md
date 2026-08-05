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

## Install

**Download from [Releases](https://github.com/danieljustus/symaira-hub/releases)**
— grab the latest `SymairaHub-<version>.dmg`, open it, and drag the app to
Applications.

> A Homebrew cask (`brew install danieljustus/tap/symhub`) is planned.

## Usage

![Symaira Hub screenshot](docs/assets/screenshot.png)

Launch Symaira Hub. The sidebar shows every tool in the Symaira registry:

- **Installed** tools appear with their detected version; clicking one opens
  its embedded module (e.g. the symscope or symseek feature UI). A
  schema-version mismatch shows the upgrade hint with the exact
  `brew upgrade <tool>` command.
- **Available** tools that are not installed show an install tile with the
  matching `brew install` command.
- **Sources** (bottom of the sidebar) opens the source inspector: candidates
  discovered by installed tools (e.g. `symmemory`, `symskills`) can be
  added, ignored, or reviewed later per source; ignored sources can be
  reset at any time.

Click the refresh button (or relaunch the app) to re-detect tools and
re-scan sources. The hub never requires a tool to be installed — missing
CLIs simply render an install tile.

## Build

```bash
brew install xcodegen
xcodegen generate
xcodebuild -project SymairaHub.xcodeproj -scheme SymairaHub build
```

Requires macOS 14+, Xcode 16+.

## Status

Tool detection, dashboard, install tiles, source inspector. Per-tool
feature modules are embedded incrementally — `symscope` and `symseek` are
wired in so far — see `AGENTS.md` for the integration contract.

## License

Apache-2.0
