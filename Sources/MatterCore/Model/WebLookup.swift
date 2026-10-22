import Foundation

/// Looking something up on the web for a matter, kept apart from it: a general question — a
/// period to object, what an insurer usually pays — that the adviser asks, checked on the device
/// for anything personal, shown to the owner word for word, and sent only on their tap, alone,
/// in a request of its own. The matter never reaches the web search; the web never reaches the
/// matter except as the answer and its sources, kept under the brief.
public enum WebLookup {
    public struct Source: Codable, Equatable, Sendable {
        public var title: String
        public var url: String
        public init(title: String, url: String) { self.title = title; self.url = url }
    }

    /// A question the adviser would like answered, and — once looked up — the answer.
    public struct Lookup: Codable, Equatable, Sendable, Identifiable {
        public enum State: String, Codable, Sendable { case open, dismissed, answered }
        public var id = UUID()
        public var question: String
        public var state: State = .open
        public var answer: String?
        public var sources: [Source] = []
        public var date: Date?
        /// Asked in the assistant: its answer stands in the thread, and the brief only knows it —
        /// it is not shown under the brief. False for what the brief asked, and in lookups kept before.
        public var fromAssistant = false
        public init(question: String, fromAssistant: Bool = false) { self.question = question; self.fromAssistant = fromAssistant }

        enum CodingKeys: String, CodingKey { case id, question, state, answer, sources, date, fromAssistant }

        public init(from decoder: any Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            id = try c.decode(UUID.self, forKey: .id)
            question = try c.decode(String.self, forKey: .question)
            state = try c.decode(State.self, forKey: .state)
            answer = try c.decodeIfPresent(String.self, forKey: .answer)
            sources = try c.decodeIfPresent([Source].self, forKey: .sources) ?? []
            date = try c.decodeIfPresent(Date.self, forKey: .date)
            fromAssistant = try c.decodeIfPresent(Bool.self, forKey: .fromAssistant) ?? false
        }
    }

