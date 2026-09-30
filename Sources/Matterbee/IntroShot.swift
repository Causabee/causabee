import AppKit
import MatterCore
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
        case .lisbon, .lisbonTasks, .lisbonFiles: "Lisbon"
        case .care: "Care for Mum"
        }
    }

    /// The to-do the page is scrolled to, as "überfällig" shows one: the kinds of tasks around it.
    var todo: String? { self == .lisbonTasks ? "Book the Sintra" : nil }

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
