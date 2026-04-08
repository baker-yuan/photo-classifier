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

// MARK: - EXIF Metadata

struct ExifInfo {
    var cameraMake: String?
    var cameraModel: String?
    var lensModel: String?
    var focalLength: Double?
    var aperture: Double?
    var shutterSpeed: Double?
    var iso: Int?
    var dateTaken: String?
    var pixelWidth: Int?
    var pixelHeight: Int?

    var cameraDisplay: String? {
        [cameraMake, cameraModel]
            .compactMap { $0 }
            .joined(separator: " ")
            .nilIfEmpty
    }

    var shutterDisplay: String? {
        guard let s = shutterSpeed else { return nil }
        if s >= 1 { return "\(Int(s))s" }
        let denom = Int(round(1.0 / s))
        return "1/\(denom)s"
    }

    var apertureDisplay: String? {
        guard let a = aperture else { return nil }
        return String(format: "f/%.1g", a)
    }

    var focalLengthDisplay: String? {
        guard let f = focalLength else { return nil }
        return "\(Int(f))mm"
    }

    var isoDisplay: String? {
        guard let i = iso else { return nil }
        return "ISO \(i)"
    }

    var resolutionDisplay: String? {
        guard let w = pixelWidth, let h = pixelHeight else { return nil }
        return "\(w)×\(h)"
    }

    static func read(from url: URL) -> ExifInfo? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        else { return nil }

        let exif = props[kCGImagePropertyExifDictionary] as? [CFString: Any]
        let tiff = props[kCGImagePropertyTIFFDictionary] as? [CFString: Any]

        var info = ExifInfo()
        info.cameraMake = (tiff?[kCGImagePropertyTIFFMake] as? String)?
            .trimmingCharacters(in: .whitespaces)
        info.cameraModel = tiff?[kCGImagePropertyTIFFModel] as? String
        info.lensModel = exif?[kCGImagePropertyExifLensModel] as? String
        info.focalLength = exif?[kCGImagePropertyExifFocalLength] as? Double
        info.aperture = exif?[kCGImagePropertyExifFNumber] as? Double
        info.shutterSpeed = exif?[kCGImagePropertyExifExposureTime] as? Double
        info.iso = (exif?[kCGImagePropertyExifISOSpeedRatings] as? [Int])?.first
        info.dateTaken = exif?[kCGImagePropertyExifDateTimeOriginal] as? String
        info.pixelWidth = props[kCGImagePropertyPixelWidth] as? Int
        info.pixelHeight = props[kCGImagePropertyPixelHeight] as? Int
        return info
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

import SwiftUI
