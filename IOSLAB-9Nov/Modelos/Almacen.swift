import Foundation
import SwiftData

/// Contenedor de SwiftData compartido por la app y los App Intents (CONTRATOS §4).
enum Almacen {
    static let esquema = Schema([Perfil.self, Medicamento.self, RegistroToma.self])

    static let contenedor: ModelContainer = {
        let enMemoria = ProcessInfo.processInfo.arguments.contains("-enMemoria")
        let config = ModelConfiguration(schema: esquema, isStoredInMemoryOnly: enMemoria)
        do {
            return try ModelContainer(for: esquema, configurations: [config])
        } catch {
            fatalError("No se pudo crear el almacén: \(error)")
        }
    }()

    /// Contenedor en memoria con los datos de ejemplo (para #Preview).
    static func vistaPrevia() -> ModelContainer {
        let config = ModelConfiguration(schema: esquema, isStoredInMemoryOnly: true)
        let c = try! ModelContainer(for: esquema, configurations: [config])
        DatosDemo.cargar(en: c.mainContext)
        return c
    }

    static func perfil(en contexto: ModelContext) -> Perfil? {
        try? contexto.fetch(FetchDescriptor<Perfil>()).first
    }

    static func medicamentosActivos(en contexto: ModelContext) -> [Medicamento] {
        let d = FetchDescriptor<Medicamento>(predicate: #Predicate { $0.activo }, sortBy: [SortDescriptor(\.nombre)])
        return (try? contexto.fetch(d)) ?? []
    }

    static func medicamento(id: UUID, en contexto: ModelContext) -> Medicamento? {
        var d = FetchDescriptor<Medicamento>(predicate: #Predicate { $0.id == id })
        d.fetchLimit = 1
        return try? contexto.fetch(d).first
    }
}
