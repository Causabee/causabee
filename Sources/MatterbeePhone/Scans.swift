import MatterCore
import PDFKit
import SwiftData
import SwiftUI
import UniformTypeIdentifiers
import VisionKit

/// A paper document — a letter, a contract, a bill — scanned with the camera or picked as a file,
/// kept on this iPhone where Files shows it (On My iPhone › Matterbee), and sorted into the matter
/// the way the paperclip sorts one in: read here, sent pseudonymised only on "Sort in", taken in
/// with a tap. What it says goes to every device; the file stays on this iPhone. Nothing goes
/// into the mailbox.
enum Scans {
    /// Pages from the camera, as one PDF.
    static func pdf(of pages: [UIImage]) -> Data? {
        let document = PDFDocument()
        for (index, image) in pages.enumerated() {
            if let page = PDFPage(image: image) { document.insert(page, at: index) }
        }
        return document.pageCount == 0 ? nil : document.dataRepresentation()
    }
}

/// Naming the document and keeping it.
struct ScanSheet: View {
    let matter: Matter
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(Navigation.self) private var navigation
    @Query private var profiles: [Profile]
    @State private var title = ""
    @State private var file: (name: String, data: Data, isPDF: Bool)?
    @State private var scanning = false
    @State private var picking = false
    @State private var failure: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if let file {
                        Label("\(file.name) · \(ByteCountFormatter.string(fromByteCount: Int64(file.data.count), countStyle: .file))",
                              systemImage: file.isPDF ? "doc.richtext" : "photo")
                    }
                    if VNDocumentCameraViewController.isSupported {
                        Button(file == nil ? "Scan with the camera" : "Scan again", systemImage: "doc.viewfinder") { scanning = true }
                    }
                    Button(file == nil ? "Choose a PDF or a photo" : "Choose another file", systemImage: "folder") { picking = true }
                } header: {
                    Text("The document")
                }
                Section {
                    TextField("For example: Tax assessment, rental contract, invoice", text: $title)
                } header: {
                    Text("What is it?")
                } footer: {
                    Text("Saved on this iPhone, in \(PhoneShots.place), under this name. Then scanned here and sorted into “\(matter.name)” when you tap “Sort in” — about 4 cents — as with the paperclip. Its tasks and dates go to all your devices; the file stays on this iPhone.")
                }
                if let failure { Text(failure).foregroundStyle(Theme.warning) }
            }
            .navigationTitle("Add a document")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add", action: add).disabled(file == nil)
                }
            }
            .fullScreenCover(isPresented: $scanning) {
                DocumentCamera { pages in
                    scanning = false
                    if let data = Scans.pdf(of: pages) { file = (name: "Scan \(MatterStatus.day(Date())).pdf", data: data, isPDF: true) }
                } cancel: { scanning = false }
                .ignoresSafeArea()
            }
            .fileImporter(isPresented: $picking, allowedContentTypes: [.pdf, .image]) { result in
                guard case .success(let url) = result else { return }
                let access = url.startAccessingSecurityScopedResource()
                defer { if access { url.stopAccessingSecurityScopedResource() } }
                guard let data = try? Data(contentsOf: url) else { failure = "The file cannot be read."; return }
                file = (name: url.lastPathComponent, data: data, isPDF: url.pathExtension.lowercased() == "pdf")
            }
        }
    }

    /// Named by what it is, when it was said — "Tax assessment.pdf" — else by its own name.
    private var keptName: String? {
        guard let file else { return nil }
        let named = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !named.isEmpty else { return file.name }
        let ending = (file.name as NSString).pathExtension
        return named + (ending.isEmpty ? "" : ".\(ending)")
    }

    /// Kept, then into the assistant, where it is read and waits for "Sort in".
    private func add() {
        guard let file, let name = keptName else { return }
        guard let kept = PhoneShots.shared.keep(file.data, named: name) else {
            failure = "It could not be saved on this iPhone. Is there space left?"
            return
        }
        PhoneShots.shared.bring(kept, matter: matter.persistentModelID, context: context, owner: profiles.first?.names.first)
        dismiss()
        navigation.showsAssistant = true
    }
}

/// The system's document camera: finds the page's edges, straightens it, and hands back the pages.
struct DocumentCamera: UIViewControllerRepresentable {
    let done: ([UIImage]) -> Void
    let cancel: () -> Void

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let camera = VNDocumentCameraViewController()
        camera.delegate = context.coordinator
        return camera
    }

    func updateUIViewController(_ controller: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(done: done, cancel: cancel) }

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let done: ([UIImage]) -> Void
        let cancel: () -> Void

        init(done: @escaping ([UIImage]) -> Void, cancel: @escaping () -> Void) {
            self.done = done
            self.cancel = cancel
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            done((0..<scan.pageCount).map { scan.imageOfPage(at: $0) })
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) { cancel() }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) { cancel() }
    }
}
