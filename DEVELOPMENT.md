# 开发文档

## 项目概述

**照片分类 (PhotoClassifier)** 是一款 macOS 原生桌面应用，用于快速整理和分类照片/视频文件。核心理念是"目录即标签"——通过将文件移动到不同子目录来实现分类，无需数据库，分类结果直接体现在文件系统中。

## 开发环境

- **IDE:** Xcode 16.1+
- **语言:** Swift 5.9
- **框架:** SwiftUI + AppKit
- **最低部署目标:** macOS 13.0 (Ventura)
- **沙盒:** 启用 App Sandbox，仅请求用户选择文件的读写权限

## 架构设计

### MVVM 模式

```
┌─────────────────┐
│   View Layer    │  SwiftUI Views (MainView, PhotoGridView, PhotoDetailView)
│                 │  通过 @EnvironmentObject 访问 ViewModel
├─────────────────┤
│   ViewModel     │  ClassifierViewModel (@Published 属性驱动 UI 更新)
│                 │  处理所有业务逻辑、文件操作、状态管理
├─────────────────┤
│   Model Layer   │  PhotoItem (数据模型)
│                 │  ThumbnailCache (缩略图缓存)
└─────────────────┘
```

### 文件结构

| 文件 | 职责 | 行数 |
|------|------|------|
| `ClassifierApp.swift` | App 入口、WindowGroup、菜单命令 | ~30 |
| `ClassifierViewModel.swift` | 核心 ViewModel、文件操作、状态管理 | ~475 |
| `MainView.swift` | 主界面、侧边栏、工具栏、欢迎页 | ~370 |
| `PhotoGridView.swift` | 照片网格、缩略图卡片、右键菜单 | ~195 |
| `PhotoDetailView.swift` | 全屏沉浸视图、全屏窗口管理 | ~495 |
| `PhotoModel.swift` | PhotoItem 模型、ThumbnailCache | ~80 |

## 核心模块详解

### ClassifierViewModel

这是应用的核心，管理所有状态和业务逻辑。

**关键属性：**
- `@Published var photos: [PhotoItem]` — 所有照片的主数据源
- `@Published var viewMode: ViewMode` — `.grid` 或 `.detail`
- `@Published var detailIndex: Int` — 当前查看的照片索引
- `@Published var detailToast: String?` — 打标后的 Toast 提示
- `@Published var isSelectionMode: Bool` — 多选模式开关（开启后单击即选中）
- `private var isDetailTagging: Bool` — 防止并发打标的序列化标志

**核心方法：**

| 方法 | 功能 |
|------|------|
| `loadDirectory(_:preserveState:completion:)` | 扫描目录，加载照片列表 |
| `refresh()` | 重新加载目录，保留当前状态 |
| `tagCurrentDetail(_:)` | 沉浸模式下为当前照片打标 |
| `moveCurrentDetailToRoot()` | 沉浸模式下移回根目录 |
| `moveSelectedToTag(_:)` | 网格模式批量移动 |
| `moveToRoot(_:)` | 移动单张照片回根目录 |

**文件操作流程：**
```
用户点击标签按钮
  → tagCurrentDetail(tag)
  → 检查 isDetailTagging 防止并发
  → 后台线程创建目标目录（如不存在）
  → FileManager.moveItem 移动文件
  → 主线程更新 photos 数组（in-place）
  → 显示 Toast 提示
  → 更新 detailIndex（如需要）
```

### 全屏沉浸视图

全屏模式使用独立的 `NSWindow` 实现，而非 SwiftUI 的 fullScreenCover，以实现真正的全屏覆盖（包括菜单栏和 Dock）。

**架构：**
```
FullScreenDetailWindow (单例管理器)
  └── _FullScreenPanel (NSWindow 子类)
        ├── canBecomeKey = true  (borderless window 需要)
        ├── keyDown(with:)       (捕获方向键/ESC/空格)
        └── contentView = NSHostingView(PhotoDetailView)
```

**键盘事件处理：**
1. `_FullScreenPanel.keyDown()` 捕获方向键、ESC、空格
2. `NSEvent.addLocalMonitorForEvents(.keyDown)` 拦截 ⌘+数字（在菜单系统之前）
3. 通过 `NotificationCenter.detailKeyEvent` 通知传递给 SwiftUI 视图
4. `PhotoDetailView.handleKey()` 处理具体逻辑

**为什么不用 SwiftUI 的 keyboardShortcut？**
SwiftUI 的 `.keyboardShortcut` 是菜单级别的快捷键，会被主窗口的 `QuickTagButton` 拦截。使用 `NSEvent.addLocalMonitorForEvents` 可以在事件到达菜单系统之前拦截并消费。

### 缩略图缓存

`ThumbnailCache` 使用 `NSCache` 实现自动内存管理：
- 图片：通过 `CGImageSourceCreateThumbnailAtIndex` 高效生成缩略图
- 视频：通过 `AVAssetImageGenerator.copyCGImage` 提取视频帧
- 缓存上限：500 个缩略图对象
- 自动回收：系统内存不足时 NSCache 自动清理

## 已知设计决策

### 为什么"目录即标签"？

1. **无需数据库** — 分类结果直接体现在文件系统中，关闭应用不丢失
2. **跨工具兼容** — 用 Finder 也能看到分类结果
3. **简单直觉** — 用户容易理解"移动到文件夹"的概念
4. **零配置** — 打开任何有子目录的文件夹即可工作

### 为什么 in-place 更新而非 refresh？

沉浸模式下打标使用 in-place 更新（直接修改 `photos` 数组），而非重新扫描目录：
- 避免打断用户的浏览节奏
- 避免全量扫描的延迟
- 保持 `detailIndex` 稳定

### 竞态条件保护

`isDetailTagging` 标志确保同一时刻只有一个打标操作在执行。因为：
- 文件移动是异步操作
- 快速连续按键可能在前一个操作完成前触发新操作
- 第二个操作会使用已失效的文件路径

## 扩展开发

### 添加新标签类型

1. 在 `ClassifierViewModel.loadDirectory()` 中，子目录自动被识别为标签
2. 用户也可以通过 UI 的"添加标签"按钮创建新子目录
3. 颜色映射在多处使用 `hashValue % colors.count` 自动分配

### 支持新文件格式

在 `ClassifierViewModel` 中修改：
```swift
private let imageExtensions: Set<String> = [
    // 在这里添加新的图片格式
]

private let videoExtensions: Set<String> = [
    // 在这里添加新的视频格式
]
```

同时更新 `PhotoItem` 中的 `videoExtensions`。

## 测试

目前项目未包含单元测试。建议的测试方向：

1. **ViewModel 测试** — 测试 `filteredPhotos` 计算、`tagCounts` 计算
2. **文件操作测试** — 在临时目录中测试移动、重名处理
3. **状态一致性测试** — 测试打标后 `detailIndex` 的正确性
