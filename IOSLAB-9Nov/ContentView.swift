import SwiftUI
import SwiftData

/// Raíz de la app (CONTRATOS §7).
/// Primera vez → presentación y entrevista (sin cuenta ni registro).
/// Después → pestañas Inicio, Calendario, Agregar y Perfil con la barra nativa (Liquid Glass).
struct ContentView: View {
    @Query private var perfiles: [Perfil]
    @AppStorage(ClavesApp.altaTerminada) private var altaTerminada = false
    @Environment(Navegacion.self) private var navegacion

    var body: some View {
        Group {
            if perfiles.first != nil && altaTerminada {
                InicioView()
                    .transition(.opacity)
            } else {
                OnboardingView { agregarAhora in
                    navegacion.pestana = agregarAhora ? .escanear : .hoy
                    withAnimation(.easeInOut(duration: 0.3)) { altaTerminada = true }
                }
                .transition(.opacity)
            }
        }
        .tint(Paleta.tinta)
        .preferredColorScheme(.light)
    }
}

/// Pestañas de la app ya configurada. La barra es la del sistema: en iOS 26+ es de Liquid Glass.
struct InicioView: View {
    @Environment(Navegacion.self) private var navegacion

    var body: some View {
        @Bindable var navegacion = navegacion
        TabView(selection: $navegacion.pestana) {
            Tab(Pestana.hoy.titulo, systemImage: Pestana.hoy.icono, value: Pestana.hoy) {
                TuDiaView()
            }
            Tab(Pestana.calendario.titulo, systemImage: Pestana.calendario.icono, value: Pestana.calendario) {
                CalendarioView()
            }
            Tab(Pestana.escanear.titulo, systemImage: Pestana.escanear.icono, value: Pestana.escanear) {
                AltaFlujoView { navegacion.pestana = .hoy }
            }
            Tab(Pestana.perfil.titulo, systemImage: Pestana.perfil.icono, value: Pestana.perfil) {
                PerfilView()
            }
        }
        .tint(Paleta.tinta)
        .onChange(of: navegacion.tomaResaltada) { _, nueva in
            // Un aviso abrió la app: se muestra Inicio con la toma resaltada.
            if nueva != nil { navegacion.pestana = .hoy }
        }
    }
}

extension String {
    /// "la de la presión" → "La de la presión"
    var capitalizedPrimera: String { prefix(1).uppercased() + dropFirst() }
}

#Preview("Con datos") {
    ContentView()
        .modelContainer(Almacen.vistaPrevia())
        .environment(Navegacion.compartida)
}
