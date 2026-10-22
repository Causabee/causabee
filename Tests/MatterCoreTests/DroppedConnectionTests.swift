import Foundation
import Network
import Testing
@testable import MatterCore

@Suite("A connection that drops is tried again, and said in plain words")
struct DroppedConnectionTests {
    @Test("Socket not connected, reset, closed: dropped; a refused login is not")
    func dropped() {
        #expect(isDroppedConnection(NWError.posix(.ENOTCONN)))
        #expect(isDroppedConnection(NWError.posix(.ECONNRESET)))
        #expect(isDroppedConnection(IMAPError.closed))
        #expect(!isDroppedConnection(IMAPError.refused(command: "LOGIN", answer: "NO")))
        #expect(!plainWords(NWError.posix(.ENOTCONN)).contains("POSIX"))
    }
}
