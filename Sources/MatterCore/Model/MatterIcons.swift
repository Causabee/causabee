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
        Icon(symbol: "truck.box", label: "Move", words: ["umzug", "moving", "move", "spedition"]),
        Icon(symbol: "bathtub", label: "Bathroom", words: ["bad", "bathroom", "badsanierung"]),
        Icon(symbol: "wrench.and.screwdriver", label: "Repair", words: ["renovierung", "renovation", "sanierung", "reparatur", "repair", "handwerker", "dach", "roof", "heizung"]),
        Icon(symbol: "car", label: "Car", words: ["auto", "car", "kfz", "unfall", "accident", "parking", "fahrzeug", "werkstatt", "garage", "parkplatz"]),
        Icon(symbol: "airplane", label: "Trip", words: ["reise", "reisen", "trip", "flug", "flight", "urlaub", "holiday", "vacation", "ferien"]),
        Icon(symbol: "suitcase.rolling", label: "Travel", words: []),
        Icon(symbol: "cross.case", label: "Health", words: ["reha", "krankenhaus", "hospital", "klinik", "arzt", "doctor", "gesundheit", "health", "operation", "zahnarzt", "krankenkasse"]),
        Icon(symbol: "heart", label: "Care", words: ["pflege", "care", "mama", "mum", "mom", "mutter", "papa", "dad", "vater", "oma", "opa"]),
        Icon(symbol: "stethoscope", label: "Doctor", words: []),
        Icon(symbol: "pawprint", label: "Pet", words: ["hund", "dog", "katze", "cat", "tierarzt", "vet"]),
        Icon(symbol: "graduationcap", label: "School", words: ["schule", "school", "uni", "studium", "kita", "klasse", "science", "abitur", "ausbildung"]),
        Icon(symbol: "books.vertical", label: "Study", words: []),
        Icon(symbol: "wineglass", label: "Celebration", words: ["hochzeit", "wedding", "geburtstag", "birthday", "feier", "party", "jubiläum"]),
        Icon(symbol: "checkmark.shield", label: "Insurance", words: ["versicherung", "insurance", "haftpflicht"]),
        Icon(symbol: "hammer", label: "Legal", words: ["anwalt", "lawyer", "gericht", "court", "klage", "rechtsstreit", "widerspruch"]),
        Icon(symbol: "receipt", label: "Tax and bills", words: ["steuer", "steuererklärung", "tax", "rechnung", "invoice", "mahnung", "abo", "abonnement", "kündigen", "kündigung"]),
        Icon(symbol: "eurosign", label: "Money", words: ["kredit", "loan", "finanzierung", "geld", "rente", "pension", "erbe", "erstatten"]),
        Icon(symbol: "building.columns", label: "Bank and office", words: ["bank", "amt", "behörde", "finanzamt"]),
        Icon(symbol: "briefcase", label: "Work", words: ["job", "bewerbung", "application", "arbeit", "work", "arbeitsvertrag", "kunde", "projekt"]),
        Icon(symbol: "house", label: "Home", words: ["wohnung", "haus", "flat", "house", "apartment", "miete", "mieter", "rent", "immobilie", "eigentümer", "hausverwaltung", "weg", "mühle"]),
        Icon(symbol: "key", label: "Keys", words: ["schlüssel", "key", "übergabe"]),
        Icon(symbol: "tree", label: "Garden", words: ["garten", "garden", "baum", "sperrmüll"]),
        Icon(symbol: "person.2", label: "People", words: ["verein", "club", "familie", "family", "eltern"]),
        Icon(symbol: "envelope", label: "Mail", words: []),
        Icon(symbol: "doc.text", label: "Papers", words: ["vertrag", "contract", "antrag", "unterlagen"]),
        Icon(symbol: "folder", label: "Folder", words: []),
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
