import AppKit
import AuthenticationServices
import MatterCore

/// Google's sign-in page in the Mac's own sign-in window, not in Causabee: the owner types their
/// Google password there, where Causabee cannot see it, and Google comes back to the app's own
/// address with a code. The window is the one Safari's passwords and passkeys work in.
@MainActor
final class GoogleSignInFlow: NSObject, ASWebAuthenticationPresentationContextProviding {
    private var session: ASWebAuthenticationSession?

    /// Signs in and returns the account. `keep`: the refresh token goes into the Keychain — not in
    /// the setup's test mode, which keeps nothing.
    func signIn(hint: String? = nil, keep: Bool = true) async throws -> (account: MailAccount, accessToken: String) {
        let attempt = try GoogleSignIn.start(hint: hint)
        let callback: URL = try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(url: attempt.url, callbackURLScheme: GoogleSignIn.redirectScheme) { url, error in
                if let url { continuation.resume(returning: url) } else { continuation.resume(throwing: error ?? GoogleSignIn.Failure.noCode) }
            }
            session.presentationContextProvider = self
            // A fresh window each time: no cookie from an earlier sign-in chooses the account.
            session.prefersEphemeralWebBrowserSession = true
            self.session = session
            session.start()
        }
        session = nil
        return try await GoogleSignIn.finish(attempt, callback: callback, keep: keep)
    }

    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        MainActor.assumeIsolated { NSApp.keyWindow ?? NSApp.windows.first ?? ASPresentationAnchor() }
    }

    /// The owner closed the window: not an error worth showing.
    static func wasCancelled(_ error: Error) -> Bool {
        (error as? ASWebAuthenticationSessionError)?.code == .canceledLogin
    }
}
