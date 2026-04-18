import AppKit
import CoreGraphics
import AVFoundation

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
