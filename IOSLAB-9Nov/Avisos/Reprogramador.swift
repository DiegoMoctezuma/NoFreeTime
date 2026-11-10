import Foundation
import SwiftData

/// Mantiene los avisos al día: programa las tomas próximas de cada medicamento activo
/// y cancela los de tratamientos terminados (RF-04 "Fin"). Se llama al confirmar "¿Cómo te aviso?"
/// y cada vez que la app vuelve al frente.
///
/// iOS guarda como máximo 64 notificaciones pendientes y descarta el resto sin avisar.
/// Por eso se juntan las tomas de todas las medicinas, se ordenan por hora y solo se programan
/// las más próximas hasta `tope`. Las demás se programan al volver a abrir la app.
@MainActor
enum Reprogramador {
    /// Días hacia adelante para medicinas con horario por comidas o a hora fija.
    static let dias = 2
    /// Horas hacia adelante para pautas "cada N horas" (generan muchas tomas).
    static let horasIntervalo: TimeInterval = 24
    /// Avisos como máximo: deja margen bajo el límite de 64 de iOS.
    static let tope = 60

    static func reprogramarTodo(contexto: ModelContext, servicio: ServicioAvisos = ServicioAvisosSistema.compartido) async {
        guard let perfil = Almacen.perfil(en: contexto) else { return }
        let ahora = Date.now
        let todos = (try? contexto.fetch(FetchDescriptor<Medicamento>())) ?? []
        var activos: [Medicamento] = []
        var porMedicamento: [UUID: [TomaProgramada]] = [:]
        var candidatos: [(toma: TomaProgramada, costo: Int)] = []

        for med in todos {
            if !med.activo || Plan.termino(med) || med.aviso == .ninguno {
                await servicio.cancelar(medicamentoID: med.id)
                continue
            }
            activos.append(med)
            let esIntervalo = med.inicioIntervalo != nil
            let limite = esIntervalo ? ahora.addingTimeInterval(horasIntervalo * 3600) : .distantFuture
            let tomas = Plan.tomas(de: med, perfil: perfil, desde: ahora, dias: esIntervalo ? 2 : dias)
                .filter { $0.fecha > ahora && $0.fecha <= limite }
                .filter { Registro.registro(idToma: $0.id, contexto: contexto) == nil }
            porMedicamento[med.id] = tomas
            let costo = med.aviso == .recordatorio ? 1 + ServicioAvisosSistema.repeticiones(para: med) : 1
            candidatos += tomas.map { (toma: $0, costo: costo) }
        }

        let elegidas = Set(seleccionar(candidatos, tope: tope).map(\.id))
        for med in activos {
            // `programar` cancela primero: una medicina sin tomas elegidas queda sin avisos pendientes por ahora.
            let tomas = (porMedicamento[med.id] ?? []).filter { elegidas.contains($0.id) }
            try? await servicio.programar(med, tomas: tomas)
        }
    }

    /// Las tomas más próximas cuyo costo total (avisos que generan) no pasa de `tope`.
    /// Se detiene en la primera que ya no cabe, para no saltarse una toma cercana por una lejana.
    static func seleccionar(_ candidatos: [(toma: TomaProgramada, costo: Int)], tope: Int) -> [TomaProgramada] {
        var usado = 0
        var elegidas: [TomaProgramada] = []
        for c in candidatos.sorted(by: { $0.toma.fecha < $1.toma.fecha }) {
            guard usado + c.costo <= tope else { break }
            usado += c.costo
            elegidas.append(c.toma)
        }
        return elegidas
    }
}
