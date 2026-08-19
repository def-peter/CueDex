# CueDex

[English](README.md) | [简体中文](README.zh-CN.md)

[![Release](https://img.shields.io/github/v/release/def-peter/CueDex?style=flat-square)](https://github.com/def-peter/CueDex/releases/latest)
[![Downloads](https://img.shields.io/github/downloads/def-peter/CueDex/total?style=flat-square)](https://github.com/def-peter/CueDex/releases)
![macOS 14+](https://img.shields.io/badge/macOS-14%2B-2ea44f?style=flat-square&logo=apple)
[![Release workflow](https://img.shields.io/github/actions/workflow/status/def-peter/CueDex/release.yml?style=flat-square&label=release)](https://github.com/def-peter/CueDex/actions/workflows/release.yml)
[![GitHub Stars](https://img.shields.io/github/stars/def-peter/CueDex?style=flat-square)](https://github.com/def-peter/CueDex/stargazers)
[![License](https://img.shields.io/github/license/def-peter/CueDex?style=flat-square)](LICENSE)

CueDex is a native macOS menu-bar utility that signals when a Codex turn finishes. It uses a soft screen-edge glow across every connected display and an optional sound cue.

## Features

- Main-agent completion events through the official Codex `Stop` lifecycle hook
- GPU-driven monochrome breathing glow or two-color emergency-style flash, with custom colors, intensity, and duration
- Built-in macOS sounds or a custom local audio file
- Custom spoken completion messages through Apple's native `AVSpeechSynthesizer`
- Runtime Simplified Chinese and English switching, with Chinese as the default
- Pause, quiet hours, launch at login, and one-click cue previews
- Lightweight daily GitHub Release checks, plus a manual check in About
- Local event processing with no prompt or response content stored

## Run

Use the Codex Run action or:

```bash
./script/build_and_run.sh
```

The app targets macOS 14 or later. Open the General tab and choose **Enable Integration**. CueDex adds a `Stop` handler to `~/.codex/hooks.json` without replacing other hooks or the existing `notify` command. Open **Codex Settings > Hooks** to review and trust the CueDex hook the first time it is installed. If the hook does not appear, restart ChatGPT and check again.

## Installation

> [!IMPORTANT]
> CueDex does not currently use a paid Apple Developer ID certificate and is
> therefore not notarized by Apple. macOS may block the first launch or report
> that it cannot verify the developer. This Gatekeeper warning is caused by the
> missing signature and notarization; it is not a malware detection.

To open CueDex after downloading it from the official
[GitHub Releases](https://github.com/def-peter/CueDex/releases):

1. Move `CueDex.app` to the Applications folder and try to open it once.
2. Open **System Settings > Privacy & Security**.
3. Find the blocked CueDex message, click **Open Anyway**, and confirm.

Each Release includes SHA-256 files for download integrity verification.

## Package

Build an unsigned, universal DMG for Intel and Apple silicon Macs:

```bash
./script/package_unsigned.sh
```

Build for one architecture only:

```bash
./script/package_unsigned.sh --arch x86_64
./script/package_unsigned.sh --arch arm64
```

The default build contains both `x86_64` and `arm64`. Every mode applies an
ad-hoc signature, verifies the requested executable architecture, verifies the
bundle and disk image, and writes the DMG and its SHA-256 checksum under
`dist/`.

This package is not notarized. On first launch, macOS may require the user to
approve CueDex in **System Settings > Privacy & Security**.

## Release

Run the interactive release command from `main`:

```bash
./script/release.sh
```

It updates the app version and build number, creates the release commit and
tag, then pushes them to GitHub. The tag triggers GitHub Actions, which builds
separate `x86_64` and `arm64` DMGs and publishes them with SHA-256 checksums.
Use `./script/release.sh --dry-run --version <x.y.z>` to preview the process
without changing files, commits, tags, or remotes.

## Architecture

Codex invokes a small local helper only for the main agent's `Stop` lifecycle event. The helper validates that the turn contains a new assistant message, deduplicates repeated `turn_id` values, writes an empty event marker under `~/Library/Application Support/CueDex`, and wakes CueDex. Prompt and response content are never persisted. Subagents emit `SubagentStop`, which CueDex does not register. A dispatch file-system source consumes fresh markers without polling. Test builds disable these runtime services so they cannot replace or duplicate the installed app's integration.

## Star History

[![Star History Chart](https://api.star-history.com/svg?repos=def-peter/CueDex&type=Date)](https://www.star-history.com/#def-peter/CueDex&Date)

## License

CueDex is available under the [MIT License](LICENSE).
