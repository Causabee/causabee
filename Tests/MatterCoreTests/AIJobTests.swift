import Foundation
import Testing
@testable import MatterCore

/// F004: each job the bee gives the AI has its model, in one table the app and the beeserver share;
/// every request says its job; what stays the same is sent first; the model named is the one that wrote.
@Suite("F004 · The right model for each job", .serialized)
struct AIJobTests {
    static let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    struct Table: Decodable {
        struct Row: Decodable { var model: String; var flex: Bool; var testing: [String] }
        var jobs: [String: Row]
    }

    static func serverTable() throws -> Table {
        let data = try Data(contentsOf: root.appendingPathComponent("server/beeserver/src/jobs.json"))
        return try JSONDecoder().decode(Table.self, from: data)
    }

    @Test("F004 AC-2 · The app's table is the server's")
    func sameTable() throws {
        let server = try Self.serverTable()
        #expect(Set(server.jobs.keys) == Set(AIJob.allCases.map(\.rawValue)))
        for job in AIJob.allCases {
            let row = try #require(server.jobs[job.rawValue])
            #expect(row.model == job.model.id, "\(job): the app asks \(job.model.id), the server sets \(row.model)")
            #expect(row.flex == job.flex, "\(job): Flex differs")
            // Every model a job uses or is tested on is one the app knows, prices and names.
            for id in [row.model] + row.testing {
                let model = try #require(Claude.Model.known.first { $0.id == id }, "\(id) is not known to the app")
                #expect(model.label.hasPrefix("OpenAI "))
            }
        }
        #expect(AIJob.chat.flex == false, "the chat never waits for Flex")
    }

    @Test("F004 AC-1 · Every caller says its job")
    func everyCallerSaysItsJob() throws {
        let sources = Self.root.appendingPathComponent("Sources")
        let files = FileManager.default.enumerator(at: sources, includingPropertiesForKeys: nil)?
            .compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" } ?? []
        var calls = 0
        var without: [String] = []
        for file in files where !["Claude.swift", "Judge.swift"].contains(file.lastPathComponent) && !file.path.contains("/MatterSpike/") {
            let lines = try String(contentsOf: file, encoding: .utf8).split(separator: "\n")
            for line in lines where line.contains("claude.send(") || line.contains("client.send(") {
                calls += 1
                if !line.contains("job: .") { without.append(file.lastPathComponent + ": " + line.trimmingCharacters(in: .whitespaces)) }
            }
        }
        #expect(calls >= 6, "the reading, the digest, the brief, the summary, the next step and the chat")
        #expect(without.isEmpty, "\(without)")
    }

    @Test("F004 AC-1 · Through the beeserver, the request names its job and leaves the model to it")
    func headerThroughTheServer() async throws {
        Stub.seen = []
        URLProtocol.registerClass(Stub.self)
        defer { URLProtocol.unregisterClass(Stub.self) }
        let claude = Claude(key: "token", relay: URL(string: "https://beeserver.test")!)
        let body = Claude.body(model: .gptSol, system: "rules", user: "item", schema: ["type": "object"], effort: "low")
        let answer = try await claude.send(body, model: .gptSol, job: .brief)
        let request = try #require(Stub.seen.first)
        #expect(request.value(forHTTPHeaderField: "causabee-job") == "brief")
        let sent = try #require(try JSONSerialization.jsonObject(with: Stub.body(of: request)) as? [String: Any])
        #expect(sent["model"] == nil, "the server sets the job's model")
        #expect(sent["instructions"] as? String == "rules")
        // AC-6: the answer is named for the model that wrote it, not the one asked.
        #expect(answer.servedBy == "gpt-6.1-terra")
        #expect(Claude.Model.serving(answer.servedBy)?.label == "OpenAI GPT-6.1 Terra")
    }

    @Test("F004 AC-1 · With an own key, the request goes to the job's model")
    func ownKey() async throws {
        let body = Claude.body(model: .gptSol, system: "rules", user: "item", schema: ["type": "object"], effort: "low")
        let sent = Claude.openAIBody(body, model: AIJob.read.asked)
        #expect(sent["model"] as? String == AIJob.read.model.id)
        AIJob.trying[.read] = .gptLuna
        defer { AIJob.trying = [:] }
        #expect(AIJob.read.asked == .gptLuna)
        #expect(AIJob.brief.asked == AIJob.brief.model)
    }

