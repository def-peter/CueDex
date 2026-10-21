<p align="center">
  <img src="CueDex/Assets.xcassets/AppIcon.appiconset/icon_128x128@2x.png" width="112" alt="CueDex app icon">
</p>

<h1 align="center">CueDex</h1>

<p align="center"><strong>Know when your coding assistant is done, even when you are looking elsewhere.</strong></p>

<p align="center">
  A lightweight native macOS utility that uses screen-edge glow, sound, or speech<br>
  when the main Codex or OpenCode session finishes responding.
</p>

<p align="center">
  <a href="README.md">English</a> · <a href="README.zh-CN.md">简体中文</a>
</p>

<p align="center">
  <a href="https://github.com/def-peter/CueDex/releases/latest"><img src="https://img.shields.io/github/v/release/def-peter/CueDex?style=flat-square" alt="Latest release"></a>
  <a href="https://github.com/def-peter/CueDex/releases"><img src="https://img.shields.io/github/downloads/def-peter/CueDex/total?style=flat-square" alt="Downloads"></a>
  <img src="https://img.shields.io/badge/macOS-14%2B-2ea44f?style=flat-square&logo=apple" alt="macOS 14 or later">
  <a href="https://github.com/def-peter/CueDex/actions/workflows/release.yml"><img src="https://img.shields.io/github/actions/workflow/status/def-peter/CueDex/release.yml?style=flat-square&label=release" alt="Release workflow"></a>
  <a href="https://github.com/def-peter/CueDex/stargazers"><img src="https://img.shields.io/github/stars/def-peter/CueDex?style=flat-square" alt="GitHub stars"></a>
  <a href="LICENSE"><img src="https://img.shields.io/github/license/def-peter/CueDex?style=flat-square" alt="MIT license"></a>
</p>

CueDex is useful when a coding task takes long enough for you to switch to another window or step away. It listens for completion events locally and gives you a visible or audible cue without persisting or sending the conversation.

## ✨ See It in Action

<table>
  <tr>
    <td align="center" width="50%">
      <img src=".github/assets/cuedex-breathing-glow.gif" alt="Green monochrome breathing glow around the screen" width="100%">
      <br><sub><strong>Breathing glow</strong> · one color, soft rise and fade</sub>
    </td>
    <td align="center" width="50%">
      <img src=".github/assets/cuedex-two-color-flash.gif" alt="Red and blue alternating edge flash around the screen" width="100%">
      <br><sub><strong>Two-color flash</strong> · alternating edge light, red and blue by default</sub>
    </td>
  </tr>
</table>

The recordings show CueDex running around a real macOS Codex workspace. Colors and animation are configurable; glow now uses fixed 100% intensity and a 3-second duration.

## 🔔 Features

- 🎯 Main-agent completion events through the Codex `Stop` lifecycle hook; subagent completions are ignored
- 🔌 Optional OpenCode V2.1.1 global plugin, with independent Codex/OpenCode cue profiles; real-session acceptance testing is still pending
- 🌈 GPU-driven monochrome breathing glow or two-color emergency-style edge flash across every connected display
- 🎛️ Per-source colors, animations, macOS sounds, and imported audio; sound and speech follow system volume
- 🗣️ Custom spoken messages and system voices through Apple's native `AVSpeechSynthesizer`
- 🌙 Pause, quiet hours, launch at login, and one-click cue previews
- 🌐 Runtime Simplified Chinese and English switching, with Chinese as the default
- 🔄 Lightweight daily GitHub Release checks plus a manual check in About
- 🔒 Event-driven local processing with no polling, analytics, or prompt/response storage

## 📥 Install

**Requirements:** macOS 14 or later, on either Intel or Apple silicon.

