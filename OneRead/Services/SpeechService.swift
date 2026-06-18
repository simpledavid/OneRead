import AVFoundation
import Foundation

@MainActor
final class SpeechService: NSObject, ObservableObject {
    @Published private(set) var speakingWord: String?
    @Published private(set) var speakingText: String?

    private let synthesizer = AVSpeechSynthesizer()

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(_ text: String) {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            return
        }

        if speakingText == trimmedText, synthesizer.isSpeaking {
            stop()
            return
        }

        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        let utterance = AVSpeechUtterance(string: trimmedText)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.45
        utterance.pitchMultiplier = 1.0
        speakingWord = trimmedText
        speakingText = trimmedText
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        speakingWord = nil
        speakingText = nil
    }

    func isSpeaking(_ text: String) -> Bool {
        speakingText == text.trimmingCharacters(in: .whitespacesAndNewlines) && synthesizer.isSpeaking
    }
}

extension SpeechService: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didFinish utterance: AVSpeechUtterance
    ) {
        Task { @MainActor in
            speakingWord = nil
            speakingText = nil
        }
    }

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didCancel utterance: AVSpeechUtterance
    ) {
        Task { @MainActor in
            speakingWord = nil
            speakingText = nil
        }
    }
}
