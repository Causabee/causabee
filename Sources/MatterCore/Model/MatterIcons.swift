import Foundation

/// The icon a matter is known by — a house, a car, a plane — so it is found in a list before it is
/// read. Causabee suggests one from the matter's name; the owner can choose another.
public enum MatterIcons {
    public struct Icon: Identifiable, Sendable {
        /// The system symbol's name; it is what is stored.
        public let symbol: String
        public let label: String
        /// Words in a matter's name that suggest it, in lowercase: German and English.
        let words: [String]
        public var id: String { symbol }
    }

    /// For a matter whose name suggests nothing, until the owner chooses.
    public static let fallback = "folder"

    /// What can be chosen, in the order the picker shows it. A suggestion takes the first that fits,
    /// so the more telling ones come first: "Umzug" before "Wohnung", "Steuer" before "Bank".
    public static let all: [Icon] = [
        Icon(symbol: "truck.box", label: String(localized: "Move", bundle: .module), words: ["umzug", "moving", "move", "spedition"]),
        Icon(symbol: "bathtub", label: String(localized: "Bathroom", bundle: .module), words: ["bad", "bathroom", "badsanierung"]),
        Icon(symbol: "wrench.and.screwdriver", label: String(localized: "Repair", bundle: .module), words: ["renovierung", "renovation", "sanierung", "reparatur", "repair", "handwerker", "dach", "roof", "heizung"]),
        Icon(symbol: "car", label: String(localized: "Car", bundle: .module), words: ["auto", "car", "kfz", "unfall", "accident", "parking", "fahrzeug", "werkstatt", "garage", "parkplatz"]),
        Icon(symbol: "airplane", label: String(localized: "Trip", bundle: .module), words: ["reise", "reisen", "trip", "flug", "flight", "urlaub", "holiday", "vacation", "ferien"]),
        Icon(symbol: "suitcase.rolling", label: String(localized: "Travel", bundle: .module), words: []),
        Icon(symbol: "cross.case", label: String(localized: "Health", bundle: .module), words: ["reha", "krankenhaus", "hospital", "klinik", "arzt", "doctor", "gesundheit", "health", "operation", "zahnarzt", "krankenkasse"]),
        Icon(symbol: "heart", label: String(localized: "Care", bundle: .module), words: ["pflege", "care", "mama", "mum", "mom", "mutter", "papa", "dad", "vater", "oma", "opa"]),
        Icon(symbol: "stethoscope", label: String(localized: "Doctor", bundle: .module), words: []),
        Icon(symbol: "pawprint", label: String(localized: "Pet", bundle: .module), words: ["hund", "dog", "katze", "cat", "tierarzt", "vet"]),
        Icon(symbol: "graduationcap", label: String(localized: "School", bundle: .module), words: ["schule", "school", "uni", "studium", "kita", "klasse", "science", "abitur", "ausbildung"]),
        Icon(symbol: "books.vertical", label: String(localized: "Study", bundle: .module), words: []),
        Icon(symbol: "wineglass", label: String(localized: "Celebration", bundle: .module), words: ["hochzeit", "wedding", "geburtstag", "birthday", "feier", "party", "jubiläum"]),
        Icon(symbol: "checkmark.shield", label: String(localized: "Insurance", bundle: .module), words: ["versicherung", "insurance", "haftpflicht"]),
        Icon(symbol: "hammer", label: String(localized: "Legal", bundle: .module), words: ["anwalt", "lawyer", "gericht", "court", "klage", "rechtsstreit", "widerspruch"]),
        Icon(symbol: "receipt", label: String(localized: "Tax and bills", bundle: .module), words: ["steuer", "steuererklärung", "tax", "rechnung", "invoice", "mahnung", "abo", "abonnement", "kündigen", "kündigung"]),
        Icon(symbol: "eurosign", label: String(localized: "Money", bundle: .module), words: ["kredit", "loan", "finanzierung", "geld", "rente", "pension", "erbe", "erstatten"]),
        Icon(symbol: "building.columns", label: String(localized: "Bank and office", bundle: .module), words: ["bank", "amt", "behörde", "finanzamt"]),
        Icon(symbol: "briefcase", label: String(localized: "Work", bundle: .module), words: ["job", "bewerbung", "application", "arbeit", "work", "arbeitsvertrag", "kunde", "projekt"]),
        Icon(symbol: "house", label: String(localized: "Home", bundle: .module), words: ["wohnung", "haus", "flat", "house", "apartment", "miete", "mieter", "rent", "immobilie", "eigentümer", "hausverwaltung", "weg", "mühle"]),
        Icon(symbol: "key", label: String(localized: "Keys", bundle: .module), words: ["schlüssel", "key", "übergabe"]),
        Icon(symbol: "tree", label: String(localized: "Garden", bundle: .module), words: ["garten", "garden", "baum", "sperrmüll"]),
        Icon(symbol: "person.2", label: String(localized: "People", bundle: .module), words: ["verein", "club", "familie", "family", "eltern"]),
        Icon(symbol: "envelope", label: String(localized: "Mail", bundle: .module), words: []),
        Icon(symbol: "doc.text", label: String(localized: "Papers", bundle: .module), words: ["vertrag", "contract", "antrag", "unterlagen"]),
        Icon(symbol: "folder", label: String(localized: "Folder", bundle: .module), words: []),
    ]

    /// The icon a matter's name suggests, or nil: a whole word of the name, or the start of one for
    /// words of five letters and more — "Steuererklärung" for "steuer", but not "Baden" for "bad".
    public static func suggested(for name: String) -> String? {
        let tokens = name.lowercased().split { !$0.isLetter }.map(String.init)
        guard !tokens.isEmpty else { return nil }
        for icon in all {
            for word in icon.words where tokens.contains(where: { $0 == word || (word.count >= 5 && $0.hasPrefix(word)) }) {
                return icon.symbol
            }
        }
        return nil
    }
}

extension Matter {
    /// The icon to show: the owner's, or the one the name suggests, or a folder.
    public var shownIcon: String { icon ?? MatterIcons.suggested(for: name) ?? MatterIcons.fallback }
}
