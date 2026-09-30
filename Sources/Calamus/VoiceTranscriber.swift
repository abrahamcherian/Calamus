import Foundation
import AVFoundation
import Speech

/// A small singleton wrapper around Speech + AVAudioEngine for Edit > Start Voice to Text.
/// Listens continuously until `stop()` is called: Apple's speech recognizer ends its own
/// "segment" after it detects a pause (even with partial results on), so each segment that
/// ends on its own immediately starts another - the microphone itself keeps running the whole
/// time - which is what makes it feel like it's "still listening" rather than needing Start
/// pressed again after every pause. Keeps permission prompts, engine setup/teardown, and
/// transcription callbacks in one place so `EditorViewController` only has to call
/// `start`/`stop` and handle text updates.
final class VoiceTranscriber {
    static let shared = VoiceTranscriber()

    private(set) var isRunning = false
    private var stopRequested = false

    /// Called on the main queue with the latest transcription for the current segment (replaces
    /// the previous update for that segment - callers should replace, not append, the text
    /// they're tracking for it).
    var onUpdate: ((String) -> Void)?
    /// Called on the main queue when one segment ends and a new one is about to begin (listening
    /// continues). Callers should "commit" whatever text the just-ended segment inserted, so the
    /// next segment's updates start fresh instead of overwriting it.
    var onSegmentEnd: (() -> Void)?
    /// Called on the main queue when listening stops for good - either `stop()` was called, or
    /// recognition couldn't continue (no recognizer available, engine error).
    var onStop: (() -> Void)?

    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    private init() {}

    /// Requests Speech Recognition and Microphone permission (if not already granted), then
    /// starts listening. `completion` is called once, on the main queue: with `nil` on success,
    /// or a user-facing message on failure (permission denied, no recognizer available, engine
    /// couldn't start). Does nothing if a session is already running.
    func start(completion: @escaping (String?) -> Void) {
        guard !isRunning else { completion(nil); return }
        stopRequested = false
        SFSpeechRecognizer.requestAuthorization { [weak self] authStatus in
            DispatchQueue.main.async {
                guard let self = self else { return }
                guard authStatus == .authorized else {
                    completion("Voice to Text needs Speech Recognition access. Check System Settings \u{2192} Privacy & Security \u{2192} Speech Recognition.")
                    return
                }
                AVCaptureDevice.requestAccess(for: .audio) { granted in
                    DispatchQueue.main.async {
                        guard granted else {
                            completion("Voice to Text needs microphone access. Check System Settings \u{2192} Privacy & Security \u{2192} Microphone.")
                            return
                        }
                        self.startAudioEngine(completion: completion)
                    }
                }
            }
        }
    }

    /// Starts the microphone once per listening session. The tap always feeds whichever request
    /// is currently in `self.request`, so a fresh segment (a new request/task) can begin without
    /// ever stopping or reinstalling the tap - audio keeps flowing across segment boundaries.
    private func startAudioEngine(completion: @escaping (String?) -> Void) {
        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.request?.append(buffer)
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            inputNode.removeTap(onBus: 0)
            completion("Couldn't start the microphone: \(error.localizedDescription)")
            return
        }

        isRunning = true
        completion(nil)
        startSegment()
    }

    /// Starts one recognition segment against the already-running audio engine, using the
    /// language and on-device preference set in Preferences > Voice.
    private func startSegment() {
        let prefs = Preferences.shared
        // "" (System Default in Preferences) follows whatever language macOS is currently set
        // to; otherwise use the language chosen there.
        let locale = prefs.voiceRecognitionLocale.isEmpty ? Locale.current : Locale(identifier: prefs.voiceRecognitionLocale)
        guard let recognizer = SFSpeechRecognizer(locale: locale) ?? SFSpeechRecognizer(),
              recognizer.isAvailable else {
            finish()
            return
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.taskHint = .dictation
        if prefs.voiceRequiresOnDeviceRecognition, recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }
        self.request = request

        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self = self else { return }
            if let result = result {
                let text = result.bestTranscription.formattedString
                DispatchQueue.main.async { self.onUpdate?(text) }
            }
            if result?.isFinal == true || error != nil {
                DispatchQueue.main.async { self.segmentEnded() }
            }
        }
    }

    /// A segment ended on its own (the recognizer detected a pause) or with an error. If
    /// listening is still wanted, starts the next segment right away so it feels continuous;
    /// otherwise this is where listening actually winds down.
    private func segmentEnded() {
        task?.cancel()
        task = nil
        request = nil
        guard isRunning, !stopRequested else {
            finish()
            return
        }
        onSegmentEnd?()
        startSegment()
    }

    /// Stops listening for good. Safe to call whether or not a session is running.
    func stop() {
        guard isRunning else { return }
        stopRequested = true
        request?.endAudio()
        task?.cancel()
        finish()
    }

    private func finish() {
        guard isRunning else { return }
        isRunning = false
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        task?.cancel()
        task = nil
        request = nil
        onStop?()
    }
}
