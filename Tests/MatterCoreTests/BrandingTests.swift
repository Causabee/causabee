import Foundation
import Testing
@testable import MatterCore

/// Files attached to mail are read by themselves — but a logo, a signature, a banner is only the
/// mail's dress: never read, never sent, nothing paid for it.
struct BrandingTests {
    static let mailSource = Source(kind: .mail, pointer: "imap://x;UID=1", messageID: "<1@x>")

    static let dress: [(String, String, Int)] = [
        ("image001.png", "image/png", 80_000), ("image002.jpg", "image/jpeg", 120_000),
        ("Outlook-1.png", "image/png", 60_000), ("logo.png", "image/png", 90_000), ("Firmenlogo.jpg", "image/jpeg", 70_000),
        ("signature.png", "image/png", 50_000), ("Signatur_Kessler.png", "image/png", 64_000), ("banner-autumn.jpg", "image/jpeg", 200_000),
        ("linkedin.png", "image/png", 4_000), ("facebook-icon.png", "image/png", 3_000), ("twitter.png", "image/png", 2_000),
        ("instagram.png", "image/png", 5_000), ("xing.png", "image/png", 3_000), ("youtube.png", "image/png", 6_000),
        ("badge.png", "image/png", 40_000), ("footer.jpg", "image/jpeg", 90_000), ("header.png", "image/png", 150_000),
        ("spacer.gif", "image/gif", 43), ("animated.gif", "image/gif", 400_000), ("tiny.png", "image/png", 12_000),
        ("pixel.png", "image/png", 68), ("icon_phone.png", "image/png", 1_200), ("ATT00001.png", "image/png", 36_000),
    ]

    static let sent: [(String, String, Int)] = [
        ("Offer Kessler.pdf", "application/pdf", 310_000), ("Rechnung 2026-11.pdf", "application/pdf", 90_000),
        ("IMG_4512.jpeg", "image/jpeg", 2_400_000), ("Photo of the letter.jpg", "image/jpeg", 1_100_000),
        ("Screenshot 2026-11-08 at 10.12.png", "image/png", 640_000), ("Scan_Vertrag.pdf", "application/pdf", 1_800_000),
        ("Grundriss.png", "image/png", 900_000), ("damage-rear-bumper.jpg", "image/jpeg", 1_500_000),
        ("Kontoauszug.pdf", "application/pdf", 120_000), ("Befund.pdf", "application/pdf", 260_000),
    ]

    @Test("A mail's dress is never read", arguments: dress.map { $0.0 }, [0])
    func dressNotRead(name: String, _: Int) {
        let (_, type, size) = Self.dress.first { $0.0 == name }!
        let file = Document(name: name, contentType: type, byteCount: size, source: Self.mailSource)
        #expect(file.isBranding, "\(name) was taken for something sent")
        #expect(!file.isReadable)
    }

    @Test("What was sent — a PDF, a photo, a scan, a screenshot — is read", arguments: sent.map { $0.0 }, [0])
    func sentIsRead(name: String, _: Int) {
        let (_, type, size) = Self.sent.first { $0.0 == name }!
        let file = Document(name: name, contentType: type, byteCount: size, source: Self.mailSource)
        #expect(!file.isBranding, "\(name) was taken for a logo")
        #expect(file.isReadable)
        #expect(file.reading == .kept, "\(name) is not waiting to be read")
    }
}
