# Repository Guidelines

## Project Structure & Module Organization

`CueDex/` contains the macOS 14 application. Keep launch and scene setup in `App/`, persistent value types in `Models/`, shared observable state in `Stores/`, platform and integration work in `Services/`, reusable paths/helpers in `Support/`, and SwiftUI screens in `Views/`. Localized copy lives in `CueDex/Localizable.xcstrings`; images and bundled sounds live in `Assets.xcassets` and `Resources/Sounds`. Unit tests are in `CueDexTests/`, UI tests in `CueDexUITests/`, build utilities in `script/`, and product research or design artifacts in `docs/` and `design/`. Generated output belongs in ignored `.build/` or `dist/` directories.

## Build, Test, and Development Commands

- `./script/build_and_run.sh` builds the Debug app without signing and launches it.
- `./script/build_and_run.sh --verify` builds, launches, and confirms the process starts.
- `xcodebuild -project CueDex.xcodeproj -scheme CueDex -destination 'platform=macOS' -derivedDataPath .build/TestDerivedData CODE_SIGNING_ALLOWED=NO test` runs unit and UI test targets.
- `./script/package_unsigned.sh [--arch universal|arm64|x86_64]` creates an ad-hoc-signed DMG and SHA-256 file under `dist/`.

Use Xcode 16 or a compatible command-line toolchain. The deployment target is macOS 14.

## Coding Style & Naming Conventions

Follow existing Swift conventions: four-space indentation, one primary type per file, `UpperCamelCase` types, and `lowerCamelCase` members. Keep SwiftUI views declarative; place filesystem, audio, login-item, hook, and AppKit behavior behind focused services. UI-bound observable state should remain `@MainActor`. Prefer value types for preferences and explicit dependency injection for file systems, defaults, and paths. Add user-facing strings to the string catalog and update both English and Simplified Chinese values. No formatter or linter is configured, so match nearby code and keep diffs focused.

## Testing Guidelines

Use Swift Testing (`@Test`, `#expect`, `#require`) for unit tests and XCTest for UI launch flows. Name tests after behavior, for example `legacyMarqueeMigratesToAlternatingFlash`. Isolate `UserDefaults` with a UUID-named suite and clean temporary files in `defer`. Add regression coverage for preference decoding, migrations, managed files, localization, and event handling. Run the full `xcodebuild ... test` command before opening a pull request.

## Commit & Pull Request Guidelines

Recent history favors imperative Conventional Commit subjects such as `feat: bundle voice notification sounds` and `fix: keep settings window single instance`. Keep commits scoped and explain any compatibility or migration impact in the body. Pull requests should summarize behavior, list verification commands, link relevant issues, and include screenshots or recordings for visible UI changes. Call out localization, hook configuration, signing, or packaging changes explicitly.

## Release Workflow

For versioning, tagging, or publishing a GitHub Release, use `./script/release.sh` and follow its `--help`. A release is complete only after GitHub Actions succeeds and the Release contains both `x86_64` and `arm64` DMGs with their SHA-256 files.
