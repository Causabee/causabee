import Foundation

/// A draft that names a file of its matter takes that file along: the mail program opens with it
/// attached. Found by the file's name, in the draft or in what the owner asked — nothing is
/// guessed, and a file not named stays where it is.
public enum DraftAttachments {
    /// The matter's files named in any of these texts, by their own name or the one the owner gave
    /// them, whatever the case. Hidden ones are left out; each file once, in the matter's order.
    public static func named(in texts: [String], among documents: [Document]) -> [Document] {
        let hay = texts.joined(separator: "\n").precomposedStringWithCanonicalMapping.lowercased()
        var seen = Set<String>()
        return documents.filter { document in
            guard !document.isHidden else { return false }
            let names = Set([document.name, document.shownName]).filter { $0.count >= 4 }
            guard names.contains(where: { hay.contains($0.precomposedStringWithCanonicalMapping.lowercased()) }) else { return false }
            return seen.insert(document.name.lowercased() + "/" + document.messageID).inserted
        }
    }
}
