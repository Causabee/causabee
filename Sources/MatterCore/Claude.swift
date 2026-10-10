import Foundation
import CryptoKit

/// The one place in the project that talks to the network.
///
/// Swift has no official Anthropic SDK, so this is the Messages API over plain HTTPS, kept as
/// small as the spike needs: one request, one JSON answer, retries for the failures that are
/// worth retrying. Everything it is ever handed has already been through the disguise; it never
/// sees `mapping.json`, and it never logs the key.
public struct Claude: Sendable {
    public enum Failure: Error, CustomStringConvertible {
        case noKey
        case http(status: Int, body: String)
        case unreadable(String)
        case refused(category: String?)
        case truncated

        public var description: String {
            switch self {
            case .noKey: "no API key: set ANTHROPIC_API_KEY, or put it in .env"
            case .http(let status, let body): "HTTP \(status): \(body.prefix(300))"
            case .unreadable(let why): "unreadable response: \(why)"
            case .refused(let category): "declined by the model\(category.map { " (\($0))" } ?? ""), fallback included"
            case .truncated: "the answer hit max_tokens and was cut off"
            }
        }
    }

    /// The models question 6 compares, with their prices, so question 7 can be answered from the
    /// log rather than from an invoice. Per million tokens, first-party API rates, checked
    /// against the pricing table on 2026-09-27.
    public struct Model: Sendable, Hashable {
        public var id: String
        public var inputPerMillion: Double
        public var outputPerMillion: Double

        public static let opus = Model(id: "claude-opus-5", inputPerMillion: 5, outputPerMillion: 25)
        public static let sonnet = Model(id: "claude-sonnet-5", inputPerMillion: 2, outputPerMillion: 10)
        public static let haiku = Model(id: "claude-haiku-4-5", inputPerMillion: 1, outputPerMillion: 5)
        /// Mistral Large 3, from Mistral AI in Paris — to compare, sent the same disguised mail
        /// with the same instructions. Prices from mistral.ai/pricing/api on 2026-09-28.
        public static let mistralLarge = Model(id: "mistral-large-latest", inputPerMillion: 0.5, outputPerMillion: 1.5)
        /// Mistral Medium 3.5, April 2026: newer than Large 3, and priced three times as high.
        public static let mistralMedium = Model(id: "mistral-medium-latest", inputPerMillion: 1.5, outputPerMillion: 7.5)
        /// OpenAI's, by the names and prices on developers.openai.com/api/docs/pricing, 2026-09-29.
        public static let gptAstra = Model(id: "gpt-6-astra", inputPerMillion: 10, outputPerMillion: 50)
        public static let gptSol = Model(id: "gpt-6.1-sol", inputPerMillion: 2, outputPerMillion: 10)
        public static let known = [opus, sonnet, haiku, mistralLarge, mistralMedium, gptAstra, gptSol]
        /// What the owner can choose between in the app.
        public static let choices = [opus, mistralLarge, mistralMedium, gptSol, gptAstra]

        /// Sent to OpenAI's Responses API.
        public var isOpenAI: Bool { id.hasPrefix("gpt-") }
        /// The key its API takes, by the name it has in the Keychain and in `.env`.
        public var keyName: String { isMistral ? "MISTRAL_API_KEY" : isOpenAI ? "OPENAI_API_KEY" : "ANTHROPIC_API_KEY" }

        /// The name a person reads.
        public var label: String {
            switch id {
            case Model.opus.id: "Claude Opus 5"
            case Model.sonnet.id: "Claude Sonnet 5"
            case Model.haiku.id: "Claude Haiku 4.5"
            case Model.mistralLarge.id: "Mistral Large 3"
            case Model.mistralMedium.id: "Mistral Medium 3.5"
            case Model.gptAstra.id: "OpenAI GPT-6 Astra"
            case Model.gptSol.id: "OpenAI GPT-6.1 Sol"
            default: id
            }
        }

        /// A mail: about 5,000 tokens in and 900 out, from the label's record. Opus reads its
        /// instructions from the prompt cache; the others pay for them every time.
        public var perMail: Double { id == Model.opus.id ? 0.035 : cost(input: 5_000, output: 900) * 1.1 }

