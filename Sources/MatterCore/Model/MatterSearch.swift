import Foundation

/// Finding a matter by what the owner types, on the device: its name and other names first,
/// then the words of its to-dos and its mail. Nothing is sent.
@MainActor
public enum MatterSearch {
    static func fold(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "de_DE"))
            .replacingOccurrences(of: "ß", with: "ss")
    }

    public struct Hit {
        public let matter: Matter
        /// Why it came up, when not by its name: "Aufgabe: Lieferung Dachrinne nachfassen".
        public let because: String?

        public init(matter: Matter, because: String? = nil) {
            self.matter = matter
            self.because = because
        }
    }

    public static func find(_ query: String, in matters: [Matter], limit: Int = 6) -> [Hit] {
        let words = fold(query).split { $0.isWhitespace }.map(String.init).filter { $0.count >= 2 }
        guard !words.isEmpty else { return [] }
        func all(_ text: String) -> Bool { let folded = fold(text); return words.allSatisfy { folded.contains($0) } }
        var hits: [(rank: Int, hit: Hit)] = []
        for matter in matters {
            if all(([matter.name, matter.key] + matter.aliases).joined(separator: " ")) {
                hits.append((matter.isClosed ? 1 : 0, Hit(matter: matter, because: nil)))
            } else if let todo = (matter.todos ?? []).first(where: { all($0.text) }) {
                hits.append((matter.isClosed ? 3 : 2, Hit(matter: matter, because: "Task: " + todo.text)))
            } else if let entry = (matter.entries ?? []).first(where: { all($0.title + " " + ($0.digest ?? "")) }) {
                hits.append((matter.isClosed ? 5 : 4, Hit(matter: matter, because: "Mail: " + entry.title)))
            }
        }
        return hits.sorted { ($0.rank, $0.hit.matter.name) < ($1.rank, $1.hit.matter.name) }.prefix(limit).map(\.hit)
    }
}
