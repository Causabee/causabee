import AVFoundation
import Foundation
import Observation
@preconcurrency import WhisperKit

/// Speech written down on the device: Whisper's multilingual `small` model through WhisperKit, as
/// in Utterclip. The model is not in the app — 216 MB, loaded once when the owner says so — and
/// no sound leaves the device: what comes out is text, and the recording is deleted.
@Observable
@MainActor
public final class Transcriber {
    public static let shared = Transcriber()

    public enum State: Equatable {
        /// The model is not on this device yet.
        case missing
        /// Being loaded from the net: how far, 0…1.
        case downloading(Double)
        /// On the device, not in memory yet.
        case cold
        case warming
        case ready
        case failed(String)
    }

    public private(set) var state: State
    private var engine: Engine?

    static let variant = "small_216MB"
    /// The size said before the download.
    public static let megabytes = 216
    private static let repo = "argmaxinc/whisperkit-coreml"

    /// WhisperKit, kept off the main actor: it is loaded and asked from here only.
    private final class Engine: @unchecked Sendable {
        let kit: WhisperKit

        init(model: String, base: URL, repo: String, folder: String) async throws {
            let config = WhisperKitConfig(model: model, downloadBase: base, modelRepo: repo, modelFolder: folder,
                                          verbose: false, logLevel: .error, prewarm: true, load: true, download: false)
            kit = try await WhisperKit(config)
        }

        func words(in path: String) async throws -> String {
            // Said outright: without it the decoder starts in English, and German comes out translated.
            var options = DecodingOptions()
            options.task = .transcribe
            options.detectLanguage = true
            let results = try await kit.transcribe(audioPath: path, decodeOptions: options)
            // "[BLANK_AUDIO]", "[MUSIC]": what Whisper says of sound that is no speech.
            return results.map(\.text).joined()
                .replacing(#/\[[A-Z_ ]+\]/#, with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        static func fetch(variant: String, base: URL, repo: String, progress: @escaping @Sendable (Double) -> Void) async throws -> URL {
            try await WhisperKit.download(variant: variant, downloadBase: base, from: repo) { progress($0.fractionCompleted) }
        }
    }

    /// Application Support, not Documents: nothing the owner should see in Files, and not in backups.
    private static var base: URL {
        let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Causabee/speech", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    private static var modelFolder: URL {
        base.appendingPathComponent("models/\(repo)/openai_whisper-\(variant)", isDirectory: true)
    }

    /// Written when a download ended whole: a folder alone may be half of one.
    private static var marker: URL { modelFolder.appendingPathComponent(".complete") }

    private init() {
        state = FileManager.default.fileExists(atPath: Self.marker.path) ? .cold : .missing
    }

    /// Loads the model from the net, once, saying how far it is. Then it is warmed up.
    public func download() async {
        switch state {
        case .missing, .failed: break
        default: return
        }
        state = .downloading(0)
        do {
            let folder = try await Engine.fetch(variant: Self.variant, base: Self.base, repo: Self.repo) { done in
                Task { @MainActor in
                    if case .downloading = Transcriber.shared.state { Transcriber.shared.state = .downloading(done) }
                }
            }
            FileManager.default.createFile(atPath: folder.appendingPathComponent(".complete").path, contents: nil)
            var base = Self.base
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            try? base.setResourceValues(values)
            state = .cold
            await warmUp()
        } catch {
            state = .failed("The speech model could not be loaded: \(error.localizedDescription)")
        }
    }

    /// The model into memory, once: the first words then do not wait for it.
    public func warmUp() async {
        guard state == .cold else { return }
        state = .warming
        do {
            engine = try await Engine(model: Self.variant, base: Self.base, repo: Self.repo, folder: Self.modelFolder.path)
            state = .ready
        } catch {
            state = .failed("The speech model could not be started: \(String(describing: error))")
        }
    }

