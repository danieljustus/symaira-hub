# Symaira Hub

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
modules are embedded incrementally — see `AGENTS.md` for the integration
contract.

## License

Apache-2.0