        /// Sent to Mistral's API rather than Anthropic's.
        public var isMistral: Bool { id.hasPrefix("mistral") }

        public static func named(_ name: String) -> Model? {
            switch name.lowercased() {
            case "opus": opus
            case "sonnet": sonnet
            case "haiku": haiku
            case "mistral": mistralLarge
            case "mistral-medium": mistralMedium
            case "openai", "gpt": gptSol
            case "gpt-astra": gptAstra
            default: known.first { $0.id == name }
            }
        }

        /// Whether a response's `model` field is this model. The API may answer with a dated
        /// snapshot — `claude-haiku-4-5-20251001` for `claude-haiku-4-5` — and taking that for a
        /// different model priced Haiku's whole first run at Opus rates.
        public func isServing(_ served: String) -> Bool {
            // Mistral answers "mistral-large-2512" for "mistral-large-latest".
            if isMistral { return served.hasPrefix(id.replacingOccurrences(of: "-latest", with: "")) }
            if isOpenAI { return served == id || served.hasPrefix(id + "-") }
            return served == id || served.hasPrefix(id + "-")
        }

        public static func serving(_ served: String) -> Model? {
            known.first { $0.isServing(served) }
        }

        /// Cached input is priced apart: writing it costs a quarter more than ordinary input, reading
        /// it back a tenth. `input` is what was neither.
        public func cost(input: Int, output: Int, cacheWrite: Int = 0, cacheRead: Int = 0) -> Double {
            (Double(input) * inputPerMillion + Double(output) * outputPerMillion
             + Double(cacheWrite) * inputPerMillion * 1.25 + Double(cacheRead) * inputPerMillion * 0.1) / 1_000_000
        }

        /// Opus 5 thinks adaptively by default and has a safety classifier that can decline;
        /// Haiku 4.5 does neither. The request is shaped to match.
        var thinksAdaptively: Bool { id != Model.haiku.id && !isMistral && !isOpenAI }
        var takesFallbacks: Bool { id == Model.opus.id }
        var takesEffort: Bool { id != Model.haiku.id && !isMistral && !isOpenAI }
    }

    public struct Answer: Sendable {
        public var json: Data
        /// Which model wrote it. Usually the one asked; a different one when Opus declined and the
        /// fallback answered.
        public var servedBy: String
        public var inputTokens: Int
        public var outputTokens: Int
        public var seconds: Double
        /// The instructions, written to the cache on the first call and read back on the next.
        public var cacheWriteTokens = 0
        public var cacheReadTokens = 0

        public var cost: Double {
            (Model.serving(servedBy) ?? .opus).cost(input: inputTokens, output: outputTokens,
                                                   cacheWrite: cacheWriteTokens, cacheRead: cacheReadTokens)
        }
    }

    public let key: String
    public var endpoint = URL(string: "https://api.anthropic.com/v1/messages")!

    public init(key: String) {
        self.key = key
    }

    /// `ANTHROPIC_API_KEY` from the environment, or from a `.env` file in the working directory
    /// — the file is gitignored, and only that one line is read from it.
    /// `keychain: false` for a test: it must never read, or make macOS ask for, the owner's keys.
    public static func key(environment: [String: String] = ProcessInfo.processInfo.environment,
                           dotEnv: URL = URL(fileURLWithPath: ".env"), named name: String = "ANTHROPIC_API_KEY",
                           keychain: Bool = true) -> String? {
        if let key = environment[name]?.trimmed, !key.isEmpty { return key }
        // Pasted in the app's settings: the app has no working directory with a `.env` in it.
        if keychain, let key = APIKeys.get(name) { return key }
        guard let text = try? String(contentsOf: dotEnv, encoding: .utf8) else { return nil }
        for line in text.split(whereSeparator: \.isNewline) {
            let line = line.trimmed
            guard line.hasPrefix(name + "=") else { continue }
            var value = String(line.dropFirst(name.count + 1)).trimmed
            if value.count >= 2, let first = value.first, first == value.last, first == "\"" || first == "'" {
                value = String(value.dropFirst().dropLast())
            }
            return value.isEmpty ? nil : value
        }
        return nil
    }

