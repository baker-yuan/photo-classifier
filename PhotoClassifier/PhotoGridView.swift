import SwiftUI

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

// MARK: - Thumbnail

struct ThumbnailView: View {
    let photo: PhotoItem
    let size: CGFloat
    let isSelected: Bool
    var showCheckbox: Bool = false

    @State private var thumbnail: NSImage?
    @State private var isHovering = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            thumbnailImage
                .frame(width: size, height: size)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay {
                    if photo.isVideo {
                        ZStack {
                            Circle()
                                .fill(.black.opacity(0.5))
                                .frame(width: 32, height: 32)
                            Image(systemName: "play.fill")
                                .foregroundStyle(.white)
                                .font(.system(size: 14))
                        }
                    }
                }

            if let tag = photo.tag {
                tagBadge(tag)
            }

            if isSelected {
                selectionBorder
            }

            if showCheckbox {
                checkboxOverlay
            }
        }
        .shadow(color: isSelected ? Color.accentColor.opacity(0.3) : Color.black.opacity(0.08),
                radius: isSelected ? 4 : 2, y: isSelected ? 0 : 1)
        .onHover { isHovering = $0 }
        .onAppear { loadThumbnail() }
        .onChange(of: size) { _ in loadThumbnail() }
    }

    @ViewBuilder
    private var thumbnailImage: some View {
        if let thumb = thumbnail {
            Image(nsImage: thumb)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: size, height: size)
                .scaleEffect(isHovering ? 1.08 : 1.0)
                .animation(.easeOut(duration: 0.2), value: isHovering)
        } else {
            Rectangle()
                .fill(Color.gray.opacity(0.1))
                .frame(width: size, height: size)
                .overlay { ProgressView().controlSize(.small) }
        }
    }

    private func tagBadge(_ tag: String) -> some View {
        Text(tag)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(badgeColor(tag).opacity(0.85))
            .foregroundStyle(.white)
            .clipShape(Capsule())
            .padding(4)
    }

    private var selectionBorder: some View {
        RoundedRectangle(cornerRadius: 6)
            .stroke(Color.accentColor, lineWidth: 3)
            .frame(width: size, height: size)
    }

    private var checkboxOverlay: some View {
        ZStack {
            if isSelected {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 22, height: 22)
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
            } else {
                Circle()
                    .strokeBorder(Color.white, lineWidth: 2)
                    .frame(width: 22, height: 22)
                    .shadow(color: .black.opacity(0.3), radius: 1, y: 1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(6)
    }

    private func loadThumbnail() {
        let item = photo
        let targetSize = size
        DispatchQueue.global(qos: .userInitiated).async {
            let img = ThumbnailCache.shared.thumbnail(for: item, maxSize: max(targetSize, 200))
            DispatchQueue.main.async { thumbnail = img }
        }
    }

    private func badgeColor(_ tag: String) -> Color {
        deterministicTagColor(tag)
    }
}
