// Renders an HTML film to PNG frames: loads the page off screen at 1080 × 1920, and for every
// frame calls the page's `seek(seconds)` — which sets every animation to that time — and takes a
// snapshot. Then ffmpeg joins the frames with the voice (see scripts/film/render.sh).
//
//   swift scripts/film/render.swift <page.html> <frames-folder> <seconds> [fps]
import AppKit
import WebKit

let args = CommandLine.arguments
guard args.count >= 4 else { print("usage: render.swift <page.html> <folder> <seconds> [fps]"); exit(2) }
let page = URL(fileURLWithPath: args[1]), folder = URL(fileURLWithPath: args[2], isDirectory: true)
let seconds = Double(args[3])!, fps = args.count > 4 ? Double(args[4])! : 30
try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

let app = NSApplication.shared
let config = WKWebViewConfiguration()
config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
let web = WKWebView(frame: NSRect(x: 0, y: 0, width: 1080, height: 1920), configuration: config)
let window = NSWindow(contentRect: web.frame, styleMask: .borderless, backing: .buffered, defer: false)
window.contentView = web

final class Loader: NSObject, WKNavigationDelegate {
    var done: (() -> Void)?
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { done?() }
}
let loader = Loader()
web.navigationDelegate = loader

func snapshot(_ index: Int, total: Int) {
    guard index < total else { print("rendered \(total) frames"); exit(0) }
    let t = Double(index) / fps
    web.evaluateJavaScript("seek(\(t))") { _, error in
        if let error { print("seek failed at \(t): \(error)"); exit(1) }
        // One tick for layout after the seek, then the picture.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.012) {
            let shot = WKSnapshotConfiguration()
            shot.rect = web.bounds
            shot.snapshotWidth = 1080
            web.takeSnapshot(with: shot) { image, error in
                guard let image, let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
                      let png = rep.representation(using: .png, properties: [:]) else { print("snapshot failed at \(t): \(String(describing: error))"); exit(1) }
                try? png.write(to: folder.appendingPathComponent(String(format: "f%05d.png", index)))
                if index % 150 == 0 { print("frame \(index) / \(total)") }
                snapshot(index + 1, total: total)
            }
        }
    }
}
loader.done = {
    // Fonts and images: give the page a moment before the first frame. FILM_PROBE=<js> prints that expression and stops.
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
        if let probe = ProcessInfo.processInfo.environment["FILM_PROBE"] {
            web.evaluateJavaScript(probe) { value, error in print("probe:", value ?? "nil", error.map { "\($0)" } ?? ""); exit(0) }
            return
        }
        snapshot(0, total: Int((seconds * fps).rounded()))
    }
}
web.loadFileURL(page, allowingReadAccessTo: page.deletingLastPathComponent().deletingLastPathComponent())
app.run()
