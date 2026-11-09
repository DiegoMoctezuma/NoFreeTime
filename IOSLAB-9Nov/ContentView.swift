import SwiftUI
import SwiftData
import FoundationModels

/// Raíz de la app (CONTRATOS §7).
/// Sin perfil → Alta (WP-03); con perfil → Tu día (WP-05).
/// Mientras esas pantallas no se integran, muestra la vista de andamiaje de WP-00.
struct ContentView: View {
    var body: some View {
        // Al integrar WP-03 y WP-05: if perfiles.isEmpty { AltaFlujoView {…} } else { TuDiaView() }
        AndamiajeView()
    }
}

/// Vista provisional de WP-00: lista de medicamentos y disponibilidad de Apple Intelligence.
private struct AndamiajeView: View {
    @Environment(\.modelContext) private var contexto
    @Query(sort: \Medicamento.nombre) private var medicamentos: [Medicamento]
    @Query private var perfiles: [Perfil]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Etiqueta(texto: textoIA,
                             icono: iaDisponible ? "checkmark.seal.fill" : "exclamationmark.triangle.fill",
                             color: iaDisponible ? Paleta.tomada : Paleta.sePaso)
                }
                Section(perfiles.first.map { "Medicamentos de \($0.nombre)" } ?? "Medicamentos") {
                    if medicamentos.isEmpty {
                        Text("Sin medicamentos").foregroundStyle(.secondary)
                    }
                    ForEach(medicamentos) { med in
                        HStack(spacing: 12) {
                            Circle().fill(Color(hex: med.colorHex)).frame(width: 20, height: 20)
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(med.nombreVisible.capitalizedPrimera).font(.title3.bold())
                                Text("\(med.nombreTecnico) · \(med.dosis) · \(med.momentos.map(\.texto).joined(separator: ", "))")
                                    .font(.subheadline).foregroundStyle(.secondary)
                            }
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
                Section {
                    BotonGrande(titulo: "Cargar datos de ejemplo", icono: "tray.and.arrow.down") {
                        DatosDemo.cargar(en: contexto)
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
            }
            .navigationTitle("Andamiaje")
        }
    }

    private var iaDisponible: Bool {
        if case .available = SystemLanguageModel.default.availability { return true }
        return false
    }

    private var textoIA: String {
        switch SystemLanguageModel.default.availability {
        case .available:
            return "Apple Intelligence: disponible"
        case .unavailable(.deviceNotEligible):
            return "Apple Intelligence: este iPhone no es compatible"
        case .unavailable(.appleIntelligenceNotEnabled):
            return "Apple Intelligence: no está activado"
        case .unavailable(.modelNotReady):
            return "Apple Intelligence: el modelo se está descargando"
        case .unavailable:
            return "Apple Intelligence: no disponible"
        }
    }
}

extension String {
    /// "la de la presión" → "La de la presión"
    var capitalizedPrimera: String { prefix(1).uppercased() + dropFirst() }
}

#Preview {
    ContentView()
        .modelContainer(Almacen.vistaPrevia())
}