1. Download the correct DMG from the [latest GitHub Release](https://github.com/def-peter/CueDex/releases/latest): `arm64` for Apple silicon (M1 or later), or `x86_64` for Intel.
2. Open the DMG and move `CueDex.app` to `/Applications`.
3. Launch CueDex and enable the desired integration below. Integrations are not enabled automatically.

> [!IMPORTANT]
> CueDex is ad-hoc signed but is not notarized because it does not currently use
> a paid Apple Developer ID certificate. macOS may block the first launch or say
> that it cannot verify the developer. This is an expected Gatekeeper warning,
> not a malware detection. Open **System Settings > Privacy & Security**, find
> the CueDex message, choose **Open Anyway**, and confirm.

Every Release includes a SHA-256 file for verifying download integrity.

## 🔌 Connect to Codex

1. Open CueDex and select **General > Codex > Enable Integration**.
2. CueDex adds its `Stop` handler to `~/.codex/hooks.json` without replacing other hooks or an existing `notify` command.
3. Open **Codex Settings > Hooks** and review and trust the CueDex hook.
4. If the hook does not appear, restart ChatGPT and check again.

Once trusted, CueDex stays in the menu bar and responds only when the main agent finishes with a new assistant message.

If another Codex `Stop` hook blocks completion and asks the agent to continue, CueDex cannot guarantee that its cue waits for that continuation.

## 🔌 Connect to OpenCode

1. Use local **OpenCode V2.1.1**. Other versions, remote servers, SSH, and containers are not supported by this integration.
2. In CueDex, select **General > OpenCode > Enable Integration** and confirm installation of CueDex's global plugin. No manual JSON edits, MCP setup, or API keys are required.
3. Reload OpenCode after installation; if the plugin does not load, its background service may need restarting. Finish active work before doing so. CueDex does not restart it for you.
4. Start a new request in a main session, let it finish successfully, and check **Last completion received** in CueDex.

The plugin targets successful main-session responses, not child sessions, failures, cancellations, or permission/input waits. A request already running when the plugin loads is deliberately skipped. Cue settings remain editable when integration is disabled, and preview buttons do not verify connectivity.

**Validation boundary:** automated tests pass, but real plugin loading, service compatibility, and end-to-end session delivery have not yet been accepted. See [the design and verification record](docs/design/opencode-support.md).

## ⚙️ How It Works

Codex invokes a small local helper for the main agent's `Stop` event. OpenCode uses a global V2 plugin to observe execution and primary-step lifecycle events. Both write metadata-only local event files under `~/Library/Application Support/CueDex` and wake the app. A dispatch file-system source consumes fresh events without polling. CueDex deduplicates delivery, routes it to the matching source profile, and queues cues without interrupting playback. Events older than 60 seconds are discarded; pause and quiet hours clear pending cues without replaying them later.

Prompt and response content are never persisted or sent anywhere. CueDex only contacts the GitHub Releases API for its low-frequency update check.

## 🛠️ Development

Build and launch the Debug app with the Codex Run action or:

```bash
./script/build_and_run.sh
```

Run unit and UI tests:

```bash
xcodebuild -project CueDex.xcodeproj -scheme CueDex \
  -destination 'platform=macOS' \
  -derivedDataPath .build/TestDerivedData \
  CODE_SIGNING_ALLOWED=NO test
```

## 📦 Packaging and Release

Build an unsigned, universal DMG for Intel and Apple silicon:

```bash
./script/package_unsigned.sh
```

Or build one architecture:

```bash
./script/package_unsigned.sh --arch x86_64
./script/package_unsigned.sh --arch arm64
```

To publish a new version from `main`:

```bash
./script/release.sh
```

The release script updates the version and build number, creates the release commit and tag, and pushes them to GitHub. GitHub Actions builds separate `x86_64` and `arm64` DMGs, verifies their SHA-256 checksums, and attaches all artifacts to the Release.

Use `./script/release.sh --dry-run --version <x.y.z>` to preview the release without modifying files, commits, tags, or remotes.

## 💬 Feedback

Bug reports and feature ideas are welcome in [GitHub Issues](https://github.com/def-peter/CueDex/issues), or by email at [guanzhen.li@foxmail.com](mailto:guanzhen.li@foxmail.com).

## ⭐ Star History

If CueDex is useful to you, a star helps more people find it.

<a href="https://www.star-history.com/?repos=def-peter%2FCueDex&type=date&legend=top-left">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/chart?repos=def-peter/CueDex&type=date&theme=dark&legend=top-left&sealed_token=5nuVWzx-WQUx7nvob4_ku4QGR4Plyxbd64fWgjA7yRwk_5fr3VhB0fYSXvp3RY6VIrCGfIXj0osJ56k3LY9ALFwAFKIkIPEpdS3nsla21cmR7xmBLsyfhA">
    <source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/chart?repos=def-peter/CueDex&type=date&legend=top-left&sealed_token=5nuVWzx-WQUx7nvob4_ku4QGR4Plyxbd64fWgjA7yRwk_5fr3VhB0fYSXvp3RY6VIrCGfIXj0osJ56k3LY9ALFwAFKIkIPEpdS3nsla21cmR7xmBLsyfhA">
    <img alt="Star History Chart" src="https://api.star-history.com/chart?repos=def-peter/CueDex&type=date&legend=top-left&sealed_token=5nuVWzx-WQUx7nvob4_ku4QGR4Plyxbd64fWgjA7yRwk_5fr3VhB0fYSXvp3RY6VIrCGfIXj0osJ56k3LY9ALFwAFKIkIPEpdS3nsla21cmR7xmBLsyfhA">
  </picture>
</a>

## 📄 License

Created by Peter Li. CueDex is available under the [MIT License](LICENSE).
