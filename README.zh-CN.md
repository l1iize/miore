# Miore

**Core, More, Miore.**

一款为 macOS 打造、100% 使用 Swift 编写的原生 Minecraft 启动器 ♡

[English](README.md) | [简体中文](README.zh-CN.md)

> Miore 是非官方项目，与 Mojang Studios、Microsoft 没有隶属或合作关系。Minecraft 是 Microsoft 的商标。

## 项目简介

Miore 将 Minecraft 实例、加载器、游戏内容、Java 运行时、启动设置和故障排查工具集中在清晰的 macOS 使用体验中。界面采用原生控件和响应式布局，并提供可自定义的 Home 工作区，让日常启动和管理操作保持简单直接。

## 主要功能

- **100% Swift 编写**，使用原生 SwiftUI 界面
- 支持 **macOS 12+**，同时提供 Apple Silicon 和 Intel Mac 的 Universal 2 构建
- 扫描并识别 Vanilla、Fabric、Forge、NeoForge 和 Quilt 实例
- 从 Mojang 官方版本清单安装 Minecraft，并校验依赖库、资源和 SHA-1
- 安装兼容的 Fabric、Quilt、Forge 和 NeoForge 加载器配置
- 通过 Modrinth 搜索并安装兼容的模组、依赖、资源包和整合包
- 解析继承版本、现代与旧版启动参数、依赖库以及 macOS 原生运行库
- 自动发现系统、Homebrew 和官方启动器中的 Java，并按需推荐 Java 8、16、17 或 21
- 提供实例选择、内存设置、启动与停止控制以及实时控制台
- 提供可编辑的 Home 工作区，支持小组件拖动、缩放和 8 点网格吸附
- 支持简体中文、繁体中文、English 和日本語
- 内置可选的 Mio 助手，可解释 Miore、回答 Minecraft 问题，并分析用户主动提供的日志
- 支持 OpenAI、DeepSeek、Anthropic、OpenRouter、Ollama 和自定义 OpenAI-compatible Endpoint

## Microsoft 账户说明

Miore **目前无法直接进行 Microsoft 登录**。

如需使用在线 Minecraft 账户，请按以下步骤操作：

1. 先在这台 Mac 的 Minecraft 官方启动器中完成登录。
2. 打开 Miore 的账户管理页面。
3. 从官方启动器导入已经登录的账户。

Miore 不会内置或借用其他启动器的 Microsoft Client ID。导入后的凭据只保存在本机。请勿分享账户文件、Access Token、Refresh Token 或未经脱敏的完整日志。

离线档案仍可用于本地游戏或经过适当配置的离线环境。

## 系统要求

- macOS 12 Monterey 或更高版本
- 从源码构建时需要 Swift 5.9 或更高版本
- 与所选 Minecraft 版本兼容的 Java 运行时
- 导入 Microsoft 账户时，需要已完成登录的 Minecraft 官方启动器
- 获取版本信息、刷新认证和下载内容时需要网络连接

## 从源码构建

```sh
git clone <your-repository-url>
cd miore
swift test
./scripts/build-app.sh
open dist/Miore.app
```

构建脚本会在 `dist/Miore.app` 生成同时支持 `arm64` 和 `x86_64` 的 Universal 2 应用。本地构建使用 ad-hoc 签名；公开分发仍需要 Apple Developer ID 签名和公证。

普通开发构建可使用：

```sh
swift build
swift run Miore
```

## 开始使用

1. 打开 Miore，在设置中确认游戏目录。
2. 从 Minecraft 官方启动器导入账户，或创建离线档案。
3. 安装或选择一个 Minecraft 实例。
4. 选择兼容的 Java 运行时并设置内存。
5. 按需安装加载器或游戏内容。
6. 在 Home 选择实例并启动游戏。

默认游戏目录为官方启动器使用的位置：

```text
~/Library/Application Support/minecraft
```

Miore 也可以使用其他兼容的游戏目录，但其中应包含正确的 `versions`、`libraries` 和 `assets` 目录结构。

## Mio 助手

Mio 是可选功能。配置 AI 服务商、模型、Endpoint 和 API Key 后，Mio 可以：

- 解释 Miore 的功能和使用流程；
- 回答 Minecraft、加载器、模组和 Java 相关问题；
- 分析对话中由用户提供的启动输出或脱敏日志；
- 给出故障排查建议。

Mio 不会自行点击界面、检查任意文件、安装内容、修改设置或启动游戏。API Key 保存在 Miore 的本地配置中；提交给 Mio 的日志会隐藏常见 Token 和本机用户目录路径。

## 当前限制

- 暂不支持直接 Microsoft 登录，请从官方启动器导入账户。
- OptiFine 会在下载匹配的官方 JAR 后打开 OptiFine 官方安装器。
- 整合包会写入当前选择的游戏目录，大型整合包建议使用独立目录。
- 公开构建暂未完成 Apple 公证，从网络下载后可能出现 Gatekeeper 提示。

## 项目状态

Miore 当前处于 prerelease 开发阶段。正式版本发布前，功能、兼容性和第三方服务集成可能继续调整。
