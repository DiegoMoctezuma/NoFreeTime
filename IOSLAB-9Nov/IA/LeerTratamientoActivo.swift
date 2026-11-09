import Foundation
import FoundationModels

/// Herramienta de solo lectura: el tratamiento activo, una línea por medicamento (PRD A5).
/// Se construye con una copia del tratamiento: el modelo nunca toca SwiftData.
nonisolated struct LeerTratamientoActivo: Tool {
    let name = "leerTratamientoActivo"
    let description = "Devuelve los medicamentos que la persona ya tiene registrados, uno por línea: nombre · concentración · dosis · momentos. Solo lectura."

    @Generable
    struct Arguments {}

    let lineas: [String]

    func call(arguments: Arguments) async throws -> String {
        lineas.isEmpty ? "La persona no tiene medicamentos registrados." : lineas.joined(separator: "\n")
    }
}

extension LeerTratamientoActivo {
    /// "Losartán · 50 mg · 1 tableta · desayuno"
    @MainActor
    init(tratamiento: [Medicamento]) {
        self.init(lineas: tratamiento.filter(\.activo).map { m in
            [m.nombre, m.concentracion ?? "", m.dosis, m.momentos.map(\.nombre).joined(separator: ", ")]
                .filter { !$0.isEmpty }
                .joined(separator: " · ")
        })
    }
}
