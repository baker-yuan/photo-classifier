import AppKit

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

extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
