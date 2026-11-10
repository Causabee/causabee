// Where words are in a picture, in its own pixels: for placing the film's ticks, rings and cards on
// today's screenshots by measure, not by eye. Apple's Vision reads the picture on this Mac.
//
//   swift scripts/film/find.swift <picture> [words …]     every line, or only those that contain the words
//
// Prints x y w h (top-left origin, pixels) and the text, one line each.
import AppKit
import Vision

let args = Array(CommandLine.arguments.dropFirst())
guard let path = args.first, let image = NSImage(contentsOfFile: path),
      let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { print("usage: find.swift <picture> [words …]"); exit(2) }
let wanted = args.dropFirst().map { $0.lowercased() }
let request = VNRecognizeTextRequest()
request.recognitionLevel = .accurate
request.usesLanguageCorrection = false
try VNImageRequestHandler(cgImage: cg).perform([request])
let W = Double(cg.width), H = Double(cg.height)
for result in request.results ?? [] {
    guard let text = result.topCandidates(1).first?.string else { continue }
    if !wanted.isEmpty, !wanted.contains(where: { text.lowercased().contains($0) }) { continue }
    let b = result.boundingBox
    print(String(format: "%5.0f %5.0f %5.0f %4.0f  %@", b.minX * W, (1 - b.maxY) * H, b.width * W, b.height * H, text))
}
