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
        let accion = UNNotificationAction(identifier: Identificadores.accionYaMeLaTome,
                                          title: "Ya me la tomé",
                                          options: [],
                                          icon: UNNotificationActionIcon(systemImageName: "checkmark.circle.fill"))
        let categoria = UNNotificationCategory(identifier: Identificadores.categoriaToma,
                                               actions: [accion],
                                               intentIdentifiers: [],
                                               options: [])
        centro.setNotificationCategories([categoria])
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
        await MainActor.run {
            switch accion {
            case Identificadores.accionYaMeLaTome:
                try? YaMeLaTomeIntent.registrar(idToma: idToma)
            case UNNotificationDefaultActionIdentifier:
                Navegacion.compartida.tomaResaltada = idToma
            default:
                break
            }
        }
        if accion == Identificadores.accionYaMeLaTome {
            await ServicioAvisosSistema.compartido.cancelarRepeticiones(idToma: idToma)
        }
    }
}
