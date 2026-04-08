import SwiftUI

struct MainView: View {
    @EnvironmentObject var vm: ClassifierViewModel
    @State private var sidebarSelection: String? = "全部"
    @State private var showAddTag = false
    @State private var newTagText = ""

    var body: some View {
        Group {
            if vm.currentDirectory == nil {
                WelcomeView()
            } else {
                mainContent
            }
        }
        .onChange(of: vm.viewMode) { newMode in
            if newMode == .detail {
                FullScreenDetailWindow.shared.show(vm: vm)
            } else {
                FullScreenDetailWindow.shared.close()
            }
        }
    }

    private var mainContent: some View {
        NavigationSplitView {
            SidebarView(selection: $sidebarSelection, showAddTag: $showAddTag, newTagText: $newTagText)
                .navigationSplitViewColumnWidth(min: 180, ideal: 210, max: 260)
                .onChange(of: sidebarSelection) { newValue in
                    guard let value = newValue else { return }
                    vm.filterTag = (value == "全部") ? nil : value
                    vm.deselectAll()
                }
        } detail: {
            VStack(spacing: 0) {
                GridToolbar()
                Divider()
                PhotoGridView()
                if !vm.selectedPhotos.isEmpty {
                    Divider()
                    TaggingBar()
                }
                Divider()
                StatusBar()
            }
        }
    }
}

// MARK: - Welcome

struct WelcomeView: View {
    @EnvironmentObject var vm: ClassifierViewModel

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 72))
                .foregroundStyle(.secondary)

            Text("图片整理")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("快速标注与整理你的照片")
                .font(.title3)
                .foregroundStyle(.secondary)

            Button(action: { vm.openFolder() }) {
                Label("选择文件夹", systemImage: "folder")
                    .font(.title3)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            if !vm.recentDirectories.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("最近打开")
                        .font(.callout)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)

                    ForEach(vm.recentDirectories, id: \.path) { url in
                        HStack(spacing: 8) {
                            Button(action: { vm.openRecent(url) }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "folder.fill")
                                        .foregroundStyle(.blue)
                                        .font(.caption)
                                    Text(url.lastPathComponent)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.primary)

                            Text(url.deletingLastPathComponent().path)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                                .truncationMode(.head)

                            Spacer()

                            Button(action: { vm.removeFromRecent(url) }) {
                                Image(systemName: "xmark")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.primary.opacity(0.04))
                        )
                    }
                }
                .frame(width: 360)
            }

            VStack(spacing: 6) {
                Text("⌘O 打开文件夹")
                Text("子目录自动识别为标签归类")
                Text("双击照片进入沉浸式打标")
            }
            .font(.caption)
            .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Grid Toolbar

struct GridToolbar: View {
    @EnvironmentObject var vm: ClassifierViewModel

    var body: some View {
        HStack(spacing: 12) {
            openButton
            dirLabel
            Divider().frame(height: 20)
            sizeControls
            Spacer()
            refreshButton
            selectAllButton
            selectionModeButton
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.bar)
    }

    private var openButton: some View {
        Button(action: { vm.openFolder() }) {
            Label("打开", systemImage: "folder")
        }
        .help("打开文件夹（⌘O）")
    }

