import Foundation
import CryptoKit

/// A model that decides which of two lists of to-dos mean the same things to do.
///
/// Word stems could not tell "Accept the offer by replying to all" from nothing, nor
/// "Feedbackgespräch" from the sentence it sits in, and they cannot tell a different verb for the
/// same thing from a different thing. A reader can. So step 8 can ask one: the owner's to-dos and
/// the pipeline's, for one mail at a time, and back comes which pairs are the same, each with a
/// reason, so the judge can be checked the way the matcher was.
///
/// Both lists go through the same disguise as the mail did. The judge sees `[Person A]`, never a
/// name. And it is not the model it judges: Claude Sonnet 5 judges Haiku and Opus alike, rather
/// than Opus marking its own homework.
public struct Judge: Sendable {
    public var model: Claude.Model
    public var claude: Claude?
    public var cache: URL

    public init(model: Claude.Model = .sonnet, claude: Claude?, cache: URL) {
        self.model = model
        self.claude = claude
        self.cache = cache
    }

    public static let version = "judge-v1"

    static let system = """
    You compare two lists of to-dos taken from the same email: one written by the person who \
    owns the mailbox, one written by software. Say which items mean the same thing to do.

    Two items are the same when doing one is doing the other — the same action on the same \
    thing — however differently they are worded, and whatever language they are in. A short \
    item and a long one can be the same: "Feedbackgespräch" and "Bestätigen, ob Mittwoch 10 Uhr \
    für das Feedbackgespräch passt" are. A different action on the same thing is not the same: \
    "Angebot prüfen" and "Angebot annehmen" are two to-dos. Ignore who is said to do it; that is \
    judged separately. When one item covers two of the other list's, pair it with the closer one \
    only.

    Each item is used at most once. Names have been replaced by tags such as [Person A]; treat \
    them as names. Give a short reason for every pair, in German.
    """

    static var schema: [String: Any] {
        ["type": "object", "additionalProperties": false, "required": ["pairs"],
         "properties": ["pairs": ["type": "array", "items": [
             "type": "object", "additionalProperties": false, "required": ["owner_item", "software_item", "reason"],
             "properties": ["owner_item": ["type": "integer"], "software_item": ["type": "integer"], "reason": ["type": "string"]],
         ]]]]
    }

    public struct Pair: Codable, Sendable {
        public var ownerItem: Int
        public var softwareItem: Int
        public var reason: String
        enum CodingKeys: String, CodingKey { case ownerItem = "owner_item", softwareItem = "software_item", reason }
    }
    struct Answer: Codable { var pairs: [Pair] }

    public struct Verdict: Sendable {
        public var pairs: [(expected: Int, found: Int, reason: String)]
        public var cost: Double
        public var cached: Bool
    }

    /// Items are numbered from 1 for the judge and handed back from 0.
    public func judge(expected: [String], found: [String], subject: String) async throws -> Verdict {
        guard !expected.isEmpty, !found.isEmpty else { return Verdict(pairs: [], cost: 0, cached: true) }
        func numbered(_ items: [String]) -> String {
            items.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n")
        }
        let user = "Email subject: \(subject)\n\nThe owner's to-dos:\n\(numbered(expected))\n\nThe software's to-dos:\n\(numbered(found))"
        let body = Claude.body(model: model, system: Self.system, user: user, schema: Self.schema, effort: "low")

        let name = try Claude.cacheKey(body)
        let file = cache.appendingPathComponent("judge-" + model.id).appendingPathComponent(name + ".json")

        var cached = true
        var answer: Claude.Answer
        if let data = try? Data(contentsOf: file), let stored = try? JSONDecoder().decode(Stored.self, from: data) {
            answer = Claude.Answer(json: Data(stored.json.utf8), servedBy: stored.servedBy,
                                   inputTokens: stored.inputTokens, outputTokens: stored.outputTokens, seconds: 0)
        } else {
            guard let claude else { throw Claude.Failure.noKey }
            answer = try await claude.send(body, model: model)
            cached = false
            let stored = Stored(json: String(decoding: answer.json, as: UTF8.self), servedBy: answer.servedBy,
                                inputTokens: answer.inputTokens, outputTokens: answer.outputTokens)
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(stored).write(to: file, options: .atomic)
        }

        let pairs = try Self.pairs(from: answer.json, expected: expected.count, found: found.count)
        let served = Claude.Model.serving(answer.servedBy) ?? model
        return Verdict(pairs: pairs, cost: served.cost(input: answer.inputTokens, output: answer.outputTokens,
                                                       cacheWrite: answer.cacheWriteTokens, cacheRead: answer.cacheReadTokens),
                       cached: cached)
    }

    /// The judge's answer, numbered from 1, as pairs from 0. A judge that numbers outside the
    /// lists, or uses an item twice, is overruled quietly: the first valid use stands.
    static func pairs(from json: Data, expected: Int, found: Int) throws -> [(expected: Int, found: Int, reason: String)] {
        let decoded = try JSONDecoder().decode(Answer.self, from: json)
        var usedE = Set<Int>(), usedF = Set<Int>()
        var pairs: [(expected: Int, found: Int, reason: String)] = []
        for pair in decoded.pairs {
            let (e, f) = (pair.ownerItem - 1, pair.softwareItem - 1)
            guard (0..<expected).contains(e), (0..<found).contains(f), !usedE.contains(e), !usedF.contains(f) else { continue }
            usedE.insert(e); usedF.insert(f)
            pairs.append((e, f, pair.reason))
        }
        return pairs
    }

    struct Stored: Codable {
        var json: String
        var servedBy: String
        var inputTokens: Int
        var outputTokens: Int
    }
}
