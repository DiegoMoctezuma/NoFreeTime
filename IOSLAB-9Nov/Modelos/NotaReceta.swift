import Foundation
import SwiftData

/// Nota general escrita en una receta que no es de un medicamento
/// ("Dieta baja en sal", "Regresar a consulta en 1 mes"). Solo se guarda si la persona lo confirma.
@Model
final class NotaReceta {
    @Attribute(.unique) var id: UUID
    var texto: String
    var fecha: Date

    init(id: UUID = UUID(), texto: String, fecha: Date = .now) {
        self.id = id
        self.texto = texto
        self.fecha = fecha
    }
}