    // MARK: The request

    /// The request body, built separately so a dry run can write exactly what would be sent.
    public static func body(model: Model, system: String, user: String, schema: [String: Any],
                            effort: String?) -> [String: Any] {
        var outputConfig: [String: Any] = ["format": ["type": "json_schema", "schema": schema]]
        if let effort, model.takesEffort { outputConfig["effort"] = effort }
        var body: [String: Any] = [
            "model": model.id,
            "max_tokens": 16000,
            // The instructions are the same for every mail, and marked for the cache: the first
            // call writes them, every call within five minutes reads them at a tenth of the price.
            // Opus 5 caches from 512 tokens; Haiku 4.5 only from 4,096, so there it does nothing —
            // no error, no saving.
            "system": [["type": "text", "text": system, "cache_control": ["type": "ephemeral"]]],
            "messages": [["role": "user", "content": user]],
            "output_config": outputConfig,
        ]
        if model.takesFallbacks { body["fallbacks"] = "default" }
        return body
    }

    /// The request as the local answer cache knows it: the instructions as plain text, without
    /// the prompt-cache marker. Adding the marker changed no answer, and must not make every
    /// answer already paid for look new.
    public static func cacheKey(_ body: [String: Any]) throws -> String {
        var plain = body
        if let blocks = body["system"] as? [[String: Any]] {
            plain["system"] = blocks.compactMap { $0["text"] as? String }.joined()
        }
        let data = try JSONSerialization.data(withJSONObject: plain, options: [.sortedKeys])
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    /// The key the model's own API takes: Anthropic's, or Mistral's as `MISTRAL_API_KEY`.
    public static func key(for model: Model) -> String? {
        key(named: model.keyName)
    }

    /// The request, sent. A connection that drops on the way — the phone changing from Wi-Fi to the
    /// mobile network, a server closing a kept connection — is tried again, twice, before it is an error.
    static func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        var attempt = 0
        while true {
            attempt += 1
            do {
                return try await URLSession.shared.data(for: request)
            } catch let error as URLError where [.networkConnectionLost, .cannotConnectToHost, .dnsLookupFailed, .secureConnectionFailed].contains(error.code) && attempt < 3 {
                try await Task.sleep(for: .seconds(Double(attempt)))
            }
        }
    }

    public func send(_ body: [String: Any], model: Model) async throws -> Answer {
        if model.isMistral { return try await sendMistral(body, model: model) }
        if model.isOpenAI { return try await sendOpenAI(body, model: model) }
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        // Nothing is streamed back, so the server says nothing until it is done; a long mail
        // with thinking on can take minutes, and the default of sixty seconds would give up.
        request.timeoutInterval = 600
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(key, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        if model.takesFallbacks { request.setValue("server-side-fallback-2026-07-01", forHTTPHeaderField: "anthropic-beta") }
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])

