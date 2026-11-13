import AppKit
import MatterCore
import SwiftData
import SwiftUI

/// An item that found no matter, opened beside the sidebar: what the bee read in it, so the owner
/// can decide where it goes — and the original in Mail, on a click. Nothing is sent.
struct UnplacedLookView: View {
    let judgement: Judgement
    let matters: [Matter]
    let place: (Matter) -> Void
    let startNew: () -> Void
    let setAside: () -> Void
    @Environment(\.dismiss) private var dismiss

    private var look: UnplacedLook { UnplacedLook(judgement) }

    /// `message://<Message-ID>`: Mail opens the original, if it has the account.
    private var original: URL? {
        let id = judgement.emailID
        guard !id.isEmpty, judgement.source.hasPrefix("imap://") || judgement.source.hasPrefix("file://") || judgement.source.hasPrefix("/"),
              let encoded = "<\(id)>".addingPercentEncoding(withAllowedCharacters: .alphanumerics.union(CharacterSet(charactersIn: "@.-_"))) else { return nil }
        return URL(string: "message://" + encoded)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(look.title).font(.headline).fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
                        Text([look.from, look.date?.formatted(date: .abbreviated, time: .shortened)].compactMap { $0 }.joined(separator: " · "))
                            .font(.callout).foregroundStyle(.secondary)
                    }
                    if let about = look.about {
                        section(String(localized: "What it says")) { Text(about).fixedSize(horizontal: false, vertical: true).textSelection(.enabled) }
                    }
                    if !look.found.isEmpty {
                        section(String(localized: "Found in it")) {
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(look.found) { line in
                                    Label(line.text, systemImage: line.symbol).fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }
                    if let why = look.why {
                        section(String(localized: "Why no matter")) { Text(RuleReason.word(why)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) }
                    }
                    if let original {
                        Button("Open the original in Mail") { NSWorkspace.shared.open(original) }
                            .buttonStyle(.gold)
                            .accessibilityIdentifier("unplaced.original")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
            }
            Divider()
            HStack(spacing: 10) {
                Menu("Add to …") {
                    Button("New Matter …") { dismiss(); startNew() }
                    Divider()
                    ForEach(matters.filter { !$0.isClosed }.sorted { $0.name < $1.name }) { matter in
                        Button(matter.name) { dismiss(); place(matter) }
                    }
                }
                .fixedSize()
                .accessibilityIdentifier("unplaced.add")
                Button("Not needed") { dismiss(); setAside() }
                    .accessibilityIdentifier("unplaced.aside")
                Spacer()
                Button("Close") { dismiss() }.keyboardShortcut(.cancelAction)
            }
            .padding(12)
        }
        .frame(width: 360)
        .frame(maxHeight: 480)
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(.secondary).textCase(.uppercase)
            content()
        }
    }
}
