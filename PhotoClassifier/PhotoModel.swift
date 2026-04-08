import AppKit
import CoreGraphics
import AVFoundation

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

final class ThumbnailCache {
    static let shared = ThumbnailCache()
    private let cache = NSCache<NSURL, NSImage>()

    private init() { cache.countLimit = 500 }

    func thumbnail(for item: PhotoItem, maxSize: CGFloat) -> NSImage? {
        let key = item.url as NSURL
        if let cached = cache.object(forKey: key) { return cached }

        let img: NSImage?
        if item.isVideo {
            img = videoThumbnail(url: item.url, maxSize: maxSize)
        } else {
            img = imageThumbnail(url: item.url, maxSize: maxSize)
        }

        if let img = img {
            cache.setObject(img, forKey: key)
        }
        return img
    }

    private func imageThumbnail(url: URL, maxSize: CGFloat) -> NSImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceThumbnailMaxPixelSize: maxSize * 2,
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
    }

    private func videoThumbnail(url: URL, maxSize: CGFloat) -> NSImage? {
        let asset = AVAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: maxSize * 2, height: maxSize * 2)

        do {
            let cgImage = try generator.copyCGImage(at: CMTime(seconds: 1, preferredTimescale: 600), actualTime: nil)
            return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        } catch {
            // Try at time 0
            do {
                let cgImage = try generator.copyCGImage(at: .zero, actualTime: nil)
                return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
            } catch {
                return nil
            }
        }
    }

    func clear() { cache.removeAllObjects() }
}

// MARK: - Deterministic Tag Color

private let tagColorPalette: [Color] = [.blue, .purple, .orange, .teal, .indigo, .pink, .mint, .cyan]

func deterministicTagColor(_ tag: String) -> Color {
    switch tag {
    case "保留": return .green
    case "删除": return .red
    default:
        var hash: UInt64 = 5381
        for byte in tag.utf8 {
            hash = hash &* 33 &+ UInt64(byte)
        }
        return tagColorPalette[Int(hash % UInt64(tagColorPalette.count))]
    }
}

// MARK: - Directory Tree Node

struct DirectoryNode: Identifiable, Hashable {
    var id: String { url.path }
    let url: URL
    let name: String
    let children: [DirectoryNode]

    func hash(into hasher: inout Hasher) { hasher.combine(url) }
    static func == (lhs: DirectoryNode, rhs: DirectoryNode) -> Bool { lhs.url == rhs.url }
}

import SwiftUI
