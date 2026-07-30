# Contributing to SymairaHub

Thank you for your interest in contributing to SymairaHub! We welcome
contributions from everyone — whether it's a bug fix, a new feature, or
improvements to documentation.

## Table of Contents

- [Development Setup](#development-setup)
- [Build Commands](#build-commands)
- [Coding Conventions](#coding-conventions)
- [Pull Request Workflow](#pull-request-workflow)
- [Review Expectations](#review-expectations)
- [Reporting Issues](#reporting-issues)

## Development Setup

### Requirements

- **macOS 14** (Sonoma) or later
- **Xcode 16** or later
- **Homebrew** (for installing XcodeGen)

### Installing Dependencies

```bash
brew install xcodegen
```

### Getting Started

1. Clone the repository:
   ```bash
   git clone https://github.com/danieljustus/symaira-hub.git
   cd symaira-hub
   ```

2. Generate the Xcode project using XcodeGen:
   ```bash
   xcodegen generate
   ```

## Build Commands

```bash
# Generate the Xcode project from project.yml
xcodegen generate

# Build the project
xcodebuild -project SymairaHub.xcodeproj -scheme SymairaHub build

# Run tests
xcodebuild -project SymairaHub.xcodeproj -scheme SymairaHub test
```

## Coding Conventions

- **Language:** Swift 6
- **Style:** We follow the [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/).
- **Linting:** SwiftLint is used to enforce code style. Run it before
  submitting a PR:
  ```bash
  swiftlint
  ```
- **Formatting:** Use Xcode's built-in formatting (^I) or `swiftformat` if
  you prefer. Keep lines reasonably short and consistent with surrounding
  code.
- **Naming:** Use descriptive names. Prefer clarity over brevity.
- **Imports:** Group imports by层次: `SwiftUI` / system frameworks first,
  then `SymairaAppKit` / internal modules, then test imports.

## Pull Request Workflow

1. **Branch from `main`** — create a feature branch with a meaningful name
   (`fix/`, `feature/`, `docs/`, `refactor/`, etc.).
2. **Keep PRs focused** — one logical change per pull request. If you have
   multiple unrelated changes, split them into separate PRs.
3. **Write good commit messages** — follow
   [Conventional Commits](https://www.conventionalcommits.org/) when
   possible (`feat:`, `fix:`, `docs:`, `refactor:`, `test:`, `ci:`, etc.).
4. **CI must pass** — all CI checks (build, lint, tests) must be green
   before a PR can be merged.
5. **Keep your branch up to date** — rebase or merge `main` into your
   branch if there are conflicts.

## Review Expectations

- All pull requests require review before merging.
- All conversations (comments, suggestions, change requests) must be
  resolved before merging.
- Be respectful and constructive in code reviews. Assume good intent.
- If you are an external contributor, a maintainer will review your PR
  within a few business days.

## Reporting Issues

- Use GitHub Issues for bug reports and feature requests.
- For **security vulnerabilities**, do NOT open a public issue. Use the
  **Private Vulnerability Reporting** feature in the repository's Security
  tab instead. See `SECURITY.md` for details.

## License

By contributing to SymairaHub, you agree that your contributions will be
licensed under the same license as the project (see `LICENSE`).
