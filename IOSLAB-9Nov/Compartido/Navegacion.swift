import Observation

/// Estado de navegación compartido con intents y notificaciones (CONTRATOS §7).
@MainActor @Observable
final class Navegacion {
    static let compartida = Navegacion()

    /// Toma a resaltar en Tu día (plan B de la alarma y acción de la notificación).
    var tomaResaltada: String?

    /// Pestaña visible. Hoy → "Agregar" desde el botón de Tu día vacío.
    var pestana: Pestana = .hoy

    /// MiMi pidió abrir un paso de Agregar (la cámara de la receta o de la caja).
    var abrirAlta: PasoAlta?
    /// Paso visible dentro de Agregar (nil en el inicio de la pestaña). En esos pasos el globito se oculta
    /// para no tapar los botones de abajo.
    var pasoAlta: PasoAlta?
    /// La barra de "Deshacer" está visible abajo; el globito se esconde para no taparla.
    var deshacerVisible = false
}
