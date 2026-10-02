import Foundation

/// The owner as a sender: to tell the mail they sent from the mail that came in.
public struct Me: Sendable {
    let addresses: Set<String>
    let names: OwnerNames

    /// `names` as the owner gave them, names and addresses mixed, and the mail accounts' addresses.
    public init(names: [String], addresses: [String] = []) {
        self.addresses = Set((names.filter { $0.contains("@") } + addresses).map { $0.trimmingCharacters(in: .whitespaces).lowercased() })
        self.names = OwnerNames(names)
    }

    /// The owner's names, and the addresses of the mail accounts on this device, read once.
    public init(names: [String], withAccounts: Bool) {
        self.init(names: names, addresses: withAccounts ? Self.accountAddresses : [])
    }

    static let accountAddresses: [String] = Keychain.accounts().map(\.user)

    /// `Mara Voss <mara.voss@mail.example>` is the owner's when the address is, or the whole name
    /// is: a bare first name could be anyone's.
    public func sent(_ from: String) -> Bool {
        let address = Email.address(in: from).lowercased()
        if !address.isEmpty, addresses.contains(address) { return true }
        guard let name = Email.displayName(in: from) else { return false }
        return names.isFullName(name)
    }
}
