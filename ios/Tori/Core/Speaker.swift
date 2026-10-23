import AVFoundation
import Observation

/// Japanese text-to-speech through the system voices (the web app uses the
/// browser's built-in voice the same way). Picks the highest-quality
/// installed ja-JP voice.
@MainActor @Observable
final class Speaker: NSObject, AVSpeechSynthesizerDelegate {
    private let synth = AVSpeechSynthesizer()
    private(set) var speakingText: String?

    /// Name of the voice in use, or nil when no ja-JP voice is installed.
    let voiceName: String?
    private let voice: AVSpeechSynthesisVoice?

    override init() {
        let candidates = AVSpeechSynthesisVoice.speechVoices().filter { $0.language == "ja-JP" }
        let best = candidates.max { $0.quality.rawValue < $1.quality.rawValue }
        voice = best ?? AVSpeechSynthesisVoice(language: "ja-JP")
        voiceName = best?.name
        super.init()
        synth.delegate = self
    }

    func speak(_ text: String) {
        guard !text.isEmpty else { return }
        if synth.isSpeaking { synth.stopSpeaking(at: .immediate) }
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.85
        speakingText = text
        synth.speak(utterance)
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in self.speakingText = nil }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in self.speakingText = nil }
    }
}
