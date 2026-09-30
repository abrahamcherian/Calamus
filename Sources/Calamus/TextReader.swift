import AppKit

/// A small singleton wrapper around NSSpeechSynthesizer for the Read Aloud feature (the status
/// bar's speaker button, or Edit > Read Aloud). One session at a time, app-wide - mirrors how
/// `VoiceTranscriber` is a single shared listener rather than one per editor tab. Speaks using
/// the voice and rate chosen in Preferences > Voice (or the system defaults if left unset), and
/// reports back through `onFinish` whenever speaking stops, whether it ran to the end or was
/// interrupted by `stop()`, so the caller can keep its Read/Stop button in sync.
final class TextReader: NSObject {
    static let shared = TextReader()

    private let synthesizer = NSSpeechSynthesizer()
    private(set) var isSpeaking = false

    /// Called on the main thread once, the next time speaking stops for any reason. Callers set
    /// this right before calling `speak(_:)`.
    var onFinish: (() -> Void)?

    private override init() {
        super.init()
        synthesizer.delegate = self
    }

    /// Starts speaking `text` using the current Preferences > Voice settings. Does nothing if
    /// already speaking (callers should `stop()` first, which is what the status bar's toggle
    /// button and the Edit menu item both do).
    func speak(_ text: String) {
        guard !isSpeaking, !text.isEmpty else { return }
        let prefs = Preferences.shared
        // NSSpeechSynthesizer.VoiceName isn't a plain String on this SDK (it's its own
        // RawRepresentable type); Preferences stores the identifier as a plain String, so it's
        // rewrapped here. RawRepresentable's own init is always failable (init?(rawValue:)).
        // Also, on this SDK `voice` isn't a settable property (the compiler treats a bare
        // `.voice` as a getter-only method reference) - setting goes through the classic
        // `setVoice(_:)` method instead, which reports success/failure as a Bool; nil means
        // "use the system default voice", per Apple's documented behavior. The Bool is
        // intentionally discarded - an invalid saved identifier just falls back silently to
        // whatever voice was already in effect, rather than failing Read Aloud outright.
        _ = synthesizer.setVoice(prefs.readAloudVoiceIdentifier.isEmpty
            ? nil
            : NSSpeechSynthesizer.VoiceName(rawValue: prefs.readAloudVoiceIdentifier))
        synthesizer.rate = Float(prefs.readAloudRate)
        isSpeaking = true
        synthesizer.startSpeaking(text)
    }

    /// Stops speaking immediately. Safe to call whether or not speaking is in progress.
    func stop() {
        guard isSpeaking else { return }
        isSpeaking = false
        synthesizer.stopSpeaking()
    }
}

extension TextReader: NSSpeechSynthesizerDelegate {
    func speechSynthesizer(_ sender: NSSpeechSynthesizer, didFinishSpeaking finishedSpeaking: Bool) {
        isSpeaking = false
        DispatchQueue.main.async { [weak self] in self?.onFinish?() }
    }
}