        let started = Date()
        var attempt = 0
        while true {
            attempt += 1
            let (data, response) = try await Self.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            if status == 200 { return try Self.answer(from: data, seconds: Date().timeIntervalSince(started)) }

            // Rate limits, overload and server errors are worth waiting out; anything else is a
            // mistake in the request and will not get better by being sent again.
            let retryable = status == 429 || status == 529 || status >= 500
            guard retryable, attempt < 6 else {
                throw Failure.http(status: status, body: String(decoding: data, as: UTF8.self))
            }
            let told = (response as? HTTPURLResponse)?.value(forHTTPHeaderField: "retry-after").flatMap(Double.init)
            let wait = min(told ?? pow(2, Double(attempt)), 60)
            try await Task.sleep(for: .seconds(wait))
        }
    }

    // MARK: Mistral

    /// The same request, in Mistral's shape: the instructions as a system message, the schema as
    /// a strict `json_schema` response format. The body the cache is keyed on stays Anthropic's,
    /// so a Mistral answer is found again by the very request that would have gone to Claude.
    static func mistralBody(_ body: [String: Any], model: Model) -> [String: Any] {
        let system = (body["system"] as? [[String: Any]])?.compactMap { $0["text"] as? String }.joined() ?? (body["system"] as? String ?? "")
        let messages = (body["messages"] as? [[String: Any]]) ?? []
        let schema = ((body["output_config"] as? [String: Any])?["format"] as? [String: Any])?["schema"] ?? [:]
        return [
            "model": model.id,
            "max_tokens": 8000,
            "temperature": 0,
            "messages": [["role": "system", "content": system]] + messages,
            "response_format": ["type": "json_schema", "json_schema": ["name": "answer", "schema": schema, "strict": true]],
        ]
    }

    func sendMistral(_ body: [String: Any], model: Model) async throws -> Answer {
        var request = URLRequest(url: URL(string: "https://api.mistral.ai/v1/chat/completions")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 600
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue("Bearer \(key)", forHTTPHeaderField: "authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: Self.mistralBody(body, model: model), options: [.sortedKeys])
        let started = Date()
        var attempt = 0
        while true {
            attempt += 1
            let (data, response) = try await Self.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            if status == 200 {
                guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let choice = (object["choices"] as? [[String: Any]])?.first,
                      let message = choice["message"] as? [String: Any], let text = message["content"] as? String
                else { throw Failure.unreadable("no message in Mistral's answer") }
                if choice["finish_reason"] as? String == "length" { throw Failure.truncated }
                let usage = object["usage"] as? [String: Any] ?? [:]
                return Answer(json: Data(text.utf8), servedBy: object["model"] as? String ?? model.id,
                              inputTokens: usage["prompt_tokens"] as? Int ?? 0, outputTokens: usage["completion_tokens"] as? Int ?? 0,
                              seconds: Date().timeIntervalSince(started))
            }
            guard status == 429 || status >= 500, attempt < 6 else {
                throw Failure.http(status: status, body: String(decoding: data, as: UTF8.self))
            }
            try await Task.sleep(for: .seconds(min(pow(2, Double(attempt)), 60)))
        }
    }

    // MARK: OpenAI

    /// The same request for OpenAI's Responses API: the instructions as `instructions`, the mail
    /// as `input`, the schema as a strict `json_schema` text format.
    static func openAIBody(_ body: [String: Any], model: Model) -> [String: Any] {
        let system = (body["system"] as? [[String: Any]])?.compactMap { $0["text"] as? String }.joined() ?? (body["system"] as? String ?? "")
        let user = ((body["messages"] as? [[String: Any]]) ?? []).compactMap { $0["content"] as? String }.joined(separator: "\n\n")
        let schema = ((body["output_config"] as? [String: Any])?["format"] as? [String: Any])?["schema"] ?? [:]
        return [
            "model": model.id,
            "instructions": system,
            "input": user,
            "max_output_tokens": 8000,
            "text": ["format": ["type": "json_schema", "name": "answer", "schema": schema, "strict": true]],
        ]
    }

    func sendOpenAI(_ body: [String: Any], model: Model) async throws -> Answer {
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/responses")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 600
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue("Bearer \(key)", forHTTPHeaderField: "authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: Self.openAIBody(body, model: model), options: [.sortedKeys])
        let started = Date()
        var attempt = 0
        while true {
            attempt += 1
            let (data, response) = try await Self.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            if status == 200 {
                guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    throw Failure.unreadable("not a JSON object")
                }
                if object["status"] as? String == "incomplete" { throw Failure.truncated }
                let texts = ((object["output"] as? [[String: Any]]) ?? []).flatMap { ($0["content"] as? [[String: Any]]) ?? [] }
                if texts.contains(where: { $0["type"] as? String == "refusal" }) { throw Failure.refused(category: nil) }
                guard let text = texts.first(where: { $0["type"] as? String == "output_text" })?["text"] as? String else {
                    throw Failure.unreadable("no text in OpenAI's answer")
                }
                let usage = object["usage"] as? [String: Any] ?? [:]
                return Answer(json: Data(text.utf8), servedBy: object["model"] as? String ?? model.id,
                              inputTokens: usage["input_tokens"] as? Int ?? 0, outputTokens: usage["output_tokens"] as? Int ?? 0,
                              seconds: Date().timeIntervalSince(started))
            }
            guard status == 429 || status >= 500, attempt < 6 else {
                throw Failure.http(status: status, body: String(decoding: data, as: UTF8.self))
            }
            try await Task.sleep(for: .seconds(min(pow(2, Double(attempt)), 60)))
        }
    }

    static func answer(from data: Data, seconds: Double) throws -> Answer {
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw Failure.unreadable("not a JSON object")
        }
        switch object["stop_reason"] as? String {
        case "refusal":
            let details = object["stop_details"] as? [String: Any]
            throw Failure.refused(category: details?["category"] as? String)
        case "max_tokens":
            throw Failure.truncated
        default:
            break
        }
        // Thinking blocks come first and are empty by default; the answer is the text block.
        let blocks = object["content"] as? [[String: Any]] ?? []
        guard let text = blocks.last(where: { $0["type"] as? String == "text" })?["text"] as? String else {
            throw Failure.unreadable("no text block")
        }
        let usage = object["usage"] as? [String: Any] ?? [:]
        return Answer(json: Data(text.utf8),
                      servedBy: object["model"] as? String ?? "",
                      inputTokens: usage["input_tokens"] as? Int ?? 0,
                      outputTokens: usage["output_tokens"] as? Int ?? 0,
                      seconds: seconds,
                      cacheWriteTokens: usage["cache_creation_input_tokens"] as? Int ?? 0,
                      cacheReadTokens: usage["cache_read_input_tokens"] as? Int ?? 0)
    }
}

