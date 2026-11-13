import Foundation

public extension Bundle {
    /// MatterCore's own bundle, where the words all three devices share are kept, beside their
    /// German. Inside MatterCore a word is looked up with `bundle: .module`; from outside — the
    /// tests — `.module` is the asking target's own bundle and holds no catalogue, so this is how
    /// the shared words are reached (F009).
    static let words = Bundle.module
}
