import Observation

/// Estado de navegación compartido con intents y notificaciones (CONTRATOS §7).
@MainActor @Observable
final class Navegacion {
    static let compartida = Navegacion()

    /// Toma a resaltar en Tu día (plan B de la alarma y acción de la notificación).
    var tomaResaltada: String?

    /// Pestaña visible. Hoy → "Agregar" desde el botón de Tu día vacío.
    var pestana: Pestana = .hoy
}
