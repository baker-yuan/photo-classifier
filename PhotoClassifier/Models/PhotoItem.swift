import AppKit

struct PhotoItem: Identifiable {
    let id = UUID()
    var url: URL
    var fileName: String
    let isVideo: Bool
    var tag: String?

    static let videoExtensions: Set<String> = [
        "mp4", "mov", "m4v", "avi", "mkv", "wmv", "flv", "webm", "3gp", "mts", "ts"
    ]

    init(url: URL) {
        self.url = url
        self.fileName = url.lastPathComponent
        self.isVideo = Self.videoExtensions.contains(url.pathExtension.lowercased())
    }
}