    /// The words in a recording, in the language they were said in. The recording is deleted.
    public func words(in recording: URL) async throws -> String {
        defer { try? FileManager.default.removeItem(at: recording) }
        if state == .cold { await warmUp() }
        while state == .warming { try await Task.sleep(for: .milliseconds(120)) }
        guard state == .ready, let engine else { throw VoiceError.noModel }
        return try await engine.words(in: recording.path)
    }
}

public enum VoiceError: LocalizedError {
    case noMicrophone, noModel, heardNothing

    public var errorDescription: String? {
        switch self {
        case .noMicrophone: "Causabee may not use the microphone. Allow it in the system's privacy settings."
        case .noModel: "The speech model is not ready."
        case .heardNothing: "Nothing was heard."
        }
    }
}

/// The microphone, recorded as Whisper wants it: 16 kHz, one channel. Says how loud it is, for the
/// waveform, and ends by itself — after a silence once something was said, or when it gets long.
@Observable
@MainActor
public final class VoiceRecorder {
    public private(set) var isRecording = false
    public private(set) var startedAt: Date?
    /// How loud, 0…1, the newest last: the waveform's bars.
    public private(set) var levels: [Float] = []
    /// Called when the recording ended by itself.
    @ObservationIgnored public var ended: (@MainActor () -> Void)?

    private var recorder: AVAudioRecorder?
    private var meter: Task<Void, Never>?
    private var lastSpeech: Date?
    private var heardSpeech = false

    public static let longest: TimeInterval = 120
    private static let silence: TimeInterval = 3
    private static let window = 46

    public init() {}

    /// The recording as it looks while someone speaks, without a microphone: for a picture taken in
    /// the simulator, which has none. Nothing is recorded.
    public func stage(levels: [Float], secondsAgo: TimeInterval) {
        self.levels = levels
        startedAt = Date().addingTimeInterval(-secondsAgo)
        isRecording = true
    }

    public func start() async throws {
        #if os(macOS)
        guard await AVCaptureDevice.requestAccess(for: .audio) else { throw VoiceError.noMicrophone }
        #else
        guard await AVAudioApplication.requestRecordPermission() else { throw VoiceError.noMicrophone }
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .default)
        try session.setActive(true)
        #endif
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("causabee-voice-\(UUID().uuidString).wav")
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM), AVSampleRateKey: 16_000, AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16, AVLinearPCMIsFloatKey: false, AVLinearPCMIsBigEndianKey: false,
        ]
        let recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder.isMeteringEnabled = true
        guard recorder.record() else { throw VoiceError.noMicrophone }
        self.recorder = recorder
        levels = []
        heardSpeech = false
        lastSpeech = nil
        startedAt = Date()
        isRecording = true
        meter = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(70))
                guard let self, self.isRecording, let recorder = self.recorder else { return }
                recorder.updateMeters()
                let power = recorder.averagePower(forChannel: 0)
                // −50 dB, a quiet room, to 0; −10 dB, a loud voice, to 1.
                self.levels.append(max(0, min(1, (power + 50) / 40)))
                if self.levels.count > Self.window { self.levels.removeFirst(self.levels.count - Self.window) }
                let now = Date()
                if power > -38 { self.heardSpeech = true; self.lastSpeech = now }
                let quiet = self.heardSpeech && now.timeIntervalSince(self.lastSpeech ?? now) > Self.silence
                let long = now.timeIntervalSince(self.startedAt ?? now) > Self.longest
                if quiet || long { self.ended?(); return }
            }
        }
    }

    /// Ends the recording: the file, or nil when nothing was said into it.
    public func stop() -> URL? {
        meter?.cancel()
        meter = nil
        guard let recorder else { return nil }
        recorder.stop()
        self.recorder = nil
        isRecording = false
        startedAt = nil
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        #endif
        guard heardSpeech else {
            try? FileManager.default.removeItem(at: recorder.url)
            return nil
        }
        return recorder.url
    }

    /// Throws the recording away.
    public func cancel() {
        if let url = stop() { try? FileManager.default.removeItem(at: url) }
    }
}
