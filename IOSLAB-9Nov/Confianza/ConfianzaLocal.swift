import Foundation
import SwiftData

extension Perfil {
    var personaConfianza: ContactoConfianza? {
        guard let nombre = confianzaNombre, let telefono = confianzaTelefono,
              let raw = confianzaCanal, let canal = CanalConfianza(rawValue: raw) else { return nil }
        return try? ContactoConfianza(nombre: nombre, telefono: telefono, canal: canal)
    }

    /// Se edita un borrador. Solo esta operación aplica y persiste los tres datos juntos.
    func guardarConfianza(_ contacto: ContactoConfianza?, en contexto: ModelContext) throws {
        let anterior = (confianzaNombre, confianzaTelefono, confianzaCanal)
        confianzaNombre = contacto?.nombre
        confianzaTelefono = contacto?.telefono
        confianzaCanal = contacto?.canal.rawValue
        do { try contexto.save() }
        catch {
            confianzaNombre = anterior.0
            confianzaTelefono = anterior.1
            confianzaCanal = anterior.2
            throw error
        }
    }
}

extension ResumenConfianza {
    @MainActor
    static func delDia(_ dia: Date, medicamentos: [Medicamento], perfil: Perfil?,
                       registros: [RegistroToma], ahora: Date) -> ResumenConfianza {
        let actividades = Agenda.tomas(en: dia, meds: medicamentos, perfil: perfil, registros: registros).map { toma in
            let estado: ActividadConfianza.Estado
            if let registro = toma.registro { estado = registro.estado == .tomada ? .confirmada : .omitida }
            else { estado = .sinRegistro }
            return ActividadConfianza(id: toma.id, fecha: toma.toma.fecha, estado: estado)
        }
        return ResumenConfianza(tomas: actividades, ahora: ahora)
    }
}
