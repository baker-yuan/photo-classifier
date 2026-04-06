import SwiftUI
import AppKit

enum ViewMode {
    case grid, detail
}

final class ClassifierViewModel: ObservableObject {
    @Published var photos: [PhotoItem] = []
    @Published var selectedPhotos: Set<UUID> = []
    @Published var thumbnailSize: CGFloat = 160
    @Published var currentDirectory: URL?
    @Published var availableTags: [String] = []
    @Published var filterTag: String?
    @Published var isMoving = false
    @Published var statusMessage = "选择一个文件夹开始归类"
    @Published var viewMode: ViewMode = .grid
    @Published var detailIndex: Int = 0
    @Published var detailToast: String?
    @Published var isSelectionMode = false
    @Published var recentDirectories: [URL] = []

    private static let recentBookmarksKey = "recentDirectoryBookmarks"
    private static let maxRecent = 10

    private var isDetailTagging = false
    private var toastGeneration = 0
    private var accessedSecurityScopedURL: URL?

    private let imageExtensions: Set<String> = [
        "jpg", "jpeg", "png", "heic", "heif", "tiff", "tif", "bmp", "gif", "webp", "raw", "cr2", "nef", "arw"
    ]

    private var supportedExtensions: Set<String> {
        imageExtensions.union(PhotoItem.videoExtensions)
    }

    init() {
        recentDirectories = Self.loadRecentDirectories()
    }

    // MARK: - Recent Directories

    private static func loadRecentDirectories() -> [URL] {
        guard let bookmarks = UserDefaults.standard.array(forKey: recentBookmarksKey) as? [Data] else { return [] }
        var urls: [URL] = []
        var updatedBookmarks: [Data] = []
        var needsSave = false
        for data in bookmarks {
            var isStale = false
            if let url = try? URL(resolvingBookmarkData: data, options: [.withSecurityScope], relativeTo: nil, bookmarkDataIsStale: &isStale) {
                urls.append(url)
                if isStale, let newData = try? url.bookmarkData(options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil) {
                    updatedBookmarks.append(newData)
                    needsSave = true
                } else {
                    updatedBookmarks.append(data)
                }
            } else {
                needsSave = true
            }
        }
        if needsSave {
            UserDefaults.standard.set(updatedBookmarks, forKey: recentBookmarksKey)
        }
        return urls
    }

    private func addToRecent(_ url: URL) {
        recentDirectories.removeAll { $0.path == url.path }
        recentDirectories.insert(url, at: 0)
        if recentDirectories.count > Self.maxRecent {
            recentDirectories = Array(recentDirectories.prefix(Self.maxRecent))
        }
        let bookmarks = recentDirectories.compactMap {
            try? $0.bookmarkData(options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil)
        }
        UserDefaults.standard.set(bookmarks, forKey: Self.recentBookmarksKey)
    }

    func removeFromRecent(_ url: URL) {
        recentDirectories.removeAll { $0.path == url.path }
        let bookmarks = recentDirectories.compactMap {
            try? $0.bookmarkData(options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil)
        }
        UserDefaults.standard.set(bookmarks, forKey: Self.recentBookmarksKey)
    }

    func openRecent(_ url: URL) {
        accessedSecurityScopedURL?.stopAccessingSecurityScopedResource()
        accessedSecurityScopedURL = nil
        if url.startAccessingSecurityScopedResource() {
            accessedSecurityScopedURL = url
        }
        addToRecent(url)
        loadDirectory(url)
    }

    deinit {
        accessedSecurityScopedURL?.stopAccessingSecurityScopedResource()
    }

    // MARK: - Computed

    var filteredPhotos: [PhotoItem] {
        guard let filter = filterTag else { return photos }
        if filter == "未归类" { return photos.filter { $0.tag == nil } }
        return photos.filter { $0.tag == filter }
    }

    var tagCounts: [(tag: String, count: Int)] {
        var result: [(String, Int)] = [("全部", photos.count)]
        for tag in availableTags {
            result.append((tag, photos.filter { $0.tag == tag }.count))
        }
        result.append(("未归类", photos.filter { $0.tag == nil }.count))
        return result
    }

    var currentDetailPhoto: PhotoItem? {
        let list = filteredPhotos
        guard detailIndex >= 0, detailIndex < list.count else { return nil }
        return list[detailIndex]
    }

    // MARK: - Folder (2-level directory)

    func openFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "选择照片根目录（子目录为标签归类）"
        panel.prompt = "选择"

