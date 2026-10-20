import Foundation

/// What Causabee understands of one matter: what it is about and what the owner wants from it,
/// who is who, what is agreed, what is open and what waits, what could go wrong, and the next
/// decision — written by the adviser from the facts, and corrected by the owner, whose word it
/// never overwrites. With it, the changes the adviser proposes to the to-do list, each kept until
/// the owner takes it or puts it away. Kept on the matter as JSON, the same on every device.
public struct Brief: Codable, Equatable, Sendable {
    public enum Part: String, Codable, CaseIterable, Sendable {
        case about, goal, people, agreed, open, waiting, risks, decision
    }

    public struct Line: Codable, Equatable, Sendable {
        public var part: Part
        public var text: String
        public init(part: Part, text: String) { self.part = part; self.text = text }
    }

    /// Something the owner said about the matter: the adviser writes everything else around it.
    public struct Said: Codable, Equatable, Sendable, Identifiable {
        public var id = UUID()
        public var text: String
        public var date = Date()
        public init(text: String) { self.text = text }
    }

    /// A change to the to-do list the adviser proposes: a card like the assistant's, with the
    /// facts its ids stand for — by id on this device, by key on the others.
    public struct Proposal: Codable, Equatable, Sendable, Identifiable {
        public enum State: String, Codable, Sendable { case open, taken, dismissed }
        public var id = UUID()
        public var card: AssistantPrompt.Reply.Card
        public var refs: [String: FactRef]
        public var keys: [String: String] = [:]
        public var state: State = .open
        public init(card: AssistantPrompt.Reply.Card, refs: [String: FactRef], keys: [String: String] = [:]) {
            self.card = card; self.refs = refs; self.keys = keys
        }
    }

    public var lines: [Line] = []
    public var said: [Said] = []
    public var proposals: [Proposal] = []
    public var writtenAt: Date?

    public init(lines: [Line] = [], said: [Said] = [], proposals: [Proposal] = [], writtenAt: Date? = nil) {
        self.lines = lines; self.said = said; self.proposals = proposals; self.writtenAt = writtenAt
    }

    public func lines(_ part: Part) -> [String] { lines.filter { $0.part == part }.map(\.text) }

    /// Waiting for the owner: proposed, and neither taken nor put away.
    public var open: [Proposal] { proposals.filter { $0.state == .open } }

    /// What the owner put away: not proposed again.
    public var dismissed: [Proposal] { proposals.filter { $0.state == .dismissed } }

    /// Written anew: the owner's words stay, and what the owner decided on stays known — the
    /// newest few — while what was only proposed gives way to what is proposed now.
    public func rewritten(lines: [Line], proposals new: [Proposal], at date: Date = Date()) -> Brief {
        let decided = proposals.filter { $0.state != .open }.suffix(30)
        return Brief(lines: lines, said: said, proposals: Array(decided) + new, writtenAt: date)
    }

    /// For the facts sheet: what is understood, and what the owner said — the owner's words first.
    public var forFacts: String? {
        var parts: [String] = []
        if !said.isEmpty {
            parts.append("What the owner said about this matter (always right):\n" + said.map { "- \($0.text)" }.joined(separator: "\n"))
        }
        if !lines.isEmpty {
            parts.append("The brief written before (may be out of date; the facts and the owner's words win):\n"
                         + lines.map { "- \($0.part.rawValue): \($0.text)" }.joined(separator: "\n"))
        }
        return parts.isEmpty ? nil : parts.joined(separator: "\n")
    }

    /// One line on what the matter is about, for reading new mail with.
    public var gist: String? {
        let about = (lines(.about) + lines(.goal)).prefix(2).joined(separator: " ")
        return about.isEmpty ? nil : about
    }
}

extension Matter {
    /// The brief, read from its JSON; nil while none was written or said.
    public var shownBrief: Brief? {
        get { brief.flatMap { try? JSONDecoder().decode(Brief.self, from: Data($0.utf8)) } }
        set {
            brief = newValue.flatMap { try? JSONEncoder().encode($0) }.flatMap { String(data: $0, encoding: .utf8) }
            briefAt = newValue?.writtenAt
        }
    }

    /// Keeps something the owner said about the matter: the next brief is written around it.
    public func say(_ text: String) {
        let words = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !words.isEmpty else { return }
        var brief = shownBrief ?? Brief()
        brief.said.append(Brief.Said(text: words))
        shownBrief = brief
    }

    /// Takes back something the owner said.
    public func unsay(_ id: UUID) {
        guard var brief = shownBrief else { return }
        brief.said.removeAll { $0.id == id }
        shownBrief = brief
    }

    /// A proposal taken or put away.
    public func decide(_ proposal: UUID, _ state: Brief.Proposal.State) {
        guard var brief = shownBrief, let index = brief.proposals.firstIndex(where: { $0.id == proposal }) else { return }
        brief.proposals[index].state = state
        shownBrief = brief
    }
}
