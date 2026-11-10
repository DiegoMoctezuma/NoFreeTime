import AVFAudio
import Foundation
import Observation
import Speech

/// Responder hablando en la entrevista. El micrófono solo se abre cuando la persona toca el botón.
/// Graba a un archivo y lo transcribe en español de México (tomado del prototipo MiMi anterior).
@MainActor @Observable
final class Dictado {
    var texto = ""
    var escuchando = false
    var transcribiendo = false
    var error: String?

    private var recognizer: SFSpeechRecognizer? = SFSpeechRecognizer(locale: Locale(identifier: "es-MX"))
    private var grabadora: AVAudioRecorder?
    private var tarea: SFSpeechRecognitionTask?
    private var archivo: URL?
    private var sesionAnterior: (categoria: AVAudioSession.Category, modo: AVAudioSession.Mode, opciones: AVAudioSession.CategoryOptions)?

    func alternar() async {
        if escuchando {
            terminar()
            return
        }
        guard await autorizar() else { return }
        do {
            try empezar()
        } catch {
            detener()
            self.error = "No pude abrir el micrófono. Puedes escribir tu respuesta."
        }
    }

    func detener() {
        grabadora?.stop()
        grabadora = nil
        tarea?.cancel()
        tarea = nil
        borrarGrabacion()
        escuchando = false
        transcribiendo = false
        liberarMicrofono()
    }

    private func autorizar() async -> Bool {
        let voz: Bool = await withCheckedContinuation { continuacion in
            SFSpeechRecognizer.requestAuthorization { @Sendable estado in
                continuacion.resume(returning: estado == .authorized)
            }
        }
        guard voz else {
            error = "Para responder hablando, permite el reconocimiento de voz en Ajustes."
            return false
        }
        guard await AVAudioApplication.requestRecordPermission() else {
            error = "Para responder hablando, permite el micrófono en Ajustes."
            return false
        }
        return true
    }

    private func empezar() throws {
        tarea?.cancel()
        let sesion = AVAudioSession.sharedInstance()
        sesionAnterior = (sesion.category, sesion.mode, sesion.categoryOptions)
        // Mantiene disponible la salida de audio para VoiceOver mientras se dicta.
        try sesion.setCategory(.playAndRecord, mode: .default, options: [.mixWithOthers, .defaultToSpeaker])
        try sesion.setActive(true)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("mimi-voz-\(UUID().uuidString).m4a")
        archivo = url
        let ajustes: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        let g = try AVAudioRecorder(url: url, settings: ajustes)
        g.prepareToRecord()
        guard g.record() else { throw NSError(domain: "MiMi", code: 2) }
        grabadora = g
        texto = ""
        error = nil
        escuchando = true
    }

    private func terminar() {
        guard let url = archivo else { return }
        grabadora?.stop()
        grabadora = nil
        escuchando = false
        liberarMicrofono()
        guard let recognizer, recognizer.isAvailable else {
            borrarGrabacion()
            error = "El reconocimiento de voz no está disponible ahora. Puedes escribir tu respuesta."
            return
        }
        transcribiendo = true
        let pedido = SFSpeechURLRecognitionRequest(url: url)
        pedido.shouldReportPartialResults = true
        pedido.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
        tarea = recognizer.recognitionTask(with: pedido) { @Sendable [weak self] resultado, fallo in
            let leido = resultado?.bestTranscription.formattedString
            let termino = fallo != nil || resultado?.isFinal == true
            let fallido = fallo != nil
            Task { @MainActor [weak self] in
                guard let self, self.archivo == url else { return }
                if let leido { self.texto = leido }
                if termino {
                    self.transcribiendo = false
                    if fallido && self.texto.isEmpty {
                        self.error = "No te entendí. Intenta de nuevo o escribe tu respuesta."
                    }
                    self.tarea = nil
                    self.borrarGrabacion()
                }
            }
        }
    }

    private func liberarMicrofono() {
        guard let anterior = sesionAnterior else { return }
        sesionAnterior = nil
        let sesion = AVAudioSession.sharedInstance()
        try? sesion.setActive(false, options: .notifyOthersOnDeactivation)
        try? sesion.setCategory(anterior.categoria, mode: anterior.modo, options: anterior.opciones)
    }

    private func borrarGrabacion() {
        guard let url = archivo else { return }
        archivo = nil
        try? FileManager.default.removeItem(at: url)
    }
}
