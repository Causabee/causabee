// Renders an HTML film to PNG frames with Safari's engine: loads the page off screen, and for every
// frame calls the page's `seek(time)` — which sets every animation to that time — and takes a
// snapshot. Then ffmpeg joins the frames with the sound (scripts/film/render.sh, walkthrough.sh).
//
//   swift scripts/film/render.swift <page.html> <frames-folder> <seconds> [fps] [options]
//   swift scripts/film/render.swift <page.html> <stills-folder> --at 1.5 40 92.5 [options]   one picture each, t<time>.png
//
// Options:
//   --size 1920x1080   the page's size and the picture's (1080x1920, portrait, if left out)
//   --ms               the page's seek takes milliseconds (the walkthrough's does), not seconds
//   --root <folder>    what the page may read besides its own folder's parent (site/ for the walkthrough)
//   --query render     added to the page's address (?render): the walkthrough pauses its own clock then
import AppKit
import WebKit

var rest = Array(CommandLine.arguments.dropFirst())
func option(_ name: String) -> String? {
    guard let at = rest.firstIndex(of: name), at + 1 < rest.count else { return nil }
    defer { rest.removeSubrange(at...(at + 1)) }
    return rest[at + 1]
}
func flag(_ name: String) -> Bool {
    guard let at = rest.firstIndex(of: name) else { return false }
    rest.remove(at: at)
    return true
}
let size = option("--size").map { $0.split(separator: "x").compactMap { Double($0) } } ?? [1080, 1920]
let milliseconds = flag("--ms")
let rootFolder = option("--root").map { URL(fileURLWithPath: $0, isDirectory: true) }
let query = option("--query")
var stills: [Double]? = nil
if let at = rest.firstIndex(of: "--at") {
    stills = rest[(at + 1)...].compactMap(Double.init)
    rest.removeSubrange(at...)
}
guard rest.count >= 2, size.count == 2, stills != nil || rest.count >= 3 else {
    print("usage: render.swift <page.html> <folder> <seconds> [fps] [--size WxH] [--ms] [--root folder] [--query q] | --at t …"); exit(2)
}
let page = URL(fileURLWithPath: rest[0]), folder = URL(fileURLWithPath: rest[1], isDirectory: true)
let seconds = stills == nil ? Double(rest[2])! : 0, fps = rest.count > 3 ? Double(rest[3])! : 30
try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

let app = NSApplication.shared
let config = WKWebViewConfiguration()
config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
let web = WKWebView(frame: NSRect(x: 0, y: 0, width: size[0], height: size[1]), configuration: config)
let window = NSWindow(contentRect: web.frame, styleMask: .borderless, backing: .buffered, defer: false)
window.contentView = web

final class Loader: NSObject, WKNavigationDelegate {
    var done: (() -> Void)?
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { done?() }
}
let loader = Loader()
web.navigationDelegate = loader

/// The picture at time `t`, written as `name`; then `next`.
func picture(at t: Double, name: String, then next: @escaping () -> Void) {
    let time = milliseconds ? t * 1000 : t
    web.evaluateJavaScript("seek(\(time))") { _, error in
        if let error { print("seek failed at \(t): \(error)"); exit(1) }
        // One tick for layout after the seek, then the picture.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.012) {
            let shot = WKSnapshotConfiguration()
            shot.rect = web.bounds
            shot.snapshotWidth = NSNumber(value: size[0])
            web.takeSnapshot(with: shot) { image, error in
                // At exactly the size asked for: on a Retina screen the snapshot has twice the pixels.
                guard let image, let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size[0]), pixelsHigh: Int(size[1]),
                                                             bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                                             colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { print("snapshot failed at \(t): \(String(describing: error))"); exit(1) }
                rep.size = NSSize(width: size[0], height: size[1])
                NSGraphicsContext.saveGraphicsState()
                NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
                NSGraphicsContext.current?.imageInterpolation = .high
                image.draw(in: NSRect(x: 0, y: 0, width: size[0], height: size[1]))
                NSGraphicsContext.restoreGraphicsState()
                guard let png = rep.representation(using: .png, properties: [:]) else { print("snapshot failed at \(t)"); exit(1) }
                do { try png.write(to: folder.appendingPathComponent(name)) } catch { print("cannot write \(name): \(error)"); exit(1) }
                next()
            }
        }
    }
}

func frame(_ index: Int, total: Int) {
    guard index < total else { print("rendered \(total) frames"); exit(0) }
    picture(at: Double(index) / fps, name: String(format: "f%05d.png", index)) {
        if index % 300 == 0 { print("frame \(index) / \(total)") }
        frame(index + 1, total: total)
    }
}

func still(_ index: Int, _ times: [Double]) {
    guard index < times.count else { print("rendered \(times.count) stills"); exit(0) }
    picture(at: times[index], name: "t\(times[index]).png") { still(index + 1, times) }
}

loader.done = {
    // Fonts and images: give the page a moment before the first frame. FILM_PROBE=<js> prints that expression and stops.
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
        if let probe = ProcessInfo.processInfo.environment["FILM_PROBE"] {
            web.evaluateJavaScript(probe) { value, error in print("probe:", value ?? "nil", error.map { "\($0)" } ?? ""); exit(0) }
            return
        }
        if let stills { still(0, stills) } else { frame(0, total: Int((seconds * fps).rounded())) }
    }
}
let address = query.flatMap { URL(string: page.absoluteString + "?" + $0) } ?? page
web.loadFileURL(address, allowingReadAccessTo: rootFolder ?? page.deletingLastPathComponent().deletingLastPathComponent())
app.run()
