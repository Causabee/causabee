import Foundation
import Testing
@testable import MatterCore

@Suite("An error, in words a person reads")
struct PlainWordsTests {
    @Test("What the AI service answered is never shown raw: no status number, none of its own words")
    func theServicesAnswerStaysOut() {
        let body = #"{"type":"error","error":{"type":"overloaded_error","message":"Overloaded"}}"#
        for status in [400, 401, 402, 403, 404, 408, 413, 429, 500, 502, 503, 504, 529] {
            let words = plainWords(Claude.Failure.http(status: status, body: body))
            #expect(!words.contains("HTTP"))
            #expect(!words.contains("\(status)"))
            #expect(!words.contains("overloaded_error"))
            #expect(!words.contains("{"))
            // It says what to do: every one ends in a sentence that starts with a verb to act on.
            #expect(words.contains("Try") || words.contains("Check") || words.contains("Choose") || words.contains("Wait") || words.contains("Top"))
        }
    }

    @Test("A busy service, a wrong key and an empty account say different things")
    func theyAreToldApart() {
        #expect(plainWords(Claude.Failure.http(status: 529, body: "")) == "The AI service is busy right now. Try again in a minute.")
        #expect(plainWords(Claude.Failure.http(status: 401, body: "")).contains("API key"))
        #expect(plainWords(Claude.Failure.http(status: 402, body: "")).contains("credit"))
        #expect(plainWords(Claude.Failure.http(status: 429, body: "")).contains("Wait a minute"))
    }

    @Test("The other failures of asking: no developer's words")
    func theOthers() {
        for failure in [Claude.Failure.noKey, .unreadable("no text block"), .refused(category: "cyber"), .truncated] {
            let words = plainWords(failure)
            for word in ["max_tokens", ".env", "ANTHROPIC", "fallback", "text block", "cyber", "unreadable response"] {
                #expect(!words.contains(word))
            }
        }
        #expect(plainWords(Claude.Failure.noKey).contains("Settings"))
    }

    @Test("For the log and the command line the failure still says all of it")
    func theLogKeepsIt() {
        #expect("\(Claude.Failure.http(status: 529, body: "Overloaded"))" == "HTTP 529: Overloaded")
    }
}
