import SwiftUI
import AppKit

struct PhotoGridView: View {
    @EnvironmentObject var vm: ClassifierViewModel

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: vm.thumbnailSize, maximum: vm.thumbnailSize + 40), spacing: 2)]
    }

    var body: some View {
        Group {
            if vm.isLoading {
                loadingState
            } else if vm.filteredPhotos.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 2) {
                        ForEach(vm.filteredPhotos) { photo in
                            ThumbnailView(
                                photo: photo,
                                size: vm.thumbnailSize,
                                isSelected: vm.selectedPhotos.contains(photo.id),
                                showCheckbox: vm.isSelectionMode
                            )
                            .onTapGesture(count: 2) {
                                vm.openDetail(for: photo.id)
                            }
                            .onTapGesture(count: 1) {
                                let extend = vm.isSelectionMode
                                    || NSEvent.modifierFlags.contains(.shift)
                                    || NSEvent.modifierFlags.contains(.command)
                                vm.toggleSelection(photo.id, extend: extend)
                            }
                            .contextMenu {
                                contextMenuItems(for: photo)
                            }
                        }
                    }
                    .padding(4)
                }
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .animation(.easeInOut(duration: 0.2), value: vm.thumbnailSize)
    }

    private var loadingState: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(2.0)
            Text("加载中…")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: vm.photos.isEmpty ? "photo.stack" : "line.3.horizontal.decrease.circle")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            Text(vm.photos.isEmpty ? "文件夹中没有找到图片" : "当前归类下没有照片")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func contextMenuItems(for photo: PhotoItem) -> some View {
        Section("移动到") {
            ForEach(vm.availableTags, id: \.self) { tag in
                Button(action: { vm.moveSingleToTag(photo.id, tag: tag) }) {
                    HStack {
                        Text(tag)
                        if photo.tag == tag {
                            Image(systemName: "checkmark")
                        }
                    }
                }
                .disabled(photo.tag == tag)
            }
        }

        Divider()

        if photo.tag != nil {
            Button("移回根目录") { vm.moveToRoot(photo.id) }
        }

        Divider()

        Button("查看详情") { vm.openDetail(for: photo.id) }

        Button("在 Finder 中显示") {
            NSWorkspace.shared.activateFileViewerSelecting([photo.url])
        }
    }
}
