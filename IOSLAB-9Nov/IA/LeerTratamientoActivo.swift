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
    /// Registro de qué herramientas consultó el modelo (para decírselo a la persona).
    var uso = UsoHerramientas()

    func call(arguments: Arguments) async throws -> String {
        uso.registrar(name)
        return lineas.isEmpty ? "La persona no tiene medicamentos registrados." : lineas.joined(separator: "\n")
    }
}

extension LeerTratamientoActivo {
    /// "Losartán · 50 mg · 1 tableta · desayuno"
    @MainActor
    init(tratamiento: [Medicamento], uso: UsoHerramientas = UsoHerramientas()) {
        self.init(lineas: Self.lineas(de: tratamiento), uso: uso)
    }

    /// Una línea por medicamento activo (también la usa DeepSeek).
    @MainActor
    static func lineas(de tratamiento: [Medicamento]) -> [String] {
        tratamiento.filter(\.activo).map { m in
            [m.nombre, m.concentracion ?? "", m.dosis, m.textoPauta]
                .filter { !$0.isEmpty }
                .joined(separator: " · ")
        }
    }
}

/// Herramienta de solo lectura: las horas de la rutina de la persona, para acomodar los momentos de cada toma.
nonisolated struct LeerRutina: Tool {
    let name = "leerRutina"
    let description = "Devuelve a qué hora desayuna, come, cena y se duerme la persona. Solo lectura."

    @Generable
    struct Arguments {}

    let lineas: [String]
    var uso = UsoHerramientas()

    func call(arguments: Arguments) async throws -> String {
        uso.registrar(name)
        return lineas.isEmpty ? "No hay rutina registrada; usa desayuno 8:00, comida 14:00, cena 20:00 y dormir 22:00." : lineas.joined(separator: "\n")
    }
}

extension LeerRutina {
    @MainActor
    init(perfil: Perfil?, uso: UsoHerramientas = UsoHerramientas()) {
        self.init(lineas: Self.lineas(de: perfil), uso: uso)
    }

    /// "Desayuno: 08:00"
    @MainActor
    static func lineas(de perfil: Perfil?) -> [String] {
        guard let perfil else { return [] }
        return Momento.rutina.map { m in
            let h = perfil.hora(de: m)
            return String(format: "%@: %02d:%02d", m.nombre, h.hour ?? 0, h.minute ?? 0)
        }
    }
}

/// Qué herramientas usó el modelo en una lectura. Las herramientas corren fuera del hilo principal.
nonisolated final class UsoHerramientas: @unchecked Sendable {
    private let candado = NSLock()
    private var usadas: [String] = []

    func registrar(_ nombre: String) {
        candado.lock()
        usadas.append(nombre)
        candado.unlock()
    }

    var nombres: Set<String> {
        candado.lock()
        defer { candado.unlock() }
        return Set(usadas)
    }
}
