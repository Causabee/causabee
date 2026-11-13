import Foundation

/// The jobs the bee gives the AI, each with its model (F004). The same table as the beeserver's
/// `server/beeserver/src/jobs.json`; `AIJobTests` fails if the two differ. A job's model changes
/// in both, and only after its test on the demo's matters (`matter-spike jobs`).
public enum AIJob: String, CaseIterable, Sendable {
    /// Reading what comes in: which matter it belongs to, what it brings.
    case read
    /// A digest of one item.
    case digest
    /// A matter's brief, summary and next step.
    case brief
    /// The chat, where someone waits for the answer: a question asked with the whole matter.
    case chat
    /// F005: a quick question, asked with what it needs of the matter.
    case chatLight = "chat-light"
    /// F005: a quick question asked again with the whole matter, when its light answer lacked something.
    case chatDeeper = "chat-deeper"

    /// One of the chat's three: someone waits.
    public var isChat: Bool { self == .chat || self == .chatLight || self == .chatDeeper }

    /// The model the job is asked of — through the beeserver, which sets it too, or with an own key.
    public var model: Claude.Model {
        switch self {
        // 10 November: digests and the brief passed their test on Terra; reading stays on Sol
        // (Terra and Luna below the bar). docs/features/004-the-right-model-for-each-job/tests/
        case .read: .gptSol
        case .digest: .gptTerra
        case .brief: .gptTerra
        case .chat, .chatDeeper: .gptSol
        // F005: on Sol until the light questions pass their test on Terra (AC-7).
        case .chatLight: .gptSol
        }
    }

    /// How hard the model thinks. Reading on "low" since 10 November: as good as Sol left to itself
    /// on the demo's matters, a little cheaper and nearly twice as fast (tests/results.md).
    public var effort: String { isChat ? "medium" : "low" }

    /// Whether it may wait for Flex, at half the price. The beeserver decides; the chat never waits.
    public var flex: Bool { !isChat }

    /// For `matter-spike jobs` only: a model to try a job on, in place of the table's.
    nonisolated(unsafe) public static var trying: [AIJob: Claude.Model] = [:]

    /// The model a request of this job is sent to now.
    public var asked: Claude.Model { Self.trying[self] ?? model }
}

public extension AIJob {
    /// F005: ", quick questions with OpenAI GPT-6.1 Terra" — only while quick questions go to
    /// another model than the rest of the chat.
    static func quickQuestions(sentTo: Bool = false) -> String {
        guard chatLight.model != chat.model else { return "" }
        return String(format: sentTo ? String(localized: ", quick questions to %@", bundle: .module)
                                     : String(localized: ", quick questions with %@", bundle: .module), chatLight.model.label)
    }

    /// Where the chat's questions go, as its footer says it: "OpenAI GPT-6.1 Sol", or with the model of quick questions.
    static var chatSentTo: String { chat.model.label + quickQuestions(sentTo: true) }

    /// Which model does which job, as Settings says it on every device — and causabee.app too.
    /// While every job is on one model, the one sentence of before.
    static func said(ownKey: String) -> String {
        let read = AIJob.read.model, digest = AIJob.digest.model, brief = AIJob.brief.model, chat = AIJob.chat.model
        if Set(allCases.map(\.model)).count == 1 {
            return String(format: String(localized: "Everything is read with %@: through the beeserver with Pro, or %@.", bundle: .module), chat.label, ownKey)
        }
        let reading = digest == read ? String(format: String(localized: "Read, sorted and digested with %@.", bundle: .module), read.label)
                                     : String(format: String(localized: "Read and sorted with %@.", bundle: .module), read.label)
        let writing = digest == brief && digest != read
            ? String(format: String(localized: "Each item's digest, and each matter's brief and next step, with %@.", bundle: .module), brief.label)
            : String(format: String(localized: "Each matter's brief and next step with %@.", bundle: .module), brief.label)
        return reading + " " + writing + " "
            + String(format: String(localized: "The chat with %@%@. ", bundle: .module), chat.label, quickQuestions())
            + String(localized: "Each model was chosen only after it did its job as well as GPT-6.1 Sol. All of them get only pseudonymised text.", bundle: .module)
    }
}
