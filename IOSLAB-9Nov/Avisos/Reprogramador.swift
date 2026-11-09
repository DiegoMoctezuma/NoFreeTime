import Foundation
import SwiftData

/// Mantiene los avisos al día: programa las tomas de los próximos días de cada medicamento activo
/// y cancela los de tratamientos terminados (RF-04 "Fin"). Se llama al confirmar "¿Cómo te aviso?"
/// y cada vez que la app vuelve al frente.
@MainActor
enum Reprogramador {
    /// Días hacia adelante: suficiente para el demo y por debajo del límite de 64 notificaciones.
    static let dias = 2

    static func reprogramarTodo(contexto: ModelContext, servicio: ServicioAvisos = ServicioAvisosSistema.compartido) async {
        guard let perfil = Almacen.perfil(en: contexto) else { return }
        let todos = (try? contexto.fetch(FetchDescriptor<Medicamento>())) ?? []
        for med in todos {
            if !med.activo || Plan.termino(med) || med.aviso == .ninguno {
                await servicio.cancelar(medicamentoID: med.id)
                continue
            }
            let tomas = Plan.tomas(de: med, perfil: perfil, desde: .now, dias: dias)
                .filter { Registro.registro(idToma: $0.id, contexto: contexto) == nil }
            try? await servicio.programar(med, tomas: tomas)
        }
    }
}
