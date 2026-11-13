import MatterCore
import SwiftData
import SwiftUI

/// F008 AC-12: the person's name, asked once, on a matter's page, while none is known — so the bee
/// knows which tasks are theirs. The Mac fills in its own user name (`NSFullUserName()`); the
/// iPhone and the iPad have no card of their own, so their field starts empty. Saved in
/// `Profile.names`, the name is known on every device and the line is gone.
struct NameLine: View {
    @Environment(\.modelContext) private var context
    @Query private var profiles: [Profile]
    @State private var editing = false
    @State private var name = ""

    private var asks: Bool { !DemoData.isRequested && Welcome.asksName(names: profiles.first?.names ?? []) }

    var body: some View {
        if asks {
            VStack(alignment: .leading, spacing: 10) {
                #if os(macOS)
                let full = NSFullUserName().trimmingCharacters(in: .whitespaces)
                if !editing, !full.isEmpty {
                    HStack(spacing: 12) {
                        Text("\(Welcome.nameAskMac) \(full)?")
                        Spacer(minLength: 0)
                        Button("Yes") { save(full) }.filledButton()
                        Button("Change") { name = full; editing = true }.buttonStyle(.gold)
                    }
                } else {
                    form
                }
                #else
                form
                #endif
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            #if os(macOS)
            .padding(12)
            .quietBox()
            #else
            .phoneBox()
            #endif
        }
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(Welcome.nameAsk).fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 10) {
                TextField("Your name", text: $name)
                    .textFieldStyle(.roundedBorder)
                    #if os(iOS)
                    .textContentType(.name)
                    #endif
                    .onSubmit { save(name) }
                Button("Save") { save(name) }.filledButton()
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    private func save(_ typed: String) {
        let name = typed.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        if let profile = profiles.first {
            profile.names = [name] + profile.names.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        } else {
            context.insert(Profile(names: [name]))
        }
        try? context.save()
        editing = false
    }
}