    @Test("F004 AC-5 · Each job's prompt starts with what stays the same")
    func fixedPartFirst() {
        let matters = [(name: "care-mum", summary: "Care for Mum after her fall"), (name: "move", summary: "The move to Linden Street")]
        let a = ExtractionPrompt.user(mail: "The nurse comes on Tuesday.", sent: Date(timeIntervalSince1970: 1_790_000_000),
                                      owner: ["Person A"], matters: matters, thread: "care-mum")
        let b = ExtractionPrompt.user(mail: "The van is booked.", sent: Date(timeIntervalSince1970: 1_790_500_000),
                                      owner: ["Person A"], matters: matters)
        let shared = String(zip(a, b).prefix { $0 == $1 }.map(\.0))
        // Everything up to the item's own part is the same bytes for two different items.
        #expect(shared.contains("Matters found so far:"))
        #expect(shared.contains("The move to Linden Street"))
        #expect(!a.prefix(shared.count + 1).contains("sent on"), "the day comes after what stays the same")
        #expect(a.hasSuffix("</email>"))

        // The instructions and the schema go first, the same for every request of a job.
        for (system, schema) in [(ExtractionPrompt.system, ExtractionPrompt.schema), (DigestPrompt.system, DigestPrompt.schema),
                                 (AdviserPrompt.system(writingIn: "English"), AdviserPrompt.schema),
                                 (AssistantPrompt.system, AssistantPrompt.schema)] {
            let one = Claude.openAIBody(Claude.body(model: .gptSol, system: system, user: "one", schema: schema, effort: "low"), model: .gptSol)
            let two = Claude.openAIBody(Claude.body(model: .gptSol, system: system, user: "two", schema: schema, effort: "low"), model: .gptSol)
            #expect(one["instructions"] as? String == two["instructions"] as? String)
            #expect(NSDictionary(dictionary: one["text"] as! [String: Any]) == NSDictionary(dictionary: two["text"] as! [String: Any]))
        }
    }

    @Test("F004 AC-6 · The model named is the model that answered")
    func named() {
        #expect(Claude.Model.serving("gpt-6-luna")?.label == "OpenAI GPT-6 Luna")
        #expect(Claude.Model.serving("gpt-6.1-terra-2026-10-26")?.shortLabel == "GPT-6.1 Terra")
        #expect(Claude.Model.serving("gpt-6.1-sol")?.shortLabel == "GPT-6.1 Sol")
        let words = AIJob.said(ownKey: "with your own key")
        for job in AIJob.allCases { #expect(words.contains(job.model.label)) }
        if Set(AIJob.allCases.map(\.model)).count == 1 { #expect(words.hasPrefix("Everything is read with")) }
        else { #expect(words.contains("only after it did its job as well as GPT-6.1 Sol")) }
    }

    @Test("F004 AC-6 · causabee.app names the model of each job, and no longer one AI when there are more")
    func website() throws {
        let page = try String(contentsOf: Self.root.appendingPathComponent("site/index.html"), encoding: .utf8)
        let models = Set(AIJob.allCases.map(\.model))
        for model in models { #expect(page.contains(model.shortLabel), "causabee.app does not name \(model.shortLabel)") }
        if models.count > 1 {
            #expect(!page.contains("One AI"), "causabee.app still says one AI does everything")
            #expect(page.contains("only after it did its job as well as Sol"))
        }
        // No model the table does not use.
        for model in Claude.Model.known where !models.contains(model) {
            #expect(!page.contains(model.shortLabel), "causabee.app names \(model.shortLabel), which no job uses")
        }
    }

    @Test("F004 · Each model's price, as OpenAI charges it")
    func prices() {
        // A million cached tokens read: Terra $0.05, Luna $0.01; Sol as before.
        #expect(abs(Claude.Model.gptTerra.cost(input: 0, output: 0, cacheRead: 1_000_000) - 0.05) < 1e-9)
        #expect(abs(Claude.Model.gptLuna.cost(input: 1_000_000, output: 1_000_000) - 0.6) < 1e-9)
        #expect(abs(Claude.Model.gptSol.cost(input: 0, output: 0, cacheRead: 1_000_000) - 0.2) < 1e-9)
    }
}

/// The beeserver, as the test sees it: keeps the request and answers as if Terra wrote it.
final class Stub: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var seen: [URLRequest] = []

    static func body(of request: URLRequest) -> Data {
        if let data = request.httpBody { return data }
        guard let stream = request.httpBodyStream else { return Data() }
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let n = stream.read(&buffer, maxLength: buffer.count)
            if n <= 0 { break }
            data.append(buffer, count: n)
        }
        return data
    }

    override class func canInit(with request: URLRequest) -> Bool { request.url?.host == "beeserver.test" }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.seen.append(request)
        let answer: [String: Any] = [
            "model": "gpt-6.1-terra", "status": "completed",
            "output": [["type": "message", "content": [["type": "output_text", "text": "{}"]]]],
            "usage": ["input_tokens": 10, "output_tokens": 2],
        ]
        let data = try! JSONSerialization.data(withJSONObject: answer)
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
