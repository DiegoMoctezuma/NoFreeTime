import CoreGraphics
import Foundation
import Vision

/// Reconocimiento de texto con Vision, en el dispositivo y sin red.
/// Sirve para dos cosas: darle al modelo el texto exacto de la foto y, después,
/// comprobar en código que lo que propone el modelo sí está escrito ahí (HCAI: verificable).
nonisolated enum LectorTexto {
    /// Renglones reconocidos de arriba hacia abajo. Vacío si no hay texto.
    static func leer(_ imagen: CGImage) async -> String {
        await withCheckedContinuation { continuacion in
            DispatchQueue.global(qos: .userInitiated).async {
                let pedido = VNRecognizeTextRequest()
                pedido.recognitionLevel = .accurate
                pedido.usesLanguageCorrection = true
                pedido.recognitionLanguages = ["es-MX", "es-ES", "en-US"]
                do {
                    try VNImageRequestHandler(cgImage: imagen, orientation: .up, options: [:]).perform([pedido])
                    let renglones = (pedido.results ?? [])
                        .sorted { $0.boundingBox.minY > $1.boundingBox.minY }
                        .compactMap { $0.topCandidates(1).first?.string }
                    continuacion.resume(returning: renglones.joined(separator: "\n"))
                } catch {
                    continuacion.resume(returning: "")
                }
            }
        }
    }
}
