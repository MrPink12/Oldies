// SpeechSynthesizer.swift
// Oldies
//
// Swedish text-to-speech using AVSpeechSynthesizer.
// The "Alva" voice (sv-SE) sounds natural and is built into iOS.
// Audio plays through the glasses' open-ear speakers automatically
// when they are the active audio output.

import Foundation
import AVFoundation
import SwiftUI

@MainActor
final class SpeechSynthesizer: ObservableObject {

    @Published var isSpeaking = false

    private let synthesizer = AVSpeechSynthesizer()
    private var delegate: SynthDelegate?

    init() {
        let d = SynthDelegate(owner: self)
        synthesizer.delegate = d
        delegate = d
    }

    // MARK: – Speak

    func speak(_ text: String, voice: String = "sv-SE") {
        guard !text.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        // Stop any ongoing speech
        if synthesizer.isSpeaking { synthesizer.stopSpeaking(at: .word) }

        let utterance = AVSpeechUtterance(string: text)

        // Prefer the Alva voice (high-quality Swedish TTS)
        if let alva = AVSpeechSynthesisVoice(identifier: "com.apple.voice.enhanced.sv-SE.Alva") {
            utterance.voice = alva
        } else {
            utterance.voice = AVSpeechSynthesisVoice(language: voice)
        }

        utterance.rate           = 0.5   // slightly slower = clearer
        utterance.pitchMultiplier = 1.0
        utterance.volume          = 1.0

        // Route audio to glasses speaker when connected
        configureAudioSession()

        isSpeaking = true
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
    }

    // MARK: – Audio session

    private func configureAudioSession() {
        try? AVAudioSession.sharedInstance()
            .setCategory(.playback, mode: .default, options: [.allowBluetooth, .allowBluetoothA2DP])
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    // MARK: – Delegate

    private final class SynthDelegate: NSObject, AVSpeechSynthesizerDelegate {
        weak var owner: SpeechSynthesizer?
        init(owner: SpeechSynthesizer) { self.owner = owner }

        func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
            Task { @MainActor [weak self] in
                self?.owner?.isSpeaking = false
            }
        }
    }
}
