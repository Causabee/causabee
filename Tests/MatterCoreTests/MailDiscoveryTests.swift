import Foundation
import Testing
@testable import MatterCore

@Suite("Finding a mail server from an address")
struct MailDiscoveryTests {
    @Test func knownWithoutAsking() {
        #expect(MailDiscovery.known("ralf@gmail.com")?.kind == .gmail)
        #expect(MailDiscovery.known("a@me.com")?.host == "imap.mail.me.com")
        #expect(MailDiscovery.known("a@example.org") == nil)
        #expect(MailDiscovery.known("not an address") == nil)
    }

    @Test func imapOverTLSFromAThunderbirdFile() {
        let xml = """
        <clientConfig version="1.1"><emailProvider id="ionos.de">
          <incomingServer type="pop3"><hostname>pop.ionos.de</hostname><port>995</port><socketType>SSL</socketType></incomingServer>
          <incomingServer type="imap"><hostname>imap.ionos.de</hostname><port>143</port><socketType>STARTTLS</socketType></incomingServer>
          <incomingServer type="imap"><hostname>imap.ionos.de</hostname><port>993</port><socketType>SSL</socketType></incomingServer>
        </emailProvider></clientConfig>
        """
        #expect(MailDiscovery.imap(inConfig: xml, source: "Thunderbird") == .init(kind: .other, host: "imap.ionos.de", port: 993, source: "Thunderbird"))
    }

    @Test func googleWorkspaceIsGmail() {
        let xml = #"<incomingServer type="imap"><hostname>imap.gmail.com</hostname><port>993</port><socketType>SSL</socketType></incomingServer>"#
        #expect(MailDiscovery.imap(inConfig: xml, source: "MX")?.kind == .gmail)
    }

    @Test func thePreferredMailServer() {
        let json = Data(#"{"Answer":[{"data":"20 alt1.aspmx.l.google.com."},{"data":"10 aspmx.l.google.com."}]}"#.utf8)
        #expect(MailDiscovery.preferredMX(inDNSJSON: json) == "aspmx.l.google.com")
    }
}
