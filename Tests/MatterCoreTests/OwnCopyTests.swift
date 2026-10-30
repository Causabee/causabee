import Foundation
import Testing
@testable import MatterCore

@Suite("Only Causabee's own copy of a file is ever let go")
struct OwnCopyTests {
    private let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]

    @Test("The attachments folder beside a store is Causabee's; the owner's folders are not")
    func ownFolders() {
        #expect(MatterFolders.isOurCopy(support.appendingPathComponent("Causabee/Anhänge/1a2b3c4d-Scan.pdf")))
        #expect(MatterFolders.isOurCopy(support.appendingPathComponent("Causabee-Development/Anhänge/x.png")))
        let home = FileManager.default.homeDirectoryForCurrentUser
        #expect(!MatterFolders.isOurCopy(home.appendingPathComponent("Desktop/Scan.pdf")))
        #expect(!MatterFolders.isOurCopy(home.appendingPathComponent("Documents/Anhänge/Scan.pdf")))
        #expect(!MatterFolders.isOurCopy(support.appendingPathComponent("Causabee/matters.store")))
        #expect(!MatterFolders.isOurCopy(support.appendingPathComponent("Other App/Anhänge/x.png")))
    }
}
