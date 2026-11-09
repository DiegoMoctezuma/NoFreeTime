import SwiftUI
import SwiftData

@main struct MyApp: App {
    @Environment(\.scenePhase) private var fase

    init() {
        // Antes de cualquier respuesta a una notificación ("Ya me la tomé").
        DelegadoNotificaciones.configurar()
        #if DEBUG
        // Argumento de arranque `-demo`: carga los datos de ejemplo de don Ernesto.
        if ProcessInfo.processInfo.arguments.contains("-demo") {
            DatosDemo.cargar(en: Almacen.contenedor.mainContext)
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(Navegacion.compartida)
        }
        .onChange(of: fase) { _, nueva in
            // Mantiene los avisos de los próximos días y cancela tratamientos terminados.
            if nueva == .active {
                Task { await Reprogramador.reprogramarTodo(contexto: Almacen.contenedor.mainContext) }
            }
        }
        .modelContainer(Almacen.contenedor)
    }
}
