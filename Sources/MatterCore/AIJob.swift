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
    /// The chat, where someone waits for the answer.
    case chat

    /// The model the job is asked of — through the beeserver, which sets it too, or with an own key.
    public var model: Claude.Model {
        switch self {
        // 10 November: digests and the brief passed their test on Terra; reading stays on Sol
        // (Terra and Luna below the bar). docs/features/004-the-right-model-for-each-job/tests/
        case .read: .gptSol
        case .digest: .gptTerra
        case .brief: .gptTerra
        case .chat: .gptSol
        }
    }

    /// Whether it may wait for Flex, at half the price. The beeserver decides; the chat never waits.
    public var flex: Bool { self != .chat }

    /// For `matter-spike jobs` only: a model to try a job on, in place of the table's.
    nonisolated(unsafe) public static var trying: [AIJob: Claude.Model] = [:]

    /// The model a request of this job is sent to now.
    public var asked: Claude.Model { Self.trying[self] ?? model }
}

public extension AIJob {
    /// Which model does which job, as Settings says it on every device — and causabee.app too.
    /// While every job is on one model, the one sentence of before.
    static func said(ownKey: String) -> String {
        let read = AIJob.read.model, digest = AIJob.digest.model, brief = AIJob.brief.model, chat = AIJob.chat.model
        if Set(allCases.map(\.model)).count == 1 { return "Everything is read with \(chat.label): through the beeserver with Pro, or \(ownKey)." }
        let reading = digest == read ? "Read, sorted and digested with \(read.label)." : "Read and sorted with \(read.label)."
        let writing = digest == brief && digest != read ? "Each item's digest, and each matter's brief and next step, with \(brief.label)."
            : "Each matter's brief and next step with \(brief.label)."
        return reading + " " + writing + " The chat with \(chat.label). "
            + "Each model was chosen only after it did its job as well as GPT-6.1 Sol. All of them get only pseudonymised text."
    }
}
