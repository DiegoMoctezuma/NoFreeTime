import AppIntents
import SwiftData

/// "Ya me la tomé" desde la alarma (botón secundario de AlarmKit) o la notificación (PRD A5).
/// Crea el `RegistroToma` y cancela las repeticiones. Solo corre por un toque de la persona.
struct YaMeLaTomeIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Ya me la tomé"
    static let isDiscoverable = false
    /// Plan B (A5): si el botón de la alarma no ejecutara el intent en segundo plano,
    /// cambiar a `true` abre la app en Tu día con la toma resaltada.
    static let openAppWhenRun = false

    @Parameter(title: "Toma") var idToma: String

    init() {}

    init(idToma: String) {
        self.idToma = idToma
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        try YaMeLaTomeIntent.registrar(idToma: idToma)
        await ServicioAvisosSistema.compartido.cancelarRepeticiones(idToma: idToma)
        Navegacion.compartida.tomaResaltada = idToma
        return .result()
    }

    /// Registro compartido con la acción de la notificación.
    @MainActor
    static func registrar(idToma: String) throws {
        try Registro.marcarTomada(idToma: idToma, contexto: Almacen.contenedor.mainContext)
    }
}
