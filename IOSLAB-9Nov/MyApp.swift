import SwiftUI
import SwiftData

@main struct MyApp: App {
    init() {
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
        .modelContainer(Almacen.contenedor)
    }
}
