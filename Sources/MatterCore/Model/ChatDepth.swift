import Foundation

/// F005: how much of a matter a question is asked with. **Light** is what a quick question needs —
/// the brief, what is open, the dates to come, the people, what came in lately (`Facts.light`);
/// **deep** the whole matter, as the chat had it before. Picked on the device, without the AI and
/// without the clock, so the same question about the same matter goes the same way on every device.
public enum ChatDepth: String, Sendable, Codable, Comparable {
    case light
    case deep

    public static func < (a: ChatDepth, b: ChatDepth) -> Bool { a == .light && b == .deep }

    /// The depth for `question`, `after` the depth of the question before it about the same
    /// matter in this conversation: a follow-up never goes lighter, so the cache reads what went before.
    public static func pick(question: String, facts: Facts, after: ChatDepth?) -> ChatDepth {
        guard let light = facts.light else { return .deep }
        if after == .deep { return .deep }
        let lower = question.lowercased()
        if searches(lower) { return .deep }
        // A word only the whole matter has — an item from weeks ago, a done task, a past date, a file.
        let lightLower = light.lowercased(), whole = facts.text.lowercased()
        let named = words(of: lower).filter { !common.contains($0) }
        if named.contains(where: { whole.contains($0) && !lightLower.contains($0) }) { return .deep }
        return .light
    }

    /// The question asks to look through the matter: find, search, what was written, everything, a file.
    static func searches(_ lower: String) -> Bool {
        if phrases.contains(where: { lower.contains($0) }) { return true }
        let said = Set(words(of: lower, shortest: 3))
        return !said.isDisjoint(with: searchWords)
    }

    static func words(of text: String, shortest: Int = 4) -> [String] {
        text.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init).filter { $0.count >= shortest }
    }

    /// Asking to look through, in German and English, as words.
    static let searchWords: Set<String> = [
        "find", "finde", "finden", "such", "suche", "suchen", "search", "look", "alles", "everything", "verlauf", "history",
        "nummer", "number", "pdf", "datei", "dateien", "file", "files", "anhang", "anhänge", "attachment", "attachments",
        "dokument", "dokumente", "document", "documents", "scan", "scans", "rechnung", "invoice", "geschrieben", "wrote",
        "written", "damals", "früher", "bisher", "zusammen", "zusammenfassung", "summarise", "summarize", "summary", "raus",
    ]

    /// Asking to look through, as phrases.
    static let phrases = ["wo steht", "where does it say", "what did", "was hat", "was stand", "look up", "look in", "nachschauen",
                          "schau nach", "in der datei", "in the file", "im anhang", "alle nachrichten", "all messages"]

    /// Words of a quick question that say what to do, not what about: they send nothing deep.
    static let common: Set<String> = [
        "aufgabe", "aufgaben", "morgen", "übermorgen", "heute", "termin", "termine", "notiz", "erinnere", "erinner", "erinnerung",
        "erstelle", "erstell", "mach", "mache", "neue", "neuen", "neues", "eine", "einen", "einem", "einer", "bitte", "danke", "für",
        "nächstes", "nächste", "nächsten", "steht", "kommt", "wann", "wer", "wie", "warum", "welche", "welcher", "welches", "noch",
        "auch", "dass", "habe", "hab", "haben", "schon", "sind", "wird", "werden", "kann", "soll", "muss", "mein", "meine", "meinen",
        "diese", "dieser", "dieses", "dann", "aber", "oder", "und", "nicht", "mehr", "woche", "monat", "montag", "dienstag",
        "mittwoch", "donnerstag", "freitag", "samstag", "sonntag", "uhr", "schreib", "schreibe", "antworte", "antwort", "nachricht",
        "task", "tasks", "tomorrow", "today", "note", "remind", "reminder", "create", "make", "please", "thanks", "next", "when",
        "what", "who", "which", "does", "have", "with", "from", "that", "this", "there", "about", "call", "write", "reply", "message",
        "week", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday", "date", "appointment",
    ]
}
