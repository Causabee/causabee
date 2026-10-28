import Testing
@testable import MatterCore

@Suite("Mail providers, and a pasted password looked at before it is sent")
struct MailProvidersTests {
    @Test func providersByAddressAndServer() {
        #expect(MailProvider.by(address: "a@gmx.de")?.name == "GMX")
        #expect(MailProvider.by(address: "a@gmail.com")?.kind == .gmail)
        #expect(MailProvider.by(address: "a@example.org") == nil)
        #expect(MailProvider.by(host: "imap.gmail.com")?.kind == .gmail)
        #expect(MailProvider.isOutlook("someone@hotmail.de"))
        #expect(!MailProvider.isOutlook("someone@gmail.com"))
    }

    @Test func googlesSixteenLetters() {
        #expect(PasswordCheck.of("vqzk rmpa xlte hwns", for: .google) == .right)
        #expect(PasswordCheck.of("vqzkrmpaxltehwns", for: .google) == .right)
        #expect(PasswordCheck.of("vqzk rmpa", for: .google) == .partial)
        #expect(PasswordCheck.of("Sommer2024!", for: .google) == .wrongKind)
        #expect(PasswordCheck.of("  ", for: .google) == .empty)
        #expect(PasswordCheck.cleaned("Vqzk Rmpa xlte hwns", for: .google) == "vqzkrmpaxltehwns")
    }

    @Test func applesDashedCode() {
        #expect(PasswordCheck.of("abcd-efgh-ijkl-mnop", for: .apple) == .right)
        #expect(PasswordCheck.of("abcdefghijklmnop", for: .apple) == .right)
        #expect(PasswordCheck.cleaned("abcdefghijklmnop", for: .apple) == "abcd-efgh-ijkl-mnop")
        #expect(PasswordCheck.of("abcd-efgh", for: .apple) == .partial)
        #expect(PasswordCheck.of("MyApple#Pass1", for: .apple) == .wrongKind)
    }

    @Test func otherProvidersTakeWhatIsTyped() {
        #expect(PasswordCheck.of("anything 123", for: .usual) == .right)
        #expect(PasswordCheck.cleaned(" anything 123 ", for: .usual) == "anything 123")
    }
}
