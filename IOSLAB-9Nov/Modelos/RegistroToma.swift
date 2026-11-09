import Foundation
import SwiftData

/// Lo que la persona registró sobre una toma (RF-06). Solo se crea por una acción visible.
@Model
final class RegistroToma {
    @Attribute(.unique) var idToma: String
    var medicamentoID: UUID
    var programada: Date
    var registrada: Date?
    var estadoRaw: String

    init(idToma: String, medicamentoID: UUID, programada: Date, registrada: Date?, estado: EstadoToma) {
        self.idToma = idToma
        self.medicamentoID = medicamentoID
        self.programada = programada
        self.registrada = registrada
        self.estadoRaw = estado.rawValue
    }

    var estado: EstadoToma {
        get { EstadoToma(rawValue: estadoRaw) ?? .sePaso }
        set { estadoRaw = newValue.rawValue }
    }
}