    @ViewBuilder
    private var dirLabel: some View {
        if let dir = vm.currentDirectory {
            Text(dir.lastPathComponent)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private var sizeControls: some View {
        HStack(spacing: 4) {
            Image(systemName: "photo")
                .foregroundStyle(.secondary)
                .font(.caption)
                .help("缩小缩略图")
            Slider(value: $vm.thumbnailSize, in: 80...400, step: 20)
                .frame(width: 120)
                .help("调整缩略图大小")
            Image(systemName: "photo.fill")
                .foregroundStyle(.secondary)
                .help("放大缩略图")
            Text("\(Int(vm.thumbnailSize))px")
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .frame(width: 36)
        }
    }

    private var refreshButton: some View {
        Button(action: { vm.refresh() }) {
            Label("刷新", systemImage: "arrow.clockwise")
        }
        .help("刷新文件列表")
    }

    @ViewBuilder
    private var selectAllButton: some View {
        if !vm.filteredPhotos.isEmpty {
            let filteredIDs = Set(vm.filteredPhotos.map(\.id))
            let allSel = filteredIDs.isSubset(of: vm.selectedPhotos)
            Button(action: { allSel ? vm.deselectAll() : vm.selectAll() }) {
                Label(allSel ? "取消全选" : "全选",
                      systemImage: allSel ? "square" : "checkmark.square")
            }
            .help(allSel ? "取消全选（⌘D）" : "全选照片（⌘A）")
        }
    }

    private var selectionModeButton: some View {
        Button(action: {
            vm.isSelectionMode.toggle()
            if !vm.isSelectionMode {
                vm.deselectAll()
            }
        }) {
            Label("多选", systemImage: vm.isSelectionMode ? "checkmark.circle.fill" : "checkmark.circle")
        }
        .foregroundStyle(vm.isSelectionMode ? Color.accentColor : .primary)
        .help(vm.isSelectionMode ? "关闭多选模式" : "开启多选模式（单击选中照片）")
    }
}

// MARK: - Sidebar

struct SidebarView: View {
    @EnvironmentObject var vm: ClassifierViewModel
    @Binding var selection: String?
    @Binding var showAddTag: Bool
    @Binding var newTagText: String

    var body: some View {
        List(selection: $selection) {
            if let tree = vm.directoryTree {
                Section("目录") {
                    DirectoryRow(node: tree, isSelected: vm.currentDirectory?.path == tree.url.path)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selection = "全部"
                            vm.selectWorkingDirectory(tree.url)
                        }
                        .contextMenu {
                            Button("在 Finder 中显示") {
                                NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: tree.url.path)
                            }
                        }
                    ForEach(tree.children) { child in
                        DirectoryRow(node: child, isSelected: vm.currentDirectory?.path == child.url.path)
                            .contentShape(Rectangle())
                            .padding(.leading, 12)
                            .onTapGesture {
                                selection = "全部"
                                vm.selectWorkingDirectory(child.url)
                            }
                            .contextMenu {
                                Button("在 Finder 中显示") {
                                    NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: child.url.path)
                                }
                            }
                    }
                }
            }
            Section("归类筛选") {
                ForEach(vm.tagCounts, id: \.tag) { item in
                    TagFilterRow(tag: item.tag, count: item.count)
                        .tag(item.tag)
                        .contextMenu {
                            if item.tag != "全部" && item.tag != "未归类", let dir = vm.currentDirectory {
                                Button("在 Finder 中显示") {
                                    let tagURL = dir.appendingPathComponent(item.tag)
                                    NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: tagURL.path)
                                }
                            }
                        }
                }
            }
            Section {
                Button(action: { showAddTag = true }) {
                    Label("添加标签", systemImage: "plus.circle")
                }
                .buttonStyle(.plain)
                .foregroundColor(.accentColor)
            }
            Section("快捷键") {
                ShortcutRow(key: "⌘O", desc: "打开文件夹")
                ShortcutRow(key: "⌘A", desc: "全选照片")
                ShortcutRow(key: "⌘D", desc: "取消选择")
                ShortcutRow(key: "单击", desc: "选中照片")
                ShortcutRow(key: "双击", desc: "进入沉浸打标")
                ShortcutRow(key: "⌘+点击", desc: "多选照片")
                ShortcutRow(key: "多选按钮", desc: "切换多选模式")
                ShortcutRow(key: "右键", desc: "快速归类菜单")
            }
            Section("沉浸模式") {
                ShortcutRow(key: "← →", desc: "切换上/下一张")
                ShortcutRow(key: "⌘1~9", desc: "数字键快速归类")
                ShortcutRow(key: "Space", desc: "显示/隐藏控件")
                ShortcutRow(key: "ESC", desc: "退出沉浸模式")
            }
        }
        .listStyle(.sidebar)
        .alert("添加标签（创建子目录）", isPresented: $showAddTag) {
            TextField("标签名称", text: $newTagText)
            Button("创建") { vm.addTag(newTagText); newTagText = "" }
            Button("取消", role: .cancel) { newTagText = "" }
        }
    }
}

