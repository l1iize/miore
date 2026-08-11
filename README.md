# Miore

**Core, More, Miore.**

A native Minecraft launcher for macOS, built entirely in Swift ♡

[English](README.md) | [简体中文](README.zh-CN.md)

> Miore is an unofficial project and is not affiliated with Mojang Studios or Microsoft. Minecraft is a trademark of Microsoft.

## Overview

Miore brings Minecraft instances, loaders, content, Java runtimes, launch settings, and troubleshooting tools into a focused macOS experience. Its interface is designed around native controls, responsive layouts, and a customizable Home workspace without turning routine launcher tasks into a maze of panels.

## Highlights

- **100% Swift** with a native SwiftUI interface
- **macOS 12+**, with Universal 2 builds for Apple Silicon and Intel Macs
- Detects Vanilla, Fabric, Forge, NeoForge, and Quilt instances
- Installs official Minecraft versions with library, asset, and SHA-1 verification
- Installs compatible Fabric, Quilt, Forge, and NeoForge loader profiles
- Searches and installs compatible mods, dependencies, resource packs, and modpacks from Modrinth
- Resolves inherited version metadata, modern and legacy launch arguments, libraries, and macOS native dependencies
- Detects system, Homebrew, and official-launcher Java runtimes and recommends Java 8, 16, 17, or 21 as needed
- Provides instance selection, memory controls, launch and stop actions, and a live console
- Includes an editable Home workspace with draggable, resizable widgets and an 8-point layout grid
- Supports English, Simplified Chinese, Traditional Chinese, and Japanese
- Includes the optional Mio assistant for Miore guidance, Minecraft questions, and analysis of logs supplied by the user
- Supports OpenAI, DeepSeek, Anthropic, OpenRouter, Ollama, and custom OpenAI-compatible endpoints

## Microsoft Account Notice

Direct Microsoft sign-in is currently unavailable in Miore.

To use an online Minecraft account:

1. Sign in successfully through the official Minecraft Launcher on this Mac.
2. Open Miore's account management view.
3. Import the signed-in account from the official launcher.

Miore does not include or borrow another launcher's Microsoft Client ID. Imported credentials remain on the local Mac. Never share account files, access tokens, refresh tokens, or complete unredacted logs.

Offline profiles remain available for local and appropriately configured offline use.

## Requirements

- macOS 12 Monterey or later
- Swift 5.9 or later when building from source
- A Java runtime compatible with the selected Minecraft version
- The official Minecraft Launcher with a signed-in account when importing a Microsoft account
- Internet access for metadata, authentication refreshes, and content downloads

## Build From Source

```sh
git clone https://github.com/l1iize/miore.git
cd miore
swift test
./scripts/build-app.sh
open dist/Miore.app
```

The build script creates `dist/Miore.app` as a Universal 2 application for `arm64` and `x86_64`. Local builds use ad-hoc signing. Public distribution still requires an Apple Developer ID signature and notarization.

For a standard development build:

```sh
swift build
swift run Miore
```

## Getting Started

1. Open Miore and confirm the game directory in Settings.
2. Import an account from the official Minecraft Launcher, or create an offline profile.
3. Install or select a Minecraft instance.
4. Choose a compatible Java runtime and memory limit.
5. Add a loader or content when needed.
6. Select the instance on Home and launch it.

The default game directory is the official launcher location:

```text
~/Library/Application Support/minecraft
```

Miore can also use another compatible game directory containing the expected `versions`, `libraries`, and `assets` structure.

## Mio Assistant

Mio is optional. After configuring a provider, model, endpoint, and API key, Mio can:

- explain Miore features and workflows;
- answer Minecraft, loader, mod, and Java questions;
- analyze launcher output or redacted logs provided in the conversation;
- suggest troubleshooting steps.

Mio does not independently click controls, inspect arbitrary files, install content, change settings, or launch the game. API keys are stored in Miore's local configuration, and submitted logs are sanitized for common tokens and the local home-directory path.

## Current Limitations

- Direct Microsoft sign-in is unavailable; use account import from the official launcher.
- OptiFine installation opens the official OptiFine installer after downloading the matching JAR.
- Modpacks write into the selected game directory. A dedicated directory is recommended for large packs.
- Public release builds are not yet notarized, so downloaded builds may trigger a Gatekeeper warning.

## Project Status

Miore is currently in prerelease development. Features, compatibility, and integrations may change before a stable release.
