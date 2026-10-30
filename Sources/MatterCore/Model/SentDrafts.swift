import Foundation
import SwiftData

extension LabelIntake.SentDraft {
    /// The drafts opened from a matter in the assistant in the last two weeks, on any device: a
    /// draft card taken — opened in Mail — in a turn about a matter, with the subject it went with.
    public static func recent(in context: ModelContext, now: Date = Date()) -> [LabelIntake.SentDraft] {
        let since = Calendar.current.date(byAdding: .day, value: -days, to: now) ?? now
        let turns = (try? context.fetch(FetchDescriptor<ThreadTurn>(predicate: #Predicate { $0.date > since }))) ?? []
        return turns.flatMap { turn -> [LabelIntake.SentDraft] in
            guard let key = turn.matter?.key else { return [] }
            return opened(in: turn.payload).map { LabelIntake.SentDraft(subject: $0, matterKey: key, date: turn.date) }
        }
    }

    /// The subjects of the drafts a turn's payload says were opened: its draft cards that were taken.
    static func opened(in payload: Data) -> [String] {
        guard let json = (try? JSONSerialization.jsonObject(with: payload)) as? [String: Any],
              let answer = json["answer"] as? [String: Any], let reply = answer["reply"] as? [String: Any],
              let cards = reply["cards"] as? [[String: Any]] else { return [] }
        let applied = Set((json["applied"] as? [Int]) ?? [])
        return cards.enumerated().compactMap { index, card in
            guard applied.contains(index), card["kind"] as? String == "draft_message",
                  let subject = card["subject"] as? String, plain(subject).count >= 4 else { return nil }
            return subject
        }
    }
}
