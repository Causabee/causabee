import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// Matterbee in the share sheet: a screenshot, a photo or a PDF shared from any app goes into the
/// matter chosen here — or Matterbee decides — and waits until Matterbee opens, where it comes up
/// scanned in that matter's assistant. Nothing is read or sent here (Figma "iOS/ShareSheet").
final class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        let model = ShareModel(context: extensionContext)
        let host = UIHostingController(rootView: ShareView(model: model))
        addChild(host)
        host.view.frame = view.bounds
        host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(host.view)
        host.didMove(toParent: self)
        model.load()
    }
}

@MainActor
@Observable
final class ShareModel {
    struct Piece: Identifiable {
        let id = UUID()
        let data: Data
        let name: String
        let preview: UIImage?
    }

    enum State: Equatable {
        case loading
        case choosing
        case added(String)
        case failed(String)
    }

    private weak var context: NSExtensionContext?
    var pieces: [Piece] = []
    var state: State = .loading
    let choices = ShareInbox.choices()
    /// The matter chosen; none: Matterbee decides.
    var chosen: String?

    init(context: NSExtensionContext?) { self.context = context }

    func load() {
        let providers = (context?.inputItems as? [NSExtensionItem] ?? []).flatMap { $0.attachments ?? [] }
        Task {
            for provider in providers {
                if let piece = await Self.piece(from: provider) { pieces.append(piece) }
            }
            state = pieces.isEmpty ? .failed("Matterbee takes pictures and PDFs.") : .choosing
        }
    }

    func add() {
        do {
            for piece in pieces { try ShareInbox.put(piece.data, named: piece.name, into: chosen) }
            state = .added(choices.first { $0.key == chosen }?.name ?? "")
            Task {
                try? await Task.sleep(for: .seconds(1.6))
                context?.completeRequest(returningItems: nil)
            }
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func cancel() {
        context?.cancelRequest(withError: NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError))
    }

    /// A PDF as itself; a picture as its file, or — from the screenshot editor, which hands over
    /// only an image — as a PNG.
    private static func piece(from provider: NSItemProvider) async -> Piece? {
        let stamp = Date().formatted(.iso8601.year().month().day().time(includingFractionalSeconds: false)).replacingOccurrences(of: ":", with: ".")
        for type in [UTType.pdf, UTType.image] where provider.hasItemConformingToTypeIdentifier(type.identifier) {
            if let (data, name) = await file(of: provider, type: type) {
                return Piece(data: data, name: name, preview: type == .pdf ? nil : UIImage(data: data))
            }
            if type == .image, let image = await image(of: provider), let data = image.pngData() {
                return Piece(data: data, name: "Screenshot \(stamp).png", preview: image)
            }
        }
        return nil
    }

    private static func file(of provider: NSItemProvider, type: UTType) async -> (Data, String)? {
        await withCheckedContinuation { done in
            _ = provider.loadFileRepresentation(forTypeIdentifier: type.identifier) { url, _ in
                guard let url, let data = try? Data(contentsOf: url) else { done.resume(returning: nil); return }
                let name = provider.suggestedName.map { $0 + "." + url.pathExtension } ?? url.lastPathComponent
                done.resume(returning: (data, name))
            }
        }
    }

    private static func image(of provider: NSItemProvider) async -> UIImage? {
        await withCheckedContinuation { done in
            provider.loadItem(forTypeIdentifier: UTType.image.identifier) { item, _ in
                switch item {
                case let image as UIImage: done.resume(returning: image)
                case let data as Data: done.resume(returning: UIImage(data: data))
                case let url as URL: done.resume(returning: (try? Data(contentsOf: url)).flatMap(UIImage.init(data:)))
                default: done.resume(returning: nil)
                }
            }
        }
    }
}

struct ShareView: View {
    @Bindable var model: ShareModel

    var body: some View {
        Group {
            switch model.state {
            case .loading:
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            case .choosing:
                choosing
            case .added(let name):
                added(name)
            case .failed(let why):
                VStack(spacing: 14) {
                    Text(why).multilineTextAlignment(.center).foregroundStyle(.secondary)
                    Button("Close") { model.cancel() }.foregroundStyle(Theme.gold)
                }
                .padding(24).frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Theme.canvas)
        .tint(Theme.gold)
    }

    private var choosing: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    what
                    VStack(alignment: .leading, spacing: 8) {
                        Text("INTO").font(.caption).foregroundStyle(.secondary).kerning(0.5)
                        VStack(spacing: 0) {
                            row(key: nil, title: "Matterbee decides", sub: "it suggests the matter when you sort it in", bee: true)
                            ForEach(model.choices) { choice in
                                Divider().padding(.leading, 50)
                                row(key: choice.key, title: choice.name,
                                    sub: choice.last.map { "last mail " + $0.formatted(.dateTime.month(.abbreviated).day().locale(Locale(identifier: "en_US"))) }, bee: false)
                            }
                        }
                        .background(Theme.card, in: RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line))
                        Text(model.choices.isEmpty ? "Open Matterbee once, and your matters are here to choose."
                                                   : "Your open matters, the latest first.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 16).padding(.top, 4).padding(.bottom, 24)
            }
            .background(Theme.canvas)
            .navigationTitle("Matterbee")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { model.cancel() } }
                ToolbarItem(placement: .confirmationAction) { Button("Add") { model.add() }.fontWeight(.semibold) }
            }
        }
    }

    private var what: some View {
        HStack(alignment: .center, spacing: 14) {
            HStack(spacing: -30) {
                ForEach(model.pieces.prefix(3)) { piece in
                    Group {
                        if let preview = piece.preview {
                            Image(uiImage: preview).resizable().scaledToFill()
                        } else {
                            Image(systemName: "doc.richtext").font(.title2).foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, maxHeight: .infinity).background(Theme.box)
                        }
                    }
                    .frame(width: 54, height: 96)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.line))
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(summary).fontWeight(.medium)
                Text("Scanned on this iPhone. Nothing is sent until you tap “Sort in” in Matterbee — about 4 cents.")
                    .font(.footnote).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }

    private var summary: String {
        let pictures = model.pieces.filter { $0.preview != nil }.count, documents = model.pieces.count - pictures
        return [pictures == 0 ? nil : "\(pictures) \(pictures == 1 ? "picture" : "pictures")",
                documents == 0 ? nil : "\(documents) \(documents == 1 ? "PDF" : "PDFs")"].compactMap { $0 }.joined(separator: " · ")
    }

    private func row(key: String?, title: String, sub: String?, bee: Bool) -> some View {
        Button { model.chosen = key } label: {
            HStack(spacing: 12) {
                Group {
                    if bee { BeeMark(size: 13).tight().foregroundStyle(Theme.beeMark) } else { Color.clear }
                }
                .frame(width: 24, height: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).foregroundStyle(.primary).multilineTextAlignment(.leading)
                    if let sub { Text(sub).font(.caption).foregroundStyle(.secondary) }
                }
                Spacer(minLength: 8)
                Image(systemName: "checkmark").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.gold)
                    .opacity(model.chosen == key ? 1 : 0)
            }
            .padding(.horizontal, 14).padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(model.chosen == key ? .isSelected : [])
    }

    private func added(_ name: String) -> some View {
        VStack(spacing: 10) {
            BeeMark(size: 28, livesNowAndThen: false).tight().foregroundStyle(Theme.beeMark)
            Text(name.isEmpty ? "In Matterbee" : "In “\(name)”").font(.headline).multilineTextAlignment(.center)
            Text("Open Matterbee to see what it says and sort it in.").font(.subheadline).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
