import Foundation
import Testing
@testable import MatterCore

@Suite("Signing in with Google")
struct GoogleSignInTests {
    @Test("The XOAUTH2 answer is the address and the token, in the form Gmail takes")
    func xoauth2() {
        let encoded = GoogleSignIn.xoauth2(user: "jan@gmail.example", token: "ya29.token")
        let decoded = String(decoding: Data(base64Encoded: encoded) ?? Data(), as: UTF8.self)
        #expect(decoded == "user=jan@gmail.example\u{1}auth=Bearer ya29.token\u{1}\u{1}")
    }

    @Test("The signed-in address is read from the ID token")
    func email() {
        let claims = #"{"email":"jan@gmail.example","email_verified":true}"#
        let payload = GoogleSignIn.base64URL(Data(claims.utf8))
        #expect(GoogleSignIn.email(inIDToken: "e30.\(payload).signature") == "jan@gmail.example")
        #expect(GoogleSignIn.email(inIDToken: "not a token") == nil)
    }

    @Test("A Google account logs in with AUTHENTICATE XOAUTH2, never with LOGIN")
    func authenticate() async throws {
        let server = ScriptedServer { tag, command in
            command.hasPrefix("AUTHENTICATE XOAUTH2 ") ? "\(tag) OK Success\r\n" : "* CAPABILITY IMAP4rev1\r\n\(tag) OK\r\n"
        }
        let client = IMAPClient(transport: server)
        try await client.start()
        try await client.authenticate(user: "jan@gmail.example", token: "ya29.token")
        #expect(server.sent.contains { $0.hasPrefix("AUTHENTICATE XOAUTH2 ") })
        #expect(!server.sent.contains { $0.hasPrefix("LOGIN") })
    }

    @Test("A refused token ends in an error, after answering Gmail's explanation with an empty line")
    func refused() async throws {
        let server = ScriptedServer { tag, command in
            if command.hasPrefix("AUTHENTICATE") { return "+ eyJzdGF0dXMiOiI0MDAifQ==\r\n" }
            if command.isEmpty { return "M2 NO [AUTHENTICATIONFAILED] Invalid credentials\r\n" }
            return "* CAPABILITY IMAP4rev1\r\n\(tag) OK\r\n"
        }
        let client = IMAPClient(transport: server)
        try await client.start()
        await #expect(throws: IMAPError.self) { try await client.authenticate(user: "jan@gmail.example", token: "old") }
        #expect(server.sent.last == "")
    }

    @Test("Without a client ID there is no sign-in to start")
    func notConfigured() {
        if !GoogleSignIn.isConfigured {
            #expect(throws: GoogleSignIn.Failure.self) { try GoogleSignIn.start() }
        }
    }
}
