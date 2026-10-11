import Foundation

/// A draft that names a file of its matter takes that file along: the mail program opens with it
/// attached. Found by the file's name, in the draft or in what the owner asked — nothing is
/// guessed, and a file not named stays where it is.
public enum DraftAttachments {
    /// The matter's files named in any of these texts, by their own name or the one the owner gave
    /// them — as a person names a file: "the Sunrise Contract draft pdf" is "Sunrise-contract-draft.pdf".
    /// Case, hyphens, underscores and the dot before the ending do not count; the ending itself
    /// need not be said. Hidden ones are left out; each file once, in the matter's order.
    public static func named(in texts: [String], among documents: [Document]) -> [Document] {
        let hay = " " + plain(texts.joined(separator: "\n")) + " "
        var seen = Set<String>()
        var found: [(document: Document, said: String)] = []
        for document in documents where !document.isHidden {
            let names = Set([document.name, document.shownName].flatMap { [plain($0), plain(($0 as NSString).deletingPathExtension)] })
                // Whole words, and enough of them to be a name: "a.b", "scan" or "1.pdf" name nothing.
                .filter { $0.count >= 6 && hay.contains(" " + $0 + " ") }
            guard let said = names.max(by: { $0.count < $1.count }) else { continue }
            if seen.insert(document.name.lowercased() + "/" + document.messageID).inserted { found.append((document, said)) }
        }
        // "Sunrise contract draft pdf" names that file, not "Draft.pdf" beside it: a name that is
        // only the end of a longer one that was said is not the one meant.
        return found.filter { one in !found.contains { $0.said.count > one.said.count && (" " + $0.said + " ").contains(" " + one.said + " ") } }
            .map(\.document)
    }

    /// Letters and digits in lower case, everything else one space.
    static func plain(_ text: String) -> String {
        let folded = text.precomposedStringWithCanonicalMapping.lowercased()
        return folded.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).joined(separator: " ")
    }
}
