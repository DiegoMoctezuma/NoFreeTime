import Observation

/// Estado de navegación compartido con intents y notificaciones (CONTRATOS §7).
@MainActor @Observable
final class Navegacion {
    static let compartida = Navegacion()

    /// Toma a resaltar en Tu día (plan B de la alarma y acción de la notificación).
    var tomaResaltada: String?
}
