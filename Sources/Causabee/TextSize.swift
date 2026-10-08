import SwiftUI

#if os(macOS)
/// The Mac's text, larger than the system sets it: Causabee is read in, and the Mac's own sizes —
/// 13 for the body, 10 for a caption — are those of a list of files. One number for all of it,
/// a fifth larger; `-text.scale 1` on the command line tries another.
enum TextSize {
    static let scale: CGFloat = {
        let asked = UserDefaults.standard.double(forKey: "text.scale")
        return asked >= 0.8 && asked <= 1.6 ? asked : 1.2
    }()

    static func font(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: (size * scale).rounded(), weight: weight)
    }
}

/// The system's text styles by their names, at Causabee's size: every `.font(.caption)` in the Mac
/// app means these. The sizes are the Mac's own, times the scale.
extension Font {
    static var largeTitle: Font { TextSize.font(26) }
    static var title: Font { TextSize.font(22) }
    static var title2: Font { TextSize.font(17) }
    static var title3: Font { TextSize.font(15) }
    static var headline: Font { TextSize.font(13, .bold) }
    static var body: Font { TextSize.font(13) }
    static var callout: Font { TextSize.font(12) }
    static var subheadline: Font { TextSize.font(11) }
    static var footnote: Font { TextSize.font(10) }
    static var caption: Font { TextSize.font(10) }
    static var caption2: Font { TextSize.font(10) }
}
#endif
