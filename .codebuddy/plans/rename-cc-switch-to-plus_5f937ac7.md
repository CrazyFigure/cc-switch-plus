---
name: rename-cc-switch-to-plus
overview: 将项目安装名称从 cc-switch 改为 cc-switch-plus，避免与原 cc-switch 冲突
todos:
  - id: update-package-json
    content: 修改 package.json 中的包名为 cc-switch-plus
    status: completed
  - id: update-cargo-toml
    content: 修改 src-tauri/Cargo.toml 中的包名和库名
    status: completed
  - id: update-tauri-conf
    content: 修改 src-tauri/tauri.conf.json 中的产品名、标识符和深链接协议
    status: completed
  - id: update-windows-conf
    content: 修改 src-tauri/tauri.windows.conf.json 中的窗口标题
    status: completed
    dependencies:
      - update-tauri-conf
  - id: update-info-plist
    content: 修改 src-tauri/Info.plist 中的 URL scheme
    status: completed
    dependencies:
      - update-tauri-conf
  - id: update-flatpak-files
    content: 重命名并更新 flatpak 目录下的所有配置文件
    status: completed
    dependencies:
      - update-tauri-conf
  - id: update-deeplink-html
    content: 更新 deplink.html 中的所有深链接协议
    status: completed
    dependencies:
      - update-tauri-conf
  - id: update-source-files
    content: 更新源代码中的协议引用（Rust 和 TypeScript 文件）
    status: completed
    dependencies:
      - update-tauri-conf
  - id: update-presets
    content: 更新预设配置文件中的深链接协议
    status: completed
    dependencies:
      - update-tauri-conf
  - id: update-i18n
    content: 更新 i18n 文件中的应用名称和链接
    status: completed
    dependencies:
      - update-tauri-conf
---

## 项目概述

用户从 cc-switch 项目 fork 并添加了功能，需要将安装名称改为 cc-switch-plus，以避免与已安装的 cc-switch 冲突。

## 核心修改需求

- 修改包名：cc-switch → cc-switch-plus
- 修改产品名称：CC Switch → CC Switch Plus
- 修改应用标识符：com.ccswitch.desktop → com.ccswitchplus.desktop
- 修改深链接协议：ccswitch → ccswitchplus
- 更新所有相关配置文件中的名称和标识符

## 技术栈

- 前端：React + TypeScript + Vite
- 后端：Rust + Tauri 2.x
- 包管理：pnpm
- 构建：Tauri CLI

## 需要修改的文件清单

### 1. package.json

- name: "cc-switch" → "cc-switch-plus"

### 2. src-tauri/Cargo.toml

- name: "cc-switch" → "cc-switch-plus"
- [lib] name: "cc_switch_lib" → "cc_switch_plus_lib"

### 3. src-tauri/tauri.conf.json

- productName: "CC Switch" → "CC Switch Plus"
- identifier: "com.ccswitch.desktop" → "com.ccswitchplus.desktop"
- plugins.deep-link.desktop.schemes: ["ccswitch"] → ["ccswitchplus"]
- plugins.updater.endpoints: 更新 GitHub releases URL

### 4. src-tauri/tauri.windows.conf.json

- app.windows[0].title: "CC Switch" → "CC Switch Plus"

### 5. src-tauri/Info.plist

- CFBundleURLSchemes: "ccswitch" → "ccswitchplus"

### 6. Flatpak 文件（需要重命名）

- com.ccswitch.desktop.desktop → com.ccswitchplus.desktop.desktop
- com.ccswitch.desktop.metainfo.xml → com.ccswitchplus.desktop.metainfo.xml
- com.ccswitch.desktop.yml → com.ccswitchplus.desktop.yml
- 文件内容中的标识符同步更新

### 7. deplink.html

- 所有 ccswitch:// 协议链接改为 ccswitchplus://

### 8. 源代码中的协议引用

- src-tauri/src/lib.rs 中的深链接处理
- src-tauri/src/deeplink/*.rs 中的协议解析
- src/lib/api/deeplink.ts 中的注释和文档

### 9. 预设配置中的协议链接

- src/config/claudeProviderPresets.ts
- src/config/codexProviderPresets.ts
- src/config/geminiProviderPresets.ts
- src/config/opencodeProviderPresets.ts

### 10. i18n 文件

- src/i18n/locales/zh.json
- src/i18n/locales/ja.json
- src/i18n/locales/en.json

### 11. 其他文件

- src/contexts/UpdateContext.tsx
- src-tauri/tests/deeplink_import.rs