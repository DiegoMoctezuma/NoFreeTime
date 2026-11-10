import AVFoundation

/// Lectura en voz alta en español de México (🔊 de las tarjetas).
///
/// Usa la sesión de audio de la app en modo reproducción: así se escucha aunque el iPhone
/// esté en silencio (la persona tocó la bocina a propósito) y baja el volumen de la música mientras habla.
@MainActor
enum Voz {
    private static var sintetizador: AVSpeechSynthesizer?
    private static let observador = ObservadorVoz()

    static func decir(_ texto: String) {
        let texto = texto.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !texto.isEmpty else { return }
        callar()
        prepararSesion()
        // Un sintetizador nuevo por frase: después de stopSpeaking, iOS a veces ignora el siguiente speak.
        let nuevo = AVSpeechSynthesizer()
        nuevo.delegate = observador
        sintetizador = nuevo
        let frase = AVSpeechUtterance(string: texto)
        frase.voice = AVSpeechSynthesisVoice(language: "es-MX") ?? AVSpeechSynthesisVoice(language: "es-ES")
        frase.rate = AVSpeechUtteranceDefaultSpeechRate * 0.9
        nuevo.speak(frase)
    }

    static func callar() {
        guard let sintetizador else { return }
        sintetizador.delegate = nil
        sintetizador.stopSpeaking(at: .immediate)
        self.sintetizador = nil
        liberarSesion()
    }

    /// Lo llama el observador cuando termina de hablar.
    fileprivate static func termino(_ quien: ObjectIdentifier) {
        guard let sintetizador, ObjectIdentifier(sintetizador) == quien else { return }
        self.sintetizador = nil
        liberarSesion()
    }

    private static var dictando: Bool {
        AVAudioSession.sharedInstance().category == .playAndRecord
    }

    private static func prepararSesion() {
        // Si se está dictando, no se toca la sesión del micrófono; la voz sale por la que ya está activa.
        guard !dictando else { return }
        let sesion = AVAudioSession.sharedInstance()
        try? sesion.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? sesion.setActive(true)
    }

    private static func liberarSesion() {
        guard !dictando else { return }
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

/// Avisa a `Voz` cuando una frase termina, para devolver el volumen a la música.
private final class ObservadorVoz: NSObject, AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        let id = ObjectIdentifier(synthesizer)
        Task { @MainActor in Voz.termino(id) }
    }
}