        if panel.runModal() == .OK, let url = panel.url {
            accessedSecurityScopedURL?.stopAccessingSecurityScopedResource()
            accessedSecurityScopedURL = nil
            addToRecent(url)
            loadDirectory(url)
        }
    }

    func loadDirectory(_ directory: URL, preserveState: Bool = false, completion: (() -> Void)? = nil) {
        currentDirectory = directory
        if !preserveState {
            photos = []
            selectedPhotos = []
            filterTag = nil
            viewMode = .grid
            detailIndex = 0
            isSelectionMode = false
        }
        availableTags = []
        ThumbnailCache.shared.clear()

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let fm = FileManager.default
            var allPhotos: [PhotoItem] = []
            var tags: [String] = []

            do {
                let topContents = try fm.contentsOfDirectory(
                    at: directory,
                    includingPropertiesForKeys: [.isDirectoryKey],
                    options: [.skipsHiddenFiles]
                )

                for item in topContents {
                    let resourceValues = try? item.resourceValues(forKeys: [.isDirectoryKey])
                    if resourceValues?.isDirectory == true {
                        let tagName = item.lastPathComponent
                        tags.append(tagName)

                        let subContents = try fm.contentsOfDirectory(
                            at: item,
                            includingPropertiesForKeys: [.isRegularFileKey],
                            options: [.skipsHiddenFiles]
                        )
                        for file in subContents {
                            if self.supportedExtensions.contains(file.pathExtension.lowercased()) {
                                var photo = PhotoItem(url: file)
                                photo.tag = tagName
                                allPhotos.append(photo)
                            }
                        }
                    } else {
                        if self.supportedExtensions.contains(item.pathExtension.lowercased()) {
                            allPhotos.append(PhotoItem(url: item))
                        }
                    }
                }

                allPhotos.sort { a, b in
                    let dA = (try? a.url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
                    let dB = (try? b.url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
                    return dA > dB
                }

                if !tags.contains("保留") { tags.insert("保留", at: 0) }
                if !tags.contains("删除") {
                    let idx = min(1, tags.count)
                    tags.insert("删除", at: idx)
                }

                DispatchQueue.main.async {
                    self.availableTags = tags
                    self.photos = allPhotos
                    let untagged = allPhotos.filter { $0.tag == nil }.count
                    self.statusMessage = "已加载 \(allPhotos.count) 张照片，\(untagged) 张未归类 — \(directory.lastPathComponent)"
                    completion?()
                }
            } catch {
                DispatchQueue.main.async {
                    self.statusMessage = "加载失败: \(error.localizedDescription)"
                    completion?()
                }
            }
        }
    }

    func refresh() {
        guard let dir = currentDirectory else { return }
        let savedFilter = filterTag
        let savedViewMode = viewMode
        let savedDetailIndex = detailIndex
        selectedPhotos = []
        loadDirectory(dir, preserveState: true) { [weak self] in
            guard let self = self else { return }
            self.filterTag = savedFilter
            self.viewMode = savedViewMode
            if savedViewMode == .detail {
                let count = self.filteredPhotos.count
                if count == 0 {
                    self.viewMode = .grid
                } else {
                    self.detailIndex = min(savedDetailIndex, count - 1)
                }
            }
        }
    }

    // MARK: - Selection

    func toggleSelection(_ id: UUID, extend: Bool = false) {
        if extend {
            if selectedPhotos.contains(id) { selectedPhotos.remove(id) }
            else { selectedPhotos.insert(id) }
        } else {
            selectedPhotos = selectedPhotos == [id] ? [] : [id]
        }
    }

    func selectAll() { selectedPhotos = Set(filteredPhotos.map(\.id)) }
    func deselectAll() { selectedPhotos = [] }

    // MARK: - Tagging = Move file immediately (Grid mode)

    func moveSelectedToTag(_ tag: String) {
        guard let dir = currentDirectory else { return }
        guard !selectedPhotos.isEmpty else { return }
        let idsToMove = selectedPhotos
        selectedPhotos = []
        isMoving = true

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let fm = FileManager.default
            let tagFolder = dir.appendingPathComponent(tag)
            var moved = 0

            do {
                if !fm.fileExists(atPath: tagFolder.path) {
                    try fm.createDirectory(at: tagFolder, withIntermediateDirectories: true)
                }
            } catch {
                DispatchQueue.main.async {
                    self.isMoving = false
                    self.statusMessage = "创建目录失败: \(error.localizedDescription)"
                }
                return
            }

            for id in idsToMove {
                guard let photo = self.photos.first(where: { $0.id == id }) else { continue }
                if photo.tag == tag { continue }
                do {
                    var dest = tagFolder.appendingPathComponent(photo.fileName)
                    if fm.fileExists(atPath: dest.path) {
                        let stem = photo.url.deletingPathExtension().lastPathComponent
                        let ext = photo.url.pathExtension
                        dest = tagFolder.appendingPathComponent("\(stem)_\(UUID().uuidString.prefix(6)).\(ext)")
                    }
                    try fm.moveItem(at: photo.url, to: dest)
                    moved += 1
                } catch { /* skip failed ones */ }
            }

            DispatchQueue.main.async {
                self.isMoving = false
                self.statusMessage = "已移动 \(moved) 张照片到「\(tag)」"
                self.refresh()
            }
        }
    }

    func moveSingleToTag(_ photoID: UUID, tag: String) {
        guard let dir = currentDirectory else { return }
        guard let photo = photos.first(where: { $0.id == photoID }) else { return }
        if photo.tag == tag { return }

        let fm = FileManager.default
        let tagFolder = dir.appendingPathComponent(tag)

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                if !fm.fileExists(atPath: tagFolder.path) {
                    try fm.createDirectory(at: tagFolder, withIntermediateDirectories: true)
                }
                var dest = tagFolder.appendingPathComponent(photo.fileName)
                if fm.fileExists(atPath: dest.path) {
                    let stem = photo.url.deletingPathExtension().lastPathComponent
                    let ext = photo.url.pathExtension
                    dest = tagFolder.appendingPathComponent("\(stem)_\(UUID().uuidString.prefix(6)).\(ext)")
                }
                try fm.moveItem(at: photo.url, to: dest)
                DispatchQueue.main.async {
                    self?.statusMessage = "已将「\(photo.fileName)」移动到「\(tag)」"
                    self?.refresh()
                }
            } catch {
                DispatchQueue.main.async {
                    self?.statusMessage = "移动失败: \(error.localizedDescription)"
                }
            }
        }
    }

    func moveToRoot(_ photoID: UUID) {
        guard let dir = currentDirectory else { return }
        guard let photo = photos.first(where: { $0.id == photoID }), photo.tag != nil else { return }

        let fm = FileManager.default

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                var dest = dir.appendingPathComponent(photo.fileName)
                if fm.fileExists(atPath: dest.path) {
                    let stem = photo.url.deletingPathExtension().lastPathComponent
                    let ext = photo.url.pathExtension
                    dest = dir.appendingPathComponent("\(stem)_\(UUID().uuidString.prefix(6)).\(ext)")
                }
                try fm.moveItem(at: photo.url, to: dest)
                DispatchQueue.main.async {
                    self?.statusMessage = "已将「\(photo.fileName)」移回根目录"
                    self?.refresh()
                }
            } catch {
                DispatchQueue.main.async {
                    self?.statusMessage = "移动失败: \(error.localizedDescription)"
                }
            }
        }
    }

    func moveSelectedToRoot() {
        guard let dir = currentDirectory else { return }
        guard !selectedPhotos.isEmpty else { return }
        let idsToMove = selectedPhotos
        selectedPhotos = []
        isMoving = true

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let fm = FileManager.default
            var moved = 0

            for id in idsToMove {
                guard let photo = self.photos.first(where: { $0.id == id }), photo.tag != nil else { continue }
                do {
                    var dest = dir.appendingPathComponent(photo.fileName)
                    if fm.fileExists(atPath: dest.path) {
                        let stem = photo.url.deletingPathExtension().lastPathComponent
                        let ext = photo.url.pathExtension
                        dest = dir.appendingPathComponent("\(stem)_\(UUID().uuidString.prefix(6)).\(ext)")
                    }
                    try fm.moveItem(at: photo.url, to: dest)
                    moved += 1
                } catch { /* skip */ }
            }

            DispatchQueue.main.async {
                self.isMoving = false
                self.statusMessage = "已移回 \(moved) 张照片到根目录"
                self.refresh()
            }
        }
    }

    // MARK: - Add Tag = Create subdirectory

    func addTag(_ name: String) {
        let t = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, !availableTags.contains(t), let dir = currentDirectory else { return }

        let tagFolder = dir.appendingPathComponent(t)
        let fm = FileManager.default
        do {
            if !fm.fileExists(atPath: tagFolder.path) {
                try fm.createDirectory(at: tagFolder, withIntermediateDirectories: true)
            }
            availableTags.append(t)
            statusMessage = "已创建标签「\(t)」"
        } catch {
            statusMessage = "创建标签失败: \(error.localizedDescription)"
        }
    }

    // MARK: - Detail Navigation

    func openDetail(for id: UUID) {
        if let idx = filteredPhotos.firstIndex(where: { $0.id == id }) {
            detailIndex = idx
            viewMode = .detail
        }
    }

    func closeDetail() { viewMode = .grid }

    func nextPhoto() {
        if detailIndex < filteredPhotos.count - 1 { detailIndex += 1 }
    }

    func previousPhoto() {
        if detailIndex > 0 { detailIndex -= 1 }
    }

    // MARK: - Detail Tagging (in-place, no refresh)

    /// Tag current detail photo in-place. Serialized to prevent race conditions.
    func tagCurrentDetail(_ tag: String) {
        guard !isDetailTagging else { return }
        guard let dir = currentDirectory else { return }
        guard let photo = currentDetailPhoto, photo.tag != tag else { return }
        guard let photoIdx = photos.firstIndex(where: { $0.id == photo.id }) else { return }

        isDetailTagging = true
        let fm = FileManager.default
        let tagFolder = dir.appendingPathComponent(tag)

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                if !fm.fileExists(atPath: tagFolder.path) {
                    try fm.createDirectory(at: tagFolder, withIntermediateDirectories: true)
                }
                var dest = tagFolder.appendingPathComponent(photo.fileName)
                if fm.fileExists(atPath: dest.path) {
                    let stem = photo.url.deletingPathExtension().lastPathComponent
                    let ext = photo.url.pathExtension
                    dest = tagFolder.appendingPathComponent("\(stem)_\(UUID().uuidString.prefix(6)).\(ext)")
                }
                try fm.moveItem(at: photo.url, to: dest)

                DispatchQueue.main.async {
                    guard let self = self else { return }
                    guard let freshIdx = self.photos.firstIndex(where: { $0.id == photo.id }) else {
                        self.isDetailTagging = false
                        return
                    }
                    self.photos[freshIdx].url = dest
                    self.photos[freshIdx].fileName = dest.lastPathComponent
                    self.photos[freshIdx].tag = tag
                    self.statusMessage = "已标记为「\(tag)」"
                    self.showDetailToast(tag)

                    let count = self.filteredPhotos.count
                    if count == 0 {
                        self.viewMode = .grid
                    } else if self.detailIndex >= count {
                        self.detailIndex = count - 1
                    }
                    self.isDetailTagging = false
                }
            } catch {
                DispatchQueue.main.async {
                    self?.statusMessage = "移动失败: \(error.localizedDescription)"
                    self?.isDetailTagging = false
                }
            }
        }
    }

    /// Move current detail photo to root in-place.
    func moveCurrentDetailToRoot() {
        guard !isDetailTagging else { return }
        guard let dir = currentDirectory else { return }
        guard let photo = currentDetailPhoto, photo.tag != nil else { return }
        guard let photoIdx = photos.firstIndex(where: { $0.id == photo.id }) else { return }

        isDetailTagging = true
        let fm = FileManager.default

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                var dest = dir.appendingPathComponent(photo.fileName)
                if fm.fileExists(atPath: dest.path) {
                    let stem = photo.url.deletingPathExtension().lastPathComponent
                    let ext = photo.url.pathExtension
                    dest = dir.appendingPathComponent("\(stem)_\(UUID().uuidString.prefix(6)).\(ext)")
                }
                try fm.moveItem(at: photo.url, to: dest)

                DispatchQueue.main.async {
                    guard let self = self else { return }
                    guard let freshIdx = self.photos.firstIndex(where: { $0.id == photo.id }) else {
                        self.isDetailTagging = false
                        return
                    }
                    self.photos[freshIdx].url = dest
                    self.photos[freshIdx].fileName = dest.lastPathComponent
                    self.photos[freshIdx].tag = nil
                    self.statusMessage = "已移回根目录"
                    self.showDetailToast("根目录")

                    let count = self.filteredPhotos.count
                    if count == 0 {
                        self.viewMode = .grid
                    } else if self.detailIndex >= count {
                        self.detailIndex = count - 1
                    }
                    self.isDetailTagging = false
                }
            } catch {
                DispatchQueue.main.async {
                    self?.statusMessage = "移动失败: \(error.localizedDescription)"
                    self?.isDetailTagging = false
                }
            }
        }
    }

    private func showDetailToast(_ label: String) {
        detailToast = label
        toastGeneration += 1
        let gen = toastGeneration
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            if self?.toastGeneration == gen {
                self?.detailToast = nil
            }
        }
    }
}
