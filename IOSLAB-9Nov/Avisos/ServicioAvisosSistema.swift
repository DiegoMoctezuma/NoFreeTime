import Foundation
import SwiftUI
import AlarmKit
import ActivityKit
import SwiftData
import UserNotifications

/// Metadatos que viajan con cada alarma.
nonisolated struct MetadatosToma: AlarmMetadata {
    var idToma: String
    var repeticion: Int
}

/// Implementación de `ServicioAvisos` con AlarmKit (alarma) y UserNotifications (recordatorio).
@MainActor
final class ServicioAvisosSistema: ServicioAvisos {
    static let compartido = ServicioAvisosSistema()

    private let alarmas = AlarmManager.shared
    private let centro = UNUserNotificationCenter.current()

    /// Registro local de alarmas programadas: UUID de alarma → idToma de la notificación.
    /// AlarmKit no deja leer los metadatos de una alarma, así que se guarda aquí para poder cancelar por medicamento.
    private let claveRegistro = "avisos.alarmasProgramadas"
    private var registro: [String: String] {
        get { UserDefaults.standard.dictionary(forKey: claveRegistro) as? [String: String] ?? [:] }
        set { UserDefaults.standard.set(newValue, forKey: claveRegistro) }
    }

    // MARK: ServicioAvisos

    func programar(_ med: Medicamento, tomas: [TomaProgramada]) async throws {
        await cancelar(medicamentoID: med.id)
        let futuras = tomas.filter { $0.fecha > .now }
        switch med.aviso {
        case .alarma:
            for toma in futuras {
                try await programarAlarma(med: med, idToma: toma.id, momento: toma.momento, fecha: toma.fecha, repeticion: 0)
            }
        case .recordatorio:
            for toma in futuras {
                try await programarRecordatorio(med: med, toma: toma)
            }
        case .ninguno:
            break
        }
    }

