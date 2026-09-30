import Foundation
import FoundationModels

/// Apple's own model, in macOS: nothing to download, and its answer is held to the shape asked
/// for while it is written, so it is always one that can be read.
@available(macOS 26.0, *)
struct AppleEngine: LocalEngine {
    var name: String { "Apple (Foundation Models)" }

    @Generable
    struct Answer {
        @Guide(description: "The key of the matter from the list, or neu, or keine")
        var matter: String
        @Guide(description: "For neu: a short name for the new matter; otherwise empty")
        var newMatterTitle: String
        var todos: [Todo]
        var dates: [Day]
        var parties: [Party]
    }

    @Generable
    struct Todo {
        var text: String
        @Guide(.anyOf(["me", "we", "other"]))
        var owner: String
        @Guide(description: "YYYY-MM-DD or empty")
        var due: String
    }

    @Generable
    struct Day {
        @Guide(description: "YYYY-MM-DD")
        var day: String
        @Guide(description: "HH:MM or empty")
        var time: String
        var what: String
        @Guide(.anyOf(["appointment", "deadline"]))
        var kind: String
    }

    @Generable
    struct Party {
        var name: String
        var role: String
    }

    func read(instructions: String, prompt: String) async throws -> LocalAnswer {
        let session = LanguageModelSession(instructions: instructions)
        let answer = try await session.respond(to: prompt, generating: Answer.self, options: GenerationOptions(sampling: .greedy)).content
        return LocalAnswer(matter: answer.matter, newMatterTitle: answer.newMatterTitle,
                           todos: answer.todos.map { .init(text: $0.text, owner: $0.owner, due: $0.due) },
                           dates: answer.dates.map { .init(day: $0.day, time: $0.time, what: $0.what, kind: $0.kind) },
                           parties: answer.parties.map { .init(name: $0.name, role: $0.role) })
    }
}
