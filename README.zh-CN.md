<p align="center">
  <img src="CueDex/Assets.xcassets/AppIcon.appiconset/icon_128x128@2x.png" width="112" alt="CueDex 应用图标">
</p>

<h1 align="center">CueDex</h1>

<p align="center"><strong>即使视线不在编码助手，也能第一时间知道回复已经完成。</strong></p>

<p align="center">
  一款轻量的原生 macOS 工具，在 Codex 或 OpenCode 主会话完成回复时<br>
  通过屏幕边缘光效、提示音或语音提醒你。
</p>

<p align="center">
  <a href="README.md">English</a> · <a href="README.zh-CN.md">简体中文</a>
</p>

<p align="center">
  <a href="https://github.com/def-peter/CueDex/releases/latest"><img src="https://img.shields.io/github/v/release/def-peter/CueDex?style=flat-square" alt="最新版本"></a>
  <a href="https://github.com/def-peter/CueDex/releases"><img src="https://img.shields.io/github/downloads/def-peter/CueDex/total?style=flat-square" alt="下载量"></a>
  <img src="https://img.shields.io/badge/macOS-14%2B-2ea44f?style=flat-square&logo=apple" alt="需要 macOS 14 或更高版本">
  <a href="https://github.com/def-peter/CueDex/actions/workflows/release.yml"><img src="https://img.shields.io/github/actions/workflow/status/def-peter/CueDex/release.yml?style=flat-square&label=release" alt="发布工作流"></a>
  <a href="https://github.com/def-peter/CueDex/stargazers"><img src="https://img.shields.io/github/stars/def-peter/CueDex?style=flat-square" alt="GitHub Stars"></a>
  <a href="LICENSE"><img src="https://img.shields.io/github/license/def-peter/CueDex?style=flat-square" alt="MIT 许可证"></a>
</p>

当编码任务耗时较长，你可以放心切换窗口或暂时离开。CueDex 在本机监听完成事件，不保存、不上传对话内容，就能及时给出醒目或有声的提醒。

## ✨ 实际效果

<table>
  <tr>
    <td align="center" width="50%">
      <img src=".github/assets/cuedex-breathing-glow.gif" alt="屏幕四周显示绿色单色呼吸光" width="100%">
      <br><sub><strong>单色呼吸光</strong> · 柔和地增强和淡出</sub>
    </td>
    <td align="center" width="50%">
      <img src=".github/assets/cuedex-two-color-flash.gif" alt="屏幕四周显示红蓝双色交替闪烁" width="100%">
      <br><sub><strong>双色闪烁</strong> · 边缘光交替出现，默认红蓝配色</sub>
    </td>
  </tr>
</table>

以上录屏来自 CueDex 在真实 macOS Codex 工作区中的运行效果。颜色和动画可自定义；当前光效固定为 100% 强度、持续 3 秒。

## 🔔 功能

- 🎯 通过 Codex `Stop` 生命周期钩子监听主 Agent 完成事件，不会因子 Agent 完成而误报
- 🔌 可选的 OpenCode V2.1.1 全局插件，Codex / OpenCode 独立保存提醒配置；真实会话验收尚待完成
- 🌈 使用 GPU 渲染单色呼吸光或双色警灯式边缘闪烁，覆盖所有已连接显示器
- 🎛️ 按来源设置颜色、动画、macOS 提示音和本地音频；提示音与语音均跟随系统音量
- 🗣️ 通过 Apple 原生 `AVSpeechSynthesizer` 播放自定义文字，并可选择系统说话人
- 🌙 支持暂停提醒、免打扰、登录时启动和一键预览
- 🌐 支持运行时切换简体中文和英文，默认使用中文
- 🔄 每天轻量检查一次 GitHub Release，也可在“关于”中手动检查
- 🔒 事件驱动的本机处理，不轮询、不使用分析服务、不保存提示词或回复内容

## 📥 安装

**系统要求：** macOS 14 或更高版本，支持 Intel 和 Apple 芯片。