    func cancelar(medicamentoID: UUID) async {
        let prefijo = medicamentoID.uuidString
        // Alarmas
        var reg = registro
        for (alarmaID, idNotif) in reg where idNotif.hasPrefix(prefijo) {
            if let uuid = UUID(uuidString: alarmaID) { try? alarmas.cancel(id: uuid) }
            reg[alarmaID] = nil
        }
        registro = reg
        // Notificaciones pendientes y entregadas
        let pendientes = await centro.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix(prefijo) }
        centro.removePendingNotificationRequests(withIdentifiers: pendientes)
        let entregadas = await centro.deliveredNotifications().map(\.request.identifier).filter { $0.hasPrefix(prefijo) }
        centro.removeDeliveredNotifications(withIdentifiers: entregadas)
    }

    func cancelarRepeticiones(idToma: String) async {
        var ids: [String] = []
        var reg = registro
        for r in 0...Identificadores.maxRepeticiones {
            let idNotif = Identificadores.notificacion(idToma: idToma, repeticion: r)
            ids.append(idNotif)
            let alarmaID = Identificadores.alarma(idToma: idToma, repeticion: r)
            // La alarma base ya sonó o se detuvo; las repeticiones futuras se cancelan.
            try? alarmas.cancel(id: alarmaID)
            reg[alarmaID.uuidString] = nil
        }
        registro = reg
        centro.removePendingNotificationRequests(withIdentifiers: ids)
        centro.removeDeliveredNotifications(withIdentifiers: ids)
    }

    func estadoPermisos() async -> EstadoPermisos {
        let a: Permiso = switch alarmas.authorizationState {
        case .authorized: .concedido
        case .denied: .negado
        default: .sinPedir
        }
        let n: Permiso = switch await centro.notificationSettings().authorizationStatus {
        case .authorized, .provisional, .ephemeral: .concedido
        case .denied: .negado
        default: .sinPedir
        }
        return EstadoPermisos(alarmas: a, notificaciones: n)
    }

    func pedirPermiso(para tipo: TipoAviso) async -> Permiso {
        switch tipo {
        case .alarma:
            let estado = try? await alarmas.requestAuthorization()
            return estado == .authorized ? .concedido : .negado
        case .recordatorio:
            let ok = (try? await centro.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
            return ok ? .concedido : .negado
        case .ninguno:
            return .concedido
        }
    }

    // MARK: Repetición y demo

    /// Repite la alarma 10 min después si la persona la detuvo sin confirmar (máximo 2 veces).
    func repetirAlarmaSiFalta(idToma: String, repeticion: Int) async {
        guard repeticion < Identificadores.maxRepeticiones else { return }
        let contexto = Almacen.contenedor.mainContext
        if Registro.registro(idToma: idToma, contexto: contexto)?.estado == .tomada { return }
        guard let (medID, programada) = Registro.partes(de: idToma),
              let med = Almacen.medicamento(id: medID, en: contexto) else { return }
        let momento = Plan.tomas(de: med, perfil: Almacen.perfil(en: contexto) ?? Perfil(nombre: ""), desde: programada, dias: 1)
            .first { $0.id == idToma }?.momento ?? med.momentos.first ?? .desayuno
        let fecha = Date.now.addingTimeInterval(TimeInterval(Identificadores.minutosEntreRepeticiones * 60))
        try? await programarAlarma(med: med, idToma: idToma, momento: momento, fecha: fecha, repeticion: repeticion + 1)
    }

    /// Demo (PRD A6): adelanta el aviso de una toma a dentro de `segundos`.
    func programarPrueba(_ med: Medicamento, toma: TomaProgramada, segundos: TimeInterval = 60) async throws {
        let fecha = Date.now.addingTimeInterval(segundos)
        switch med.aviso {
        case .recordatorio:
            try await agregarNotificacion(med: med, idToma: toma.id, momento: toma.momento, fecha: fecha, repeticion: 0)
        default:
            try await programarAlarma(med: med, idToma: toma.id, momento: toma.momento, fecha: fecha, repeticion: 0)
        }
    }

    // MARK: Privado

    private func titulo(_ med: Medicamento) -> String {
        med.nombreVisible.capitalizedPrimera
    }

    private func programarAlarma(med: Medicamento, idToma: String, momento: Momento, fecha: Date, repeticion: Int) async throws {
        let id = Identificadores.alarma(idToma: idToma, repeticion: repeticion)
        try? alarmas.cancel(id: id)   // reprogramar no duplica
        let alerta = AlarmPresentation.Alert(
            title: "\(titulo(med)) · \(med.dosis) \(momento.texto)",
            secondaryButton: AlarmButton(text: "Ya me la tomé", textColor: .white, systemImageName: "checkmark.circle.fill"),
            secondaryButtonBehavior: .custom
        )
        let atributos = AlarmAttributes(
            presentation: AlarmPresentation(alert: alerta),
            metadata: MetadatosToma(idToma: idToma, repeticion: repeticion),
            tintColor: Color(hex: med.colorHex)
        )
        let configuracion = AlarmManager.AlarmConfiguration.alarm(
            schedule: .fixed(fecha),
            attributes: atributos,
            stopIntent: RepetirTomaIntent(idToma: idToma, repeticion: repeticion),
            secondaryIntent: YaMeLaTomeIntent(idToma: idToma),
            sound: .default
        )
        _ = try await alarmas.schedule(id: id, configuration: configuracion)
        var reg = registro
        reg[id.uuidString] = Identificadores.notificacion(idToma: idToma, repeticion: repeticion)
        registro = reg
    }

    private func programarRecordatorio(med: Medicamento, toma: TomaProgramada) async throws {
        for r in 0...Identificadores.maxRepeticiones {
            let fecha = toma.fecha.addingTimeInterval(TimeInterval(r * Identificadores.minutosEntreRepeticiones * 60))
            try await agregarNotificacion(med: med, idToma: toma.id, momento: toma.momento, fecha: fecha, repeticion: r)
        }
    }

    private func agregarNotificacion(med: Medicamento, idToma: String, momento: Momento, fecha: Date, repeticion: Int) async throws {
        let contenido = UNMutableNotificationContent()
        contenido.title = titulo(med)
        contenido.subtitle = med.nombreTecnico
        contenido.body = "\(med.dosis) \(momento.texto)" + (repeticion > 0 ? ". ¿Ya te la tomaste?" : "")
        contenido.sound = .default
        contenido.categoryIdentifier = Identificadores.categoriaToma
        contenido.userInfo = ["idToma": idToma]
        contenido.interruptionLevel = .active
        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: fecha)
        let solicitud = UNNotificationRequest(
            identifier: Identificadores.notificacion(idToma: idToma, repeticion: repeticion),
            content: contenido,
            trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        )
        try await centro.add(solicitud)   // mismo identificador = reemplaza, no duplica
    }
}