public extension Claude.Failure {
    /// The failure for the owner to read: what happened and what to do now — no status number,
    /// nothing of the service's own answer. `description` stays as it is, for the log and the
    /// command line.
    var forPeople: String {
        switch self {
        case .noKey:
            return "No API key for this AI model yet. Add one in Settings."
        case .http(let status, _):
            switch status {
            case 401, 403: return "The AI service did not accept the API key. Check it in Settings."
            case 402: return "The AI service says the account has no credit left. Top it up with the provider, then try again."
            case 404: return "The AI service does not know this model. Choose another in Settings."
            case 408, 504: return "The AI service took too long to answer. Try again."
            case 413: return "This is too much text for the AI model at once. Try with less, or choose another model in Settings."
            case 429: return "Too many requests to the AI service just now. Wait a minute, then try again."
            case 529, 503, 502: return "The AI service is busy right now. Try again in a minute."
            case 500...599: return "The AI service had a problem of its own. Try again in a minute."
            default: return "The AI service could not take the request. Try again; if it stays, choose another model in Settings."
            }
        case .unreadable:
            return "The AI's answer could not be read. Try again."
        case .refused:
            return "The AI model declined to answer this. Try other words, or choose another model in Settings."
        case .truncated:
            return "The AI's answer was too long and was cut off. Try again, or ask about less at once."
        }
    }
}

/// An error in words a person reads — "The connection was lost." — not the system's own dump of it.
public func plainWords(_ error: Error) -> String {
    if let error = error as? URLError {
        switch error.code {
        case .notConnectedToInternet, .dataNotAllowed: return "No connection to the internet. Nothing was sent."
        case .networkConnectionLost: return "The connection was lost on the way. Try again."
        case .timedOut: return "No answer came in time. Try again."
        case .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed: return "The service could not be reached. Try again in a moment."
        case .secureConnectionFailed: return "No secure connection could be made. Try again."
        case .cancelled: return "Stopped."
        default: return error.localizedDescription
        }
    }
    if error is CancellationError { return "Stopped." }
    // What the AI service answered, in words with what to do — not "HTTP 529" and its raw answer.
    if let failure = error as? Claude.Failure { return failure.forPeople }
    let words = "\(error)"
    // The system's own errors print their whole record; what they say for people is shorter.
    return words.hasPrefix("Error Domain=") ? error.localizedDescription : words
}
