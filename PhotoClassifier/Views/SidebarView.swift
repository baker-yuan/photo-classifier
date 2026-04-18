import SwiftUI
import AppKit

struct SidebarView: View {
    @EnvironmentObject var vm: ClassifierViewModel
    @Binding var showAddTag: Bool
    @Binding var newTagText: String

    var body: some View {
        List {
            if let tree = vm.directoryTree {
                Section("目录") {
                    Button {
                        vm.filterTag = nil
                        vm.deselectAll()
                        vm.selectWorkingDirectory(tree.url)
                    } label: {
                        DirectoryRow(node: tree, isSelected: vm.currentDirectory?.path == tree.url.path)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("在 Finder 中显示") {
                            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: tree.url.path)
                        }
                    }
                    ForEach(tree.children) { child in
                        Button {
                            vm.filterTag = nil
                            vm.deselectAll()
                            vm.selectWorkingDirectory(child.url)
                        } label: {
                            DirectoryRow(node: child, isSelected: vm.currentDirectory?.path == child.url.path)
                                .padding(.leading, 12)
                        }
                        .buttonStyle(.plain)
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
                    Button {
                        vm.filterTag = (item.tag == "全部") ? nil : item.tag
                        vm.deselectAll()
                    } label: {
                        TagFilterRow(tag: item.tag, count: item.count,
                                     isSelected: isTagSelected(item.tag))
                    }
                    .buttonStyle(.plain)
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

    private func isTagSelected(_ tag: String) -> Bool {
        if tag == "全部" { return vm.filterTag == nil }
        return vm.filterTag == tag
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
    let isSelected: Bool

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
        .fontWeight(isSelected ? .semibold : .regular)
        .foregroundStyle(isSelected ? Color.accentColor : .primary)
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
