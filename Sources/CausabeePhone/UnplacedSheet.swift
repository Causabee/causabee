import MatterCore
import SwiftData
import SwiftUI

/// An item that found no matter, opened: what the bee read in it, so the owner can decide where it
/// goes — and the whole text, read again from the mailbox on a tap. Nothing is sent.
struct UnplacedSheet: View {
    let judgement: Judgement
    let matters: [Matter]
    let place: (Matter) -> Void
    let startNew: () -> Void
    let setAside: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var whole: String?
    @State private var loading = false
    @State private var failure: String?

    private var look: UnplacedLook { UnplacedLook(judgement) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(look.title).font(.title3.weight(.semibold)).fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("unplaced.title")
                        Text([look.from, look.date?.formatted(date: .abbreviated, time: .shortened)].compactMap { $0 }.joined(separator: " · "))
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    if let about = look.about {
                        section("What it says") { Text(about).font(.body).fixedSize(horizontal: false, vertical: true) }
                    }
                    if !look.found.isEmpty {
                        section("Found in it") {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(look.found) { line in
                                    Label(line.text, systemImage: line.symbol).font(.subheadline)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }
                    if let why = look.why {
                        section("Why no matter") { Text(why).font(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) }
                    }
                    wholeText
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
            }
            .safeAreaInset(edge: .bottom) { decide }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(.secondary).textCase(.uppercase)
            content()
        }
    }

    /// The whole text: read again from the mailbox, only when asked.
    @ViewBuilder
    private var wholeText: some View {
        if let whole {
            section("The whole text") { Text(whole).font(.callout).textSelection(.enabled).fixedSize(horizontal: false, vertical: true) }
        } else if judgement.source.hasPrefix("imap://") {
            VStack(alignment: .leading, spacing: 6) {
                Button {
                    loading = true
                    failure = nil
                    Task {
                        do { whole = try await MailFiles.text(of: judgement) } catch { failure = "\(error)" }
                        loading = false
                    }
                } label: {
                    HStack(spacing: 8) {
                        if loading { ProgressView() }
                        Text(loading ? "Reading …" : "Show the whole text")
                    }
                }
                .buttonStyle(.gold).disabled(loading)
                .accessibilityIdentifier("unplaced.whole")
                if let failure { Text(failure).font(.footnote).foregroundStyle(Theme.warning) }
            }
        }
    }

    /// Decided here: into a matter, a new one, or not needed.
    private var decide: some View {
        HStack(spacing: 12) {
            Menu {
                Button("A new matter", systemImage: "plus.circle") { dismiss(); startNew() }
                Divider()
                ForEach(matters.filter { !$0.isClosed }.sorted { $0.name < $1.name }) { matter in
                    Button(matter.name) { dismiss(); place(matter) }
                }
            } label: {
                Text("Add to …").frame(maxWidth: .infinity).padding(.vertical, 12)
                    .background(Theme.gold, in: Capsule()).foregroundStyle(.white)
            }
            .accessibilityIdentifier("unplaced.add")
            Button { dismiss(); setAside() } label: {
                Text("Not needed").frame(maxWidth: .infinity).padding(.vertical, 12)
                    .background(Theme.box, in: Capsule()).foregroundStyle(.primary)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("unplaced.aside")
        }
        .font(.body.weight(.medium))
        .padding(.horizontal, 20).padding(.vertical, 10)
        .background(.bar)
    }
}