    /// Why a question may not go out, or nil when it may: anything that could say whose matter it
    /// is — a disguised name, a person's name, a number, an address — stops it. Checked on the
    /// device, before the owner is even asked.
    public static func refusal(_ question: String, personal: [String] = []) -> String? {
        let text = question.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty { return "It is empty." }
        if text.count > 300 { return "It is too long to be a general question." }
        if text.range(of: #"\[[A-Za-z]+ [A-Z0-9]+\]"#, options: .regularExpression) != nil { return "It names someone." }
        if text.range(of: #"\d{5,}"#, options: .regularExpression) != nil { return "It has a number in it that could be the owner's." }
        if text.range(of: #"[\w.+-]+@[\w-]+\.[\w.]+|https?://|www\."#, options: .regularExpression) != nil { return "It has an address in it." }
        let lower = text.lowercased()
        for word in personal.map({ $0.trimmingCharacters(in: .whitespaces).lowercased() }) where word.count >= 3 {
            let pattern = "(?<![\\p{L}\\p{N}])" + NSRegularExpression.escapedPattern(for: word) + "(?![\\p{L}\\p{N}])"
            if lower.range(of: pattern, options: .regularExpression) != nil { return "It names someone of the matter." }
        }
        return nil
    }

    /// The parts of names worth guarding: whole names; a person's given and family name each; of a
    /// longer name — a company's, "Healthbridge Care Fund" — its first word only: "Care" and "Fund"
    /// are words anyone asks about.
    public static func personal(_ names: [String]) -> [String] {
        // A name the owner marked as public may be asked about: it says nothing about anyone.
        Array(Set(names.filter { !PublicNames.covers($0) }.flatMap { name -> [String] in
            let words = name.split { !$0.isLetter }.map(String.init)
            return [name] + (words.count <= 2 ? words : Array(words.prefix(1)))
        // And a public word stays public out of any other spelling: "Expedia/Rentscape" brought
        // "Rentscape" back as a word of its own, and held the question back after all.
        }.filter { $0.count >= 3 && !PublicNames.covers($0) }))
    }

    /// The question, looked up: a short answer in `language`, with its sources, and what it cost.
    /// Claude's or OpenAI's own web search; Mistral has none to offer.
    public static func ask(_ question: String, language: String?, country: String?, claude: Claude,
                           model: Claude.Model) async throws -> (answer: String, sources: [Source], cost: Double) {
        guard refusal(question) == nil else { throw Refused() }
        let instructions = """
        Answer this general question from the web, in at most four short sentences\(language.map { ", in \($0)" } ?? ""). \
        Say what the rule or the usual practice is, with the numbers that matter — periods, amounts, \
        who decides — and when it depends on something, on what. Prefer official and primary \
        sources. No advice for a particular person: there is none to give, the question is general.
        """
        if model.isOpenAI { return try await openAI(question, instructions: instructions, country: country, key: claude.key, model: model) }
        if model.isMistral { throw NotOffered() }
        return try await anthropic(question, instructions: instructions, country: country, claude: claude, model: model)
    }

    public struct Refused: LocalizedError {
        public var errorDescription: String? { "This question has something personal in it and is not sent." }
    }

    public struct NotOffered: LocalizedError {
        public var errorDescription: String? { "Looking things up works with Claude or OpenAI. Choose one for the assistant in Settings." }
    }

    /// One web search costs about a cent with either service, on top of the words.
    static let perSearch = 0.01

    static func anthropic(_ question: String, instructions: String, country: String?, claude: Claude,
                          model: Claude.Model) async throws -> (answer: String, sources: [Source], cost: Double) {
        // Two searches and a short think: a general question, and three searches took forty seconds.
        var tool: [String: Any] = ["type": "web_search_20260209", "name": "web_search", "max_uses": 2]
        if let country { tool["user_location"] = ["type": "approximate", "country": country] }
        var messages: [[String: Any]] = [["role": "user", "content": question]]
        var request = URLRequest(url: claude.endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 300
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(claude.key, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        var texts: [String] = [], sources: [Source] = [], cost = 0.0
        // A long search can pause its turn: it is handed back as it stands, to go on — a few times at most.
        for _ in 0..<3 {
            var body: [String: Any] = ["model": model.id, "max_tokens": 2000, "system": instructions, "messages": messages, "tools": [tool]]
            if model.takesEffort { body["output_config"] = ["effort": "low"] }
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, response) = try await Claude.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard status == 200 else { throw Claude.Failure.http(status: status, body: String(decoding: data, as: UTF8.self)) }
            guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw Claude.Failure.unreadable("not a JSON object") }
            let usage = object["usage"] as? [String: Any] ?? [:]
            let searches = (usage["server_tool_use"] as? [String: Any])?["web_search_requests"] as? Int ?? 0
            cost += model.cost(input: usage["input_tokens"] as? Int ?? 0, output: usage["output_tokens"] as? Int ?? 0) + Double(searches) * perSearch
            let content = object["content"] as? [[String: Any]] ?? []
            for block in content where block["type"] as? String == "text" {
                texts.append(block["text"] as? String ?? "")
                for citation in block["citations"] as? [[String: Any]] ?? [] {
                    if let url = citation["url"] as? String { sources.append(Source(title: citation["title"] as? String ?? url, url: url)) }
                }
            }
            guard object["stop_reason"] as? String == "pause_turn" else { break }
            messages.append(["role": "assistant", "content": content])
            texts = []
        }
        return (answer(texts), unique(sources), cost)
    }

    static func openAI(_ question: String, instructions: String, country: String?, key: String,
                       model: Claude.Model) async throws -> (answer: String, sources: [Source], cost: Double) {
        var tool: [String: Any] = ["type": "web_search"]
        if let country { tool["user_location"] = ["type": "approximate", "country": country] }
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/responses")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 300
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue("Bearer \(key)", forHTTPHeaderField: "authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "model": model.id, "instructions": instructions, "input": question, "tools": [tool], "max_output_tokens": 2000,
            // A general question, answered from what the search finds: no need to think long.
            "reasoning": ["effort": "low"],
        ] as [String: Any])
        let (data, response) = try await Claude.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else { throw Claude.Failure.http(status: status, body: String(decoding: data, as: UTF8.self)) }
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw Claude.Failure.unreadable("not a JSON object") }
        let output = object["output"] as? [[String: Any]] ?? []
        let searches = output.filter { $0["type"] as? String == "web_search_call" }.count
        var texts: [String] = [], sources: [Source] = []
        for item in output where item["type"] as? String == "message" {
            for part in item["content"] as? [[String: Any]] ?? [] where part["type"] as? String == "output_text" {
                texts.append(part["text"] as? String ?? "")
                for note in part["annotations"] as? [[String: Any]] ?? [] where note["type"] as? String == "url_citation" {
                    if let url = note["url"] as? String { sources.append(Source(title: note["title"] as? String ?? url, url: url)) }
                }
            }
        }
        let usage = object["usage"] as? [String: Any] ?? [:]
        let cost = model.cost(input: usage["input_tokens"] as? Int ?? 0, output: usage["output_tokens"] as? Int ?? 0) + Double(searches) * perSearch
        return (answer(texts), unique(sources), cost)
    }

    /// The words, without the links the services put inline: the sources stand under the answer.
    static func answer(_ texts: [String]) -> String {
        texts.joined().replacingOccurrences(of: #"\s*\(\[[^\]]*\]\([^)]*\)\)"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Each source once, without what the services add to their links for themselves.
    static func unique(_ sources: [Source]) -> [Source] {
        var seen = Set<String>()
        return sources.compactMap { source in
            var url = source.url
            if var parts = URLComponents(string: url) {
                parts.queryItems = parts.queryItems?.filter { !$0.name.hasPrefix("utm_") }
                if parts.queryItems?.isEmpty == true { parts.queryItems = nil }
                url = parts.string ?? url
            }
            guard seen.insert(url).inserted else { return nil }
            return Source(title: source.title, url: url)
        }
        .prefix(4).map { $0 }
    }
}