1. 从[最新 GitHub Release](https://github.com/def-peter/CueDex/releases/latest) 下载对应的 DMG：Apple 芯片（M1 或更新）选择 `arm64`，Intel 芯片选择 `x86_64`。
2. 打开 DMG，将 `CueDex.app` 移入 `/Applications`。
3. 启动 CueDex，按下方步骤启用所需集成；应用不会自动启用接入。

> [!IMPORTANT]
> CueDex 使用 ad-hoc 签名，但目前没有付费的 Apple Developer ID 证书，因此尚未经过
> Apple 公证。macOS 可能阻止首次启动，或提示无法验证开发者。这是正常的
> Gatekeeper 提示，并非系统检测到病毒。请打开**系统设置 > 隐私与安全性**，
> 找到 CueDex 提示，点击**仍要打开**并确认。

每个 Release 都附带 SHA-256 文件，可用于校验下载完整性。

## 🔌 连接 Codex

1. 打开 CueDex，选择**通用 > Codex > 启用集成**。
2. CueDex 会向 `~/.codex/hooks.json` 添加自己的 `Stop` 处理器，不会覆盖其他钩子或已有的 `notify` 命令。
3. 打开 **Codex 设置 > Hooks**，检查并信任 CueDex 钩子。
4. 如果没有看到该钩子，请重启 ChatGPT 后再次检查。

信任后，CueDex 会常驻菜单栏，并且只在主 Agent 产生新的回复并完成时提醒。

如果其他 Codex `Stop` 钩子阻止完成并要求继续执行，CueDex 无法保证等到该次继续执行结束后才提醒。

## 🔌 连接 OpenCode

1. 使用本机 **OpenCode V2.1.1**；此接入暂不支持其他版本、远程服务器、SSH 或容器。
2. 在 CueDex 中选择**通用 > OpenCode > 启用集成**，确认安装 CueDex 全局插件。无需手改 JSON、配置 MCP 或提供 API Key。
3. 安装后重新加载 OpenCode；如果插件未加载，可能需要重启其后台服务。请先等正在执行的工作结束；CueDex 不会替你重启。
4. 在主会话中发起一次新请求，正常完成后检查 CueDex 的「最近收到完成事件」。

插件只针对主会话回复成功完成，不提醒子会话、失败、取消或等待授权/输入。插件加载时已在执行的请求会保守跳过。未启用接入也能编辑配置和预览效果；预览按钮不代表连接正常。

**验证边界：** 自动化测试已通过，但真实插件加载、运行中服务兼容性和会话端到端投递尚未完成验收。详见[设计与验证记录](docs/design/opencode-support.md)。

## ⚙️ 工作原理

Codex 在主 Agent 触发 `Stop` 事件时调用轻量的本地辅助程序；OpenCode 通过全局 V2 插件观察执行与主要回复步骤的生命周期。两者只在 `~/Library/Application Support/CueDex` 中写入事件元数据并唤醒应用，文件系统事件源直接消费新事件，无需轮询。CueDex 对投递去重、使用对应来源的配置，并排队播放而不中断当前提醒。超过 60 秒的事件会被丢弃；暂停或免打扰会清空待播提醒，恢复后不补播。

提示词和回复内容不会被保存或发送到任何地方。CueDex 只会为了低频更新检查访问 GitHub Releases API。

## 🛠️ 开发

使用 Codex 的 Run 操作，或者执行以下命令构建并启动 Debug App：

```bash
./script/build_and_run.sh
```

运行单元测试和 UI 测试：

```bash
xcodebuild -project CueDex.xcodeproj -scheme CueDex \
  -destination 'platform=macOS' \
  -derivedDataPath .build/TestDerivedData \
  CODE_SIGNING_ALLOWED=NO test
```

## 📦 打包与发布

构建同时支持 Intel 和 Apple 芯片的未签名通用 DMG：

```bash
./script/package_unsigned.sh
```

也可以只构建一种架构：

```bash
./script/package_unsigned.sh --arch x86_64
./script/package_unsigned.sh --arch arm64
```

在 `main` 分支发布新版本：

```bash
./script/release.sh
```

发布脚本会更新版本号和构建编号，创建发布提交与 Tag，然后推送到 GitHub。GitHub Actions 会分别构建 `x86_64` 和 `arm64` DMG，验证 SHA-256 校验值，并将全部产物添加到 Release。

使用 `./script/release.sh --dry-run --version <x.y.z>` 可以预览发布流程，不会修改文件、提交、Tag 或远端仓库。

## 💬 反馈

欢迎通过 [GitHub Issues](https://github.com/def-peter/CueDex/issues) 提交问题和功能建议，也可以发送邮件至 [guanzhen.li@foxmail.com](mailto:guanzhen.li@foxmail.com)。

## ⭐ Star 趋势

如果 CueDex 对你有帮助，欢迎点一个 Star，让更多人看到它。

<a href="https://www.star-history.com/?repos=def-peter%2FCueDex&type=date&legend=top-left">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/chart?repos=def-peter/CueDex&type=date&theme=dark&legend=top-left&sealed_token=5nuVWzx-WQUx7nvob4_ku4QGR4Plyxbd64fWgjA7yRwk_5fr3VhB0fYSXvp3RY6VIrCGfIXj0osJ56k3LY9ALFwAFKIkIPEpdS3nsla21cmR7xmBLsyfhA">
    <source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/chart?repos=def-peter/CueDex&type=date&legend=top-left&sealed_token=5nuVWzx-WQUx7nvob4_ku4QGR4Plyxbd64fWgjA7yRwk_5fr3VhB0fYSXvp3RY6VIrCGfIXj0osJ56k3LY9ALFwAFKIkIPEpdS3nsla21cmR7xmBLsyfhA">
    <img alt="Star 趋势图" src="https://api.star-history.com/chart?repos=def-peter/CueDex&type=date&legend=top-left&sealed_token=5nuVWzx-WQUx7nvob4_ku4QGR4Plyxbd64fWgjA7yRwk_5fr3VhB0fYSXvp3RY6VIrCGfIXj0osJ56k3LY9ALFwAFKIkIPEpdS3nsla21cmR7xmBLsyfhA">
  </picture>
</a>

## 📄 许可证

由 Peter Li 创作。CueDex 使用 [MIT 许可证](LICENSE)发布。
