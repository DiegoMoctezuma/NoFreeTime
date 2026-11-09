import Foundation
import SwiftData

/// Único punto que escribe un `RegistroToma` (CONTRATOS §3).
/// Solo se llama desde una acción visible de la persona (botón, alarma, notificación o Siri).
enum Registro {
    enum Fallo: LocalizedError {
        case idInvalido(String)
        var errorDescription: String? {
            switch self {
            case .idInvalido(let id): "Identificador de toma inválido: \(id)"
            }
        }
    }

    @discardableResult
    static func marcarTomada(idToma: String, contexto: ModelContext, ahora: Date = .now) throws -> RegistroToma {
        try guardar(idToma: idToma, estado: .tomada, registrada: ahora, contexto: contexto)
    }

    static func marcarSePaso(idToma: String, contexto: ModelContext) throws {
        try guardar(idToma: idToma, estado: .sePaso, registrada: nil, contexto: contexto)
    }

    /// Borra el registro (botón "Deshacer").
    static func deshacer(idToma: String, contexto: ModelContext) throws {
        if let r = registro(idToma: idToma, contexto: contexto) {
            contexto.delete(r)
            try contexto.save()
        }
    }

    static func registro(idToma: String, contexto: ModelContext) -> RegistroToma? {
        var d = FetchDescriptor<RegistroToma>(predicate: #Predicate { $0.idToma == idToma })
        d.fetchLimit = 1
        return try? contexto.fetch(d).first
    }

    static func partes(de idToma: String) -> (UUID, Date)? {
        guard let p = TomaProgramada.partes(de: idToma) else { return nil }
        return (p.medicamentoID, p.fecha)
    }

    private static func guardar(idToma: String, estado: EstadoToma, registrada: Date?, contexto: ModelContext) throws -> RegistroToma {
        guard let (medID, programada) = partes(de: idToma) else { throw Fallo.idInvalido(idToma) }
        let r: RegistroToma
        if let existente = registro(idToma: idToma, contexto: contexto) {
            existente.estado = estado
            existente.registrada = registrada
            r = existente
        } else {
            r = RegistroToma(idToma: idToma, medicamentoID: medID, programada: programada, registrada: registrada, estado: estado)
            contexto.insert(r)
        }
        try contexto.save()
        return r
    }
}
