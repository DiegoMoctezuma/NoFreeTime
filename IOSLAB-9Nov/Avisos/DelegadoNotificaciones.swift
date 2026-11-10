import Foundation
import UserNotifications

/// Maneja la acción "Ya me la tomé" de la notificación y el toque que abre la app.
/// `configurar()` se llama al arrancar la app (MyApp), antes de que llegue cualquier respuesta.
final class DelegadoNotificaciones: NSObject, UNUserNotificationCenterDelegate {
    static let compartido = DelegadoNotificaciones()

    @MainActor
    static func configurar() {
        let centro = UNUserNotificationCenter.current()
        centro.delegate = compartido
        let categorias: Set<UNNotificationCategory> = [
            categoria(Identificadores.categoriaToma, accion: Identificadores.accionYaMeLaTome, titulo: "Ya me la tomé"),
            categoria(Identificadores.categoriaAplicacion, accion: Identificadores.accionYaMeLaAplique, titulo: TipoAccionPlan.aplicacion.accionRegistro),
            categoria(Identificadores.categoriaCuidado, accion: Identificadores.accionYaLoHice, titulo: TipoAccionPlan.cuidado.accionRegistro)
        ]
        centro.setNotificationCategories(categorias)
    }

    private static func categoria(_ id: String, accion: String, titulo: String) -> UNNotificationCategory {
        let boton = UNNotificationAction(identifier: accion, title: titulo, options: [],
                                         icon: UNNotificationActionIcon(systemImageName: "checkmark.circle.fill"))
        return UNNotificationCategory(identifier: id, actions: [boton], intentIdentifiers: [], options: [])
    }

    /// Con la app abierta, el recordatorio también se muestra.
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }

    /// Descartar la notificación NO cuenta como toma (RF-06): solo la acción explícita registra.
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            didReceive response: UNNotificationResponse) async {
        guard let idToma = response.notification.request.content.userInfo["idToma"] as? String else { return }
        let accion = response.actionIdentifier
        let registrado = await MainActor.run {
            switch accion {
            case Identificadores.accionYaMeLaTome, Identificadores.accionYaMeLaAplique, Identificadores.accionYaLoHice:
                return (try? YaMeLaTomeIntent.registrar(idToma: idToma)) != nil
            case UNNotificationDefaultActionIdentifier:
                Navegacion.compartida.tomaResaltada = idToma
            default:
                break
            }
            return false
        }
        if registrado {
            await ServicioAvisosSistema.compartido.cancelarRepeticiones(idToma: idToma)
        }
    }
}
