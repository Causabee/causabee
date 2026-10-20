import Foundation
import ImageIO
import UniformTypeIdentifiers

/// A picture at a size to read and to send: a photo is kept as JPEG at most 3,000 points on its
/// long side — every letter still sharp, a few megabytes at most; a screenshot, small already,
/// stays as it is. A camera's full photo or a ProRAW one, kept whole and named PNG, was 50 MB and
/// more, and went along with a mail just as big.
public enum ImageSize {
    public static let longSide = 3000
    /// Above this, a picture is made smaller — kept, or attached to a mail.
    public static let limit = 5_000_000

    /// The picture to keep, and its name: unchanged when it is no image, or small enough already.
    public static func kept(_ data: Data, name: String) -> (data: Data, name: String) {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let type = CGImageSourceGetType(source).map({ UTType($0 as String) }) ?? nil,
              type.conforms(to: .image), !type.conforms(to: .pdf),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int else { return (data, name) }
        guard data.count > limit || max(width, height) > longSide else { return (data, name) }
        let options: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true,
                                        kCGImageSourceCreateThumbnailWithTransform: true,
                                        kCGImageSourceThumbnailMaxPixelSize: min(longSide, max(width, height))]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return (data, name) }
        let out = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(out, UTType.jpeg.identifier as CFString, 1, nil) else { return (data, name) }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.82] as CFDictionary)
        guard CGImageDestinationFinalize(destination), out.length < data.count else { return (data, name) }
        return (out as Data, (name as NSString).deletingPathExtension + ".jpg")
    }

    /// A file to attach to a mail: the file itself, or — a picture over the limit — a smaller copy
    /// of it in the temporary folder. The file kept in the matter stays as it is.
    public static func attachable(_ file: URL) -> URL {
        guard let size = try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize, size > limit,
              let data = try? Data(contentsOf: file) else { return file }
        let smaller = kept(data, name: file.lastPathComponent)
        guard smaller.data.count < data.count else { return file }
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("causabee-attach-" + UUID().uuidString.prefix(8), isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let copy = folder.appendingPathComponent(smaller.name)
        return (try? smaller.data.write(to: copy)) != nil ? copy : file
    }
}