struct DirectoryRow: View {
    let node: DirectoryNode
    let isSelected: Bool

    var body: some View {
        Label {
            Text(node.name)
                .lineLimit(1)
        } icon: {
            Image(systemName: "folder.fill")
                .foregroundStyle(isSelected ? Color.accentColor : .secondary)
        }
        .fontWeight(isSelected ? .semibold : .regular)
        .foregroundStyle(isSelected ? Color.accentColor : .primary)
    }
}

struct TagFilterRow: View {
    let tag: String
    let count: Int

    var body: some View {
        Label {
            HStack {
                Text(tag)
                Spacer()
                Text("\(count)")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                    .monospacedDigit()
            }
        } icon: {
            Image(systemName: iconName)
                .foregroundStyle(color)
        }
    }

    private var iconName: String {
        switch tag {
        case "全部": return "photo.on.rectangle"
        case "保留": return "checkmark.circle.fill"
        case "删除": return "trash.circle.fill"
        case "未归类": return "questionmark.circle"
        default: return "folder.circle.fill"
        }
    }

    private var color: Color {
        switch tag {
        case "全部": return .primary
        case "未归类": return .gray
        default: return deterministicTagColor(tag)
        }
    }
}

struct ShortcutRow: View {
    let key: String
    let desc: String

    var body: some View {
        HStack {
            Text(key)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
                .frame(width: 60, alignment: .leading)
            Text(desc)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .listRowSeparator(.hidden)
    }
}

// MARK: - Tagging Bar (batch, in grid)

struct TaggingBar: View {
    @EnvironmentObject var vm: ClassifierViewModel

    var body: some View {
        HStack(spacing: 12) {
            Text("已选 \(vm.selectedPhotos.count) 张")
                .font(.callout)
                .fontWeight(.medium)
            Divider().frame(height: 20)
            Text("移动到:")
                .font(.callout)
                .foregroundStyle(.secondary)

            tagButtons
            moveToRootButton

            Spacer()

            Button("取消选择") { vm.deselectAll() }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("取消所有选择")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.accentColor.opacity(0.06))
    }

    private var tagButtons: some View {
        ForEach(Array(vm.availableTags.enumerated()), id: \.offset) { idx, tag in
            QuickTagButton(tag: tag, index: idx)
        }
    }

    private var moveToRootButton: some View {
        Button(action: { vm.moveSelectedToRoot() }) {
            Label("移回根目录", systemImage: "arrow.uturn.backward.circle")
        }
        .buttonStyle(.bordered)
        .tint(.gray)
        .help("将选中照片移回根目录")
    }
}

struct QuickTagButton: View {
    @EnvironmentObject var vm: ClassifierViewModel
    let tag: String
    let index: Int

    var body: some View {
        Button(action: { vm.moveSelectedToTag(tag) }) {
            Label(tag, systemImage: tagIcon)
        }
        .buttonStyle(.bordered)
        .tint(tagColor)
        .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: .command)
        .help("移动到「\(tag)」（⌘\(index + 1)）")
    }

    private var tagIcon: String {
        switch tag {
        case "保留": return "checkmark.circle.fill"
        case "删除": return "trash.circle.fill"
        default: return "folder.circle.fill"
        }
    }

    private var tagColor: Color {
        deterministicTagColor(tag)
    }
}

// MARK: - Status Bar

struct StatusBar: View {
    @EnvironmentObject var vm: ClassifierViewModel

    var body: some View {
        HStack {
            if vm.isMoving {
                ProgressView()
                    .controlSize(.small)
                    .padding(.trailing, 4)
            }
            Text(vm.statusMessage)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            if !vm.photos.isEmpty {
                Text("单击选中 | 双击沉浸浏览 | ⌘+点击多选 | 右键快速归类")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.bar)
    }
}
