import SwiftUI

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
