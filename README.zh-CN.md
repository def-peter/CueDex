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
- 🔌 可选的 OpenCode 2.x（>= 2.1.1 且 < 3.0.0）稳定版全局插件，Codex / OpenCode 独立保存提醒配置；已在 2.1.1 下确认本机 CLI 和 OpenChamber 2.5.0 的真实提醒
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

**钩子由 CueDex 自动安装，无需手改 JSON 或复制命令。** 仅安装 CueDex 不会启用集成；Codex 中的信任确认是用户安全授权，不是手动配置步骤。

1. 打开 CueDex，选择**通用 > Codex > 启用集成**，查看目标文件并确认。CueDex 会安装本地辅助程序，并向 `~/.codex/hooks.json` 添加自己的 `Stop` 处理器，保留其他钩子和不属于 CueDex 的 `notify` 命令。如果为 CueDex 设置了 `CODEX_HOME`，钩子文件则位于该目录。
2. 打开 **Codex 设置 > Hooks**，在 **`Stop` 事件**下，找到命令包含 **`cuedex-notify`** 的那条，检查并信任。当前钩子没有独立显示名称，不要依赖界面出现名为「CueDex」的一行。默认命令指向：

   ```text
   ~/Library/Application Support/CueDex/bin/cuedex-notify
   ```

   CueDex 的通用设置也会显示实际的「**钩子事件**」和「**钩子命令**」，方便逐项核对。CueDex 无法确认信任状态，也不会代替用户授予 Codex 钩子信任。
3. 如果没有看到该钩子，请先等当前任务结束，重启 Codex 后再次检查；CueDex 不会替你重启。
4. 让**主会话完成一次新请求**，检查 CueDex 的「最近收到完成事件」。「已配置」仅代表钩子已安装，不代表已信任或已连接；「测试 Codex」只是本地效果预览，不能验证接入。

信任且加载后，CueDex 会常驻菜单栏，并且只在主 Agent 产生新的回复并完成时提醒。停用集成只移除 CueDex 自己的钩子，保留其他钩子和已保存的提醒配置。

如果其他 Codex `Stop` 钩子阻止完成并要求继续执行，CueDex 无法保证等到该次继续执行结束后才提醒。

## 🔌 连接 OpenCode

> [!IMPORTANT]
> **仅安装 CueDex，OpenCode 提醒不会自动生效。** 你需要主动启用集成，将插件安装到 OpenCode 中，再重载客户端实际使用的 OpenCode 服务。无需手改 JSON、配置 MCP 或提供 API Key。

1. 确认**实际运行的本机 OpenCode 后端在受支持的 2.x 稳定版范围（>= 2.1.1 且 < 3.0.0）内**。预发布版本、该范围外的其他版本、远程服务器、SSH 或容器均不受支持。CueDex 的「检测到的 CLI 版本」只检查本机可执行文件，不一定是客户端正在使用的后端版本。
2. 在 CueDex 中选择**通用 > OpenCode > 启用集成**，查看插件路径并确认安装。CueDex 会将受管理的全局插件写入 `~/.config/opencode/plugins/cuedex.js`，作用于本地项目，保留其他插件；停用集成时只移除 CueDex 自己的插件，保留提醒配置。
3. 等当前任务结束后，重载 CLI 或客户端实际使用的 OpenCode 服务。如果只重载客户端仍未加载插件，请自行重启其 OpenCode 后端。CueDex 不会替你重启工具或服务。
4. 在**主会话中发起一次新请求**，正常完成后检查 CueDex 的「最近收到完成事件」。「已配置」仅代表插件已安装，不代表事件投递已经验证；「测试 OpenCode」只是本地效果预览，不能验证接入。

**更新已有集成：** 正式版 CueDex 启动时会自动将已启用的受管理 OpenCode 插件刷新至最新模板，并保留原有的安装代际标记。应用不会替未启用的环境自动开启接入，绝不改动非 CueDex 管理的文件，脚本一致时跳过写盘。若文件写盘触发了 OpenCode 重新加载插件，正在进行的当前轮次可能会跳过提醒；当 OpenCode 完成升级后，请等当前任务结束并重载其实际使用的服务，以加载最新的桥接脚本。

### 在 OpenChamber 中使用

即使终端中的 `opencode --version` 显示支持的版本，OpenChamber 也可能运行自己的内置 OpenCode 后端。本次实际检查的 OpenChamber **2.5.0** 内置后端为 **2.0.32**，CueDex 插件会主动跳过该版本。

1. 在 OpenChamber 中打开**设置 > OpenChamber 分组 > 通用 > OpenCode CLI**。
2. 将「**OpenCode 可执行文件路径（OpenCode binary path）**」设为已安装的受支持 2.x（>= 2.1.1）程序的绝对路径。可在终端用 `command -v opencode` 查路径，用 `opencode --version` 核对版本。例如本机为 `/usr/local/bin/opencode`，你的路径可能不同。
3. 等当前任务结束，点击「**保存并重载（Save + reload）**」，然后让主会话完成一次新请求，确认收到提醒。

实例菜单中的 **Local · 127.0.0.1:…** 是 OpenChamber 的服务地址，不是 OpenCode 程序路径，也不能说明后端版本；不需要通过修改这个地址解决问题。

插件只针对主会话回复成功完成，不提醒子会话、失败、取消或等待授权/输入。插件加载时已在执行的请求会保守跳过。未启用接入也能编辑配置和预览效果；预览按钮不代表连接正常。

**验证边界：** 2026-10-21，用户已确认本机 OpenCode CLI 的真实提醒，以及 OpenChamber 2.5.0 切换到 2.1.1 后端并重载后的真实提醒。已对 2.1.1 与 2.1.3 官方 npm 发布包完成静态校验，确认插件与核心事件兼容，但 2.1.3 的真实用户会话尚未完成端到端验收。这不代表支持 2.x 稳定版（>= 2.1.1 且 < 3.0.0）以外的版本，也不代表多效果播放结束时机及 Codex Stop-hook 边界检查全部完成。详见[设计与验证记录](docs/design/opencode-support.md)。

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
