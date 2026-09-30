import CoreGraphics
import Foundation
import ImageIO
import Vision

/// The text of an image, read on the device. Nothing about the image leaves it: this is Apple's
/// Vision, and the result is lines with where each one sits.
public enum ScreenText {
    /// One line as Vision saw it. `box` is in the image's own proportions, 0 to 1, origin at the
    /// top left — the way a screenshot is looked at, not Vision's bottom left.
    public struct Line: Sendable, Equatable {
        public var text: String
        public var box: CGRect
        public var confidence: Float

        public init(text: String, box: CGRect, confidence: Float = 1) {
            self.text = text
            self.box = box
            self.confidence = confidence
        }

        public var midX: CGFloat { box.midX }
        public var top: CGFloat { box.minY }
        public var bottom: CGFloat { box.maxY }
    }

    public enum Failure: Error, CustomStringConvertible {
        case unreadable(URL)
        public var description: String {
            switch self { case .unreadable(let url): "\(url.lastPathComponent) is not an image this Mac can read" }
        }
    }

    public static func lines(in url: URL) throws -> (lines: [Line], size: CGSize) {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { throw Failure.unreadable(url) }
        return (try lines(in: image), CGSize(width: image.width, height: image.height))
    }

    public static func lines(in image: CGImage) throws -> [Line] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["de-DE", "en-US"]
        request.usesLanguageCorrection = true
        try VNImageRequestHandler(cgImage: image).perform([request])
        return (request.results ?? []).compactMap { observation in
            guard let best = observation.topCandidates(1).first else { return nil }
            let box = observation.boundingBox
            return Line(text: best.string, box: CGRect(x: box.minX, y: 1 - box.maxY, width: box.width, height: box.height),
                        confidence: best.confidence)
        }
        .sorted { ($0.top, $0.box.minX) < ($1.top, $1.box.minX) }
    }
}
