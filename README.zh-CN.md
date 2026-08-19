# CueDex

[English](README.md) | [简体中文](README.zh-CN.md)

[![Release](https://img.shields.io/github/v/release/def-peter/CueDex?style=flat-square)](https://github.com/def-peter/CueDex/releases/latest)
[![Downloads](https://img.shields.io/github/downloads/def-peter/CueDex/total?style=flat-square)](https://github.com/def-peter/CueDex/releases)
![macOS 14+](https://img.shields.io/badge/macOS-14%2B-2ea44f?style=flat-square&logo=apple)
[![Release workflow](https://img.shields.io/github/actions/workflow/status/def-peter/CueDex/release.yml?style=flat-square&label=release)](https://github.com/def-peter/CueDex/actions/workflows/release.yml)
[![GitHub Stars](https://img.shields.io/github/stars/def-peter/CueDex?style=flat-square)](https://github.com/def-peter/CueDex/stargazers)
[![License](https://img.shields.io/github/license/def-peter/CueDex?style=flat-square)](LICENSE)

CueDex 是一款原生 macOS 菜单栏工具，在 Codex 完成一轮回复后发出提醒。它会在所有已连接显示器的边缘显示柔和光效，也可以同时播放提示音。

## 功能

- 通过 Codex 官方的 `Stop` 生命周期钩子监听主 Agent 完成事件
- 使用 GPU 渲染单色呼吸光或双色警灯式闪烁，可自定义颜色、强度和持续时间
- 支持 macOS 内置提示音和本地音频文件
- 通过 Apple 原生 `AVSpeechSynthesizer` 播放自定义语音提醒
- 支持运行时切换简体中文和英文，默认使用中文
- 支持暂停提醒、免打扰、登录时启动和一键预览
- 所有事件均在本机处理，不保存提示词或回复内容

## 运行

使用 Codex 的 Run 操作，或者执行：

```bash
./script/build_and_run.sh
```

CueDex 支持 macOS 14 及更高版本。打开“通用”标签页并点击“启用集成”，CueDex 会在 `~/.codex/hooks.json` 中添加一个 `Stop` 处理器，不会覆盖其他钩子或已有的 `notify` 命令。首次安装后，请前往 **Codex 设置 > Hooks** 检查并信任 CueDex 钩子。如果没有看到该钩子，请重启 ChatGPT 后再次检查。

## 安装说明

> [!IMPORTANT]
> CueDex 目前没有使用付费的 Apple Developer ID 证书，因此尚未经过 Apple
> 公证。macOS 可能会阻止首次启动，或提示无法验证开发者。这是缺少开发者签名和
> 公证导致的 Gatekeeper 提示，并非系统检测到病毒。

从官方 [GitHub Releases](https://github.com/def-peter/CueDex/releases) 下载 CueDex 后：

1. 将 `CueDex.app` 移入“应用程序”文件夹，并尝试打开一次。
2. 打开“系统设置 > 隐私与安全性”。
3. 找到 CueDex 被阻止的提示，点击“仍要打开”并确认。

每个 Release 都附带 SHA-256 文件，可用于校验下载完整性。

## 打包

构建同时支持 Intel 和 Apple 芯片的未签名 DMG：

```bash
./script/package_unsigned.sh
```

也可以只构建一种架构：

```bash
./script/package_unsigned.sh --arch x86_64
./script/package_unsigned.sh --arch arm64
```

默认构建同时包含 `x86_64` 和 `arm64`。所有模式都会应用 ad-hoc 签名，检查可执行文件架构、应用包和磁盘映像，并将 DMG 及其 SHA-256 校验文件写入 `dist/`。

这些安装包尚未经过 Apple 公证。首次启动时，macOS 可能要求你在“系统设置 > 隐私与安全性”中允许打开 CueDex。

## 发布

在 `main` 分支运行交互式发布命令：

```bash
./script/release.sh
```

脚本会更新应用版本号和构建编号，创建发布提交与 Tag，然后推送到 GitHub。Tag 会触发 GitHub Actions，分别构建 `x86_64` 和 `arm64` DMG，并连同 SHA-256 校验文件发布到 GitHub Release。

使用以下命令可以预览发布流程，不会修改文件、创建提交、创建 Tag 或推送远端：

```bash
./script/release.sh --dry-run --version <x.y.z>
```

## 架构

Codex 只会在主 Agent 触发 `Stop` 生命周期事件时调用一个轻量的本地辅助程序。辅助程序会确认本轮包含新的 AI 回复，对重复的 `turn_id` 去重，在 `~/Library/Application Support/CueDex` 中写入空事件标记，并唤醒 CueDex。提示词和回复内容不会写入磁盘。

子 Agent 触发的是 `SubagentStop`，CueDex 不会注册该事件。文件系统事件源会直接消费新的标记文件，不需要轮询。测试构建会关闭这些运行时服务，避免覆盖已安装应用的集成配置或产生重复提醒。

## Star 趋势

[![Star History Chart](https://api.star-history.com/svg?repos=def-peter/CueDex&type=Date)](https://www.star-history.com/#def-peter/CueDex&Date)

## 许可证

CueDex 使用 [MIT 许可证](LICENSE)发布。
