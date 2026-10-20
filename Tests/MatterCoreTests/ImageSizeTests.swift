import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import MatterCore

struct ImageSizeTests {
    /// A noisy picture, as a camera's is, written as PNG: big, like the 55 MB photo.
    private func picture(width: Int, height: Int) -> Data {
        let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        let pixels = context.data!.assumingMemoryBound(to: UInt32.self)
        var seed: UInt32 = 7
        for i in 0..<(context.bytesPerRow / 4 * height) { seed = seed &* 1664525 &+ 1013904223; pixels[i] = seed }
        let out = NSMutableData()
        let destination = CGImageDestinationCreateWithData(out, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, context.makeImage()!, nil)
        CGImageDestinationFinalize(destination)
        return out as Data
    }

    @Test func aBigPhotoIsKeptAsAJPEGAtMost3000Wide() throws {
        let big = picture(width: 4032, height: 3024)
        #expect(big.count > ImageSize.limit)
        let kept = ImageSize.kept(big, name: "Screenshot 2026-10-20 at 09.41.00.png")
        #expect(kept.name == "Screenshot 2026-10-20 at 09.41.00.jpg")
        #expect(kept.data.count < big.count)
        let source = try #require(CGImageSourceCreateWithData(kept.data as CFData, nil))
        let properties = try #require(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
        #expect(properties[kCGImagePropertyPixelWidth] as? Int == 3000)
    }

    @Test func aSmallScreenshotStaysAsItIs() {
        let small = picture(width: 600, height: 400)
        let kept = ImageSize.kept(small, name: "Screenshot.png")
        #expect(kept.name == "Screenshot.png")
        #expect(kept.data == small)
    }

    @Test func aPDFIsNeverTouched() {
        let data = Data("%PDF-1.4\n".utf8) + Data(count: 6_000_000)
        #expect(ImageSize.kept(data, name: "Letter.pdf").data == data)
    }

    @Test func aBigPictureIsAttachedAsASmallerCopyAndTheKeptOneStays() throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("big-\(UUID().uuidString).png")
        try picture(width: 4032, height: 3024).write(to: file)
        let attached = ImageSize.attachable(file)
        #expect(attached != file)
        #expect(attached.pathExtension == "jpg")
        #expect(FileManager.default.fileExists(atPath: file.path))
    }
}
