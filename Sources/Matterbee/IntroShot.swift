import AppKit
import MatterCore
import SwiftData
import SwiftUI

/// `--demo --shot <name>`: the demo as one of the introduction's five pictures shows it, so the
/// pictures can be taken again whenever the design changes — `scripts/intro-shots.sh` starts one run
/// per picture and photographs the window. Without `--demo` there is no shot, so it never touches
/// the owner's own matters.
enum IntroShot: String {
    case overview
    case lisbon
    case lisbonTasks = "lisbon-tasks"
    case lisbonFiles = "lisbon-files"
    case care
    /// Not in the introduction: a task's popover open, for checking its design.
    case lisbonEdit = "lisbon-edit"

    nonisolated static let current: IntroShot? = {
        let arguments = CommandLine.arguments
        guard DemoData.isRequested, let at = arguments.firstIndex(of: "--shot"), at + 1 < arguments.count else { return nil }
        return IntroShot(rawValue: arguments[at + 1])
    }()

    /// The window the pictures are of, in points: at 2x 2880 × 1800, made 1800 × 1125.
    static let window = CGSize(width: 1440, height: 900)

    /// The start of the name of the matter that is open; none for the overview.
    var matter: String? {
        switch self {
        case .overview: nil
        case .lisbon, .lisbonTasks, .lisbonFiles, .lisbonEdit: "Lisbon"
        case .care: "Care for Mum"
        }
    }

    /// The to-do the page is scrolled to, as "überfällig" shows one: the kinds of tasks around it.
    var todo: String? { self == .lisbonTasks ? "Book the Sintra" : self == .lisbonEdit ? "Ask for express" : nil }

    /// The part of the page scrolled to the top (an `.id` on the matter page).
    var section: String? { self == .lisbonFiles ? "files" : nil }

    /// The window at the pictures' size, and the matter open as the picture shows it.
    @MainActor
    func arrange(_ navigation: Navigation, matters: [Matter]) {
        DispatchQueue.main.async {
            NSApp.windows.first { $0.isVisible && $0.canBecomeMain }?.setContentSize(Self.window)
        }
        guard let name = matter, let open = matters.first(where: { $0.name.hasPrefix(name) }) else { return }
        let shown = todo.flatMap { start in (open.todos ?? []).first { $0.text.hasPrefix(start) }?.persistentModelID }
        navigation.open(open, showing: shown)
    }
}

/// `--demo --render-editor <folder>`: a task's popover drawn off screen into two pictures, light
/// and dark — to check its design against Figma without photographing the screen.
@MainActor
enum DesignRender {
    static var folder: URL? {
        let arguments = CommandLine.arguments
        guard DemoData.isRequested, let at = arguments.firstIndex(of: "--render-editor"), at + 1 < arguments.count else { return nil }
        return URL(fileURLWithPath: arguments[at + 1], isDirectory: true)
    }

    static func editor(_ container: ModelContainer, to folder: URL) {
        let todos = (try? container.mainContext.fetch(FetchDescriptor<Todo>())) ?? []
        guard let todo = todos.first(where: { $0.text.hasPrefix("Ask for express") }) ?? todos.first else { exit(1) }
        for (name, appearance) in [("light", NSAppearance.Name.aqua), ("dark", .darkAqua)] {
            let view = TodoEditor(todo: todo, done: {}).modelContainer(container).background(Theme.canvas)
            let host = NSHostingView(rootView: view)
            host.appearance = NSAppearance(named: appearance)
            let size = host.fittingSize
            let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: .borderless, backing: .buffered, defer: false)
            window.contentView = host
            host.frame = NSRect(origin: .zero, size: size)
            host.layoutSubtreeIfNeeded()
            guard let picture = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { continue }
            host.cacheDisplay(in: host.bounds, to: picture)
            try? picture.representation(using: .png, properties: [:])?.write(to: folder.appendingPathComponent("editor-\(name).png"))
        }
        exit(0)
    }

    /// `--demo --render-overview <folder>`: the overview drawn off screen, light and dark, as it is
    /// and with "Care for Mum" pinned — to check it against Figma's "Overview with many matters".
    static var overviewFolder: URL? {
        let arguments = CommandLine.arguments
        guard DemoData.isRequested, let at = arguments.firstIndex(of: "--render-overview"), at + 1 < arguments.count else { return nil }
        return URL(fileURLWithPath: arguments[at + 1], isDirectory: true)
    }

    static func overview(_ container: ModelContainer, to folder: URL) {
        let matters = (try? container.mainContext.fetch(FetchDescriptor<Matter>())) ?? []
        let care = matters.first { $0.name.hasPrefix("Care for Mum") }
        let flat = matters.first { $0.name.hasPrefix("Buying the flat") }
        let fair = matters.first { $0.name.hasPrefix("Science fair") }
        // Wide, with the pinned matters beside the week, light and dark; and a narrower window.
        let shots: [(name: String, pinned: Int, size: CGSize, appearance: NSAppearance.Name)] = [
            ("wide-pinned-light", 1, CGSize(width: 1400, height: 1000), .aqua),
            ("wide-pinned-dark", 1, CGSize(width: 1400, height: 1000), .darkAqua),
            ("wide-two-pinned-light", 2, CGSize(width: 1400, height: 1100), .aqua),
            ("narrow-two-pinned-light", 2, CGSize(width: 900, height: 1500), .aqua),
            ("wide-three-pinned-light", 3, CGSize(width: 1400, height: 1400), .aqua),
            ("narrow-three-pinned-light", 3, CGSize(width: 900, height: 1900), .aqua),
            ("narrow-plain-light", 0, CGSize(width: 900, height: 1200), .aqua),
        ]
        for shot in shots {
            // In memory only: the demo store is not saved with the pins.
            care?.pinnedAt = shot.pinned >= 1 ? Date(timeIntervalSinceNow: -60) : nil
            flat?.pinnedAt = shot.pinned >= 2 ? Date(timeIntervalSinceNow: -30) : nil
            fair?.pinnedAt = shot.pinned >= 3 ? Date() : nil
            let view = OverviewView(matters: matters, search: .constant(""), start: { _ in })
                .environment(Navigation())
                .modelContainer(container)
                .frame(width: shot.size.width, height: shot.size.height)
                .background(Theme.canvas)
            let host = NSHostingView(rootView: view)
            host.appearance = NSAppearance(named: shot.appearance)
            host.frame = NSRect(origin: .zero, size: shot.size)
            let window = NSWindow(contentRect: host.frame, styleMask: .borderless, backing: .buffered, defer: false)
            window.contentView = host
            // The page measures its width, then lays out again for it.
            host.layoutSubtreeIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.5))
            host.layoutSubtreeIfNeeded()
            guard let picture = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { continue }
            host.cacheDisplay(in: host.bounds, to: picture)
            try? picture.representation(using: .png, properties: [:])?.write(to: folder.appendingPathComponent("overview-\(shot.name).png"))
        }
        care?.pinnedAt = nil
        flat?.pinnedAt = nil
        fair?.pinnedAt = nil
        exit(0)
    }
}
