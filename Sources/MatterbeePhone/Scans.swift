import MatterCore
import PDFKit
import SwiftUI
import UniformTypeIdentifiers
import VisionKit

/// A paper document — a letter, a contract, a bill — into the mail: scanned with the camera or picked as a file, and
/// put into the Matterbee label as a mail from the owner to the owner. It is kept there like any
/// attachment — no iCloud space — and the Mac's next "Get new mail" reads it and files it, its
/// tasks and dates too. Until then the matter shows it as on its way.
enum Scans {
    static let label = "Matterbee"
    private static let pendingKey = "scans.pending"

    struct Pending: Codable, Hashable {
        var matter: String
        var title: String
        var messageID: String
        var date: Date
    }

    static var pending: [Pending] {
        get { (try? JSONDecoder().decode([Pending].self, from: UserDefaults.standard.data(forKey: pendingKey) ?? Data())) ?? [] }
        set { UserDefaults.standard.set(try? JSONEncoder().encode(newValue), forKey: pendingKey) }
    }

    /// The scans of this matter the Mac has not read yet: one it has read is a mail of the matter.
    @MainActor
    static func waiting(in matter: Matter) -> [Pending] {
        let read = Set((matter.entries ?? []).map(\.messageID))
        let all = pending
        let left = all.filter { !read.contains($0.messageID) }
        if left.count != all.count { pending = left }
        return left.filter { $0.matter == matter.key }
    }

    /// Pages from the camera, as one PDF.
    static func pdf(of pages: [UIImage]) -> Data? {
        let document = PDFDocument()
        for (index, image) in pages.enumerated() {
            if let page = PDFPage(image: image) { document.insert(page, at: index) }
        }
        return document.pageCount == 0 ? nil : document.dataRepresentation()
    }
}

/// Naming the scan and putting it into the mail.
struct ScanSheet: View {
    let matter: Matter
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var file: (name: String, contentType: String, data: Data)?
    @State private var scanning = false
    @State private var picking = false
    @State private var sending = false
    @State private var failure: String?
    @State private var addsAccount = false

    private var account: MailAccount? { Keychain.accounts().first { !$0.usesGoogle } }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if let file {
                        Label("\(file.name) · \(ByteCountFormatter.string(fromByteCount: Int64(file.data.count), countStyle: .file))",
                              systemImage: file.contentType == "application/pdf" ? "doc.richtext" : "photo")
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
                    Text("It goes into your mail, under the label “\(Scans.label)”, as a mail from you to you — so every device opens it from there and it takes no iCloud space. Your Mac reads it with the next “Get new mail” and files it in “\(matter.name)”, with its tasks and dates.")
                }
                if let failure { Text(failure).foregroundStyle(Theme.warning) }
            }
            .navigationTitle("Add a document")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    if sending { ProgressView() } else {
                        Button("Put into mail", action: send).disabled(file == nil || title.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
            .fullScreenCover(isPresented: $scanning) {
                DocumentCamera { pages in
                    scanning = false
                    if let data = Scans.pdf(of: pages) { file = (name: fileName("pdf"), contentType: "application/pdf", data: data) }
                } cancel: { scanning = false }
                .ignoresSafeArea()
            }
            .fileImporter(isPresented: $picking, allowedContentTypes: [.pdf, .image]) { result in
                guard case .success(let url) = result else { return }
                let access = url.startAccessingSecurityScopedResource()
                defer { if access { url.stopAccessingSecurityScopedResource() } }
                guard let data = try? Data(contentsOf: url) else { failure = "The file cannot be read."; return }
                let type = UTType(filenameExtension: url.pathExtension)?.preferredMIMEType ?? "application/octet-stream"
                file = (name: url.lastPathComponent, contentType: type, data: data)
            }
            .sheet(isPresented: $addsAccount) { MailAccountSheet() }
        }
    }

    /// "Scan 2026-09-30.pdf", or the title, when there is one.
    private func fileName(_ ending: String) -> String {
        let base = title.trimmingCharacters(in: .whitespaces).isEmpty ? "Scan \(MatterStatus.day(Date()))" : title
        return base.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-") + "." + ending
    }

    private func send() {
        guard let file else { return }
        guard let account, let password = try? Keychain.password(for: account.user) else { addsAccount = true; return }
        let scan = ScanMessage(owner: account.user, title: title.trimmingCharacters(in: .whitespaces), matter: matter.name, file: file)
        let key = matter.key
        sending = true
        failure = nil
        Task {
            do {
                _ = try await ScanDoor.putScan(scan.data, label: Scans.label, account: account, password: password)
                Scans.pending.append(Scans.Pending(matter: key, title: scan.title, messageID: scan.messageID, date: scan.date))
                sending = false
                dismiss()
            } catch {
                sending = false
                failure = "\(error)"
            }
        }
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
