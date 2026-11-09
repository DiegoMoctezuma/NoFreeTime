import AVFoundation

/// Lectura en voz alta en español de México (🔊 de las tarjetas).
@MainActor
enum Voz {
    private static let sintetizador = AVSpeechSynthesizer()

    static func decir(_ texto: String) {
        if sintetizador.isSpeaking { sintetizador.stopSpeaking(at: .immediate) }
        let frase = AVSpeechUtterance(string: texto)
        frase.voice = AVSpeechSynthesisVoice(language: "es-MX") ?? AVSpeechSynthesisVoice(language: "es-ES")
        frase.rate = AVSpeechUtteranceDefaultSpeechRate * 0.9
        sintetizador.speak(frase)
    }

    static func callar() {
        sintetizador.stopSpeaking(at: .immediate)
    }
}
