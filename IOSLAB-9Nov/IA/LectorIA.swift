import Foundation
import CoreGraphics
import FoundationModels
import Observation

/// ¿Se puede leer con Foundation Models en este iPhone? (RF-02 "Sin Apple Intelligence").
enum DisponibilidadIA: Equatable {
    case disponible
    /// Motivo legible en español; la pantalla ofrece el camino "sin receta".
    case noDisponible(String)
}

/// Lector de receta y caja con Foundation Models, en el dispositivo (WP-01, CONTRATOS §6).
/// Devuelve propuestas; nunca escribe en SwiftData.
@MainActor @Observable
final class LectorIA {
    enum Fallo: LocalizedError {
        case noDisponible(String)
        case noPudoLeer

        var errorDescription: String? {
            switch self {
            case .noDisponible(let motivo): motivo
            case .noPudoLeer: "No pude leerla. ¿Otra foto o lo hacemos sin receta?"
            }
        }
    }

    /// Tiempo de la última lectura, de la foto a la propuesta (criterio ≤ 15 s).
    private(set) var ultimaDuracion: Duration?
    private(set) var leyendo = false

    static var disponibilidad: DisponibilidadIA {
        let modelo = SystemLanguageModel.default
        switch modelo.availability {
        case .available:
            guard modelo.capabilities.contains(.vision) else {
                return .noDisponible("Este iPhone no puede leer fotos con Apple Intelligence.")
            }
            return .disponible
        case .unavailable(.deviceNotEligible):
            return .noDisponible("Este iPhone no tiene Apple Intelligence.")
        case .unavailable(.appleIntelligenceNotEnabled):
            return .noDisponible("Apple Intelligence está apagado. Puedes activarlo en Ajustes.")
        case .unavailable(.modelNotReady):
            return .noDisponible("Apple Intelligence se está preparando. Intenta en unos minutos.")
        case .unavailable:
            return .noDisponible("Apple Intelligence no está disponible.")
        }
    }

    private static let instruccionesReceta = """
        Lees recetas médicas impresas en español de México y extraes, para cada medicamento, \
        lo que está escrito: nombre, concentración, dosis, frecuencia, momentos del día, duración e indicaciones.
        Reglas:
        - Copia solo lo que aparece en la receta. No inventes ni completes datos.
        - Si un dato no aparece o no se lee bien, déjalo vacío y agrega el nombre del campo a camposDudosos.
        - Si la receta dice "cada 8 horas", "cada 12 horas" o "cada 24 horas", llena cadaHoras y deja momentos vacío, \
        salvo que también diga con qué comida o a qué hora.
        - Si la imagen está borrosa, no tiene texto o no es una receta, responde legible = false y sin medicamentos.
        - No des consejos médicos.
        """

    private static let instruccionesCaja = """
        Lees la caja de un medicamento en español. Extrae el nombre de la sustancia activa (no la marca si \
        aparecen las dos), la concentración y cuántas tabletas o cápsulas trae. Copia solo lo que se ve; \
        si no se lee el nombre, responde legible = false.
        """

    /// Lee la receta de la foto. `legible = false` si no hay texto útil.
    /// `yaRegistrado` se calcula aquí comparando con el tratamiento (no lo decide el modelo).
    func leerReceta(_ imagen: CGImage, tratamiento: [Medicamento]) async throws -> (legible: Bool, indicaciones: [IndicacionRevisada]) {
        try verificarDisponible()
        leyendo = true
        defer { leyendo = false }
        let reloj = ContinuousClock()
        let inicio = reloj.now

        let sesion = LanguageModelSession(
            tools: [LeerTratamientoActivo(tratamiento: tratamiento)],
            instructions: Self.instruccionesReceta
        )
        let receta: RecetaPropuesta
        do {
            receta = try await sesion.respond(generating: RecetaPropuesta.self) {
                "Lee esta receta. Puedes consultar leerTratamientoActivo para ver lo que la persona ya toma."
                Attachment(imagen).label("receta")
            }.content
        } catch {
            ultimaDuracion = reloj.now - inicio
            throw traducir(error)
        }
        ultimaDuracion = reloj.now - inicio

        let validas = receta.medicamentos.filter { !$0.nombre.trimmingCharacters(in: .whitespaces).isEmpty }
        guard receta.legible, !validas.isEmpty else { return (false, []) }
        let indicaciones = validas.map { p in
            IndicacionRevisada(propuesta: p, yaRegistrado: tratamiento.contains { MapeoIndicacion.coincide(p, con: $0) })
        }
        return (true, indicaciones)
    }

    /// Lee la caja de un medicamento (RF-03).
    func leerCaja(_ imagen: CGImage) async throws -> CajaLeida {
        try verificarDisponible()
        leyendo = true
        defer { leyendo = false }
        let reloj = ContinuousClock()
        let inicio = reloj.now
        let sesion = LanguageModelSession(instructions: Self.instruccionesCaja)
        do {
            let caja = try await sesion.respond(generating: CajaLeida.self) {
                "Lee esta caja de medicamento."
                Attachment(imagen).label("caja")
            }.content
            ultimaDuracion = reloj.now - inicio
            if caja.nombre?.trimmingCharacters(in: .whitespaces).isEmpty ?? true {
                return CajaLeida(legible: false, concentracion: caja.concentracion, pastillas: caja.pastillas)
            }
            return caja
        } catch {
            ultimaDuracion = reloj.now - inicio
            throw traducir(error)
        }
    }

    private func verificarDisponible() throws {
        if case .noDisponible(let motivo) = Self.disponibilidad { throw Fallo.noDisponible(motivo) }
    }

    /// Errores del modelo → mensaje para la persona (camino "otra foto o sin receta").
    private func traducir(_ error: Error) -> Error {
        if let e = error as? LanguageModelError {
            switch e {
            case .unsupportedCapability, .unsupportedLanguageOrLocale:
                return Fallo.noDisponible("Apple Intelligence no puede leer esta foto en este iPhone.")
            default:
                return Fallo.noPudoLeer
            }
        }
        if error is SystemLanguageModel.Error {
            return Fallo.noDisponible("Apple Intelligence se está preparando. Intenta en unos minutos.")
        }
        return Fallo.noPudoLeer
    }
}
