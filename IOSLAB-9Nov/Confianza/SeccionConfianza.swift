import SwiftUI
import SwiftData

/// La ayuda vive en Perfil: Inicio conserva sus acciones habituales.
struct SeccionConfianza: View {
    let perfil: Perfil
    @Query(filter: #Predicate<Medicamento> { $0.activo }, sort: \Medicamento.nombre) private var medicamentos: [Medicamento]
    @Query private var registros: [RegistroToma]
    @Environment(\.openURL) private var abrirURL
    @State private var configurar = false
    @State private var borrador: BorradorConfianza?
    @State private var errorLlamada = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Tu persona de confianza", systemImage: "person.2")
                .font(Tipo.tarjeta).foregroundStyle(Paleta.tinta)
                .accessibilityAddTraits(.isHeader)
            if let contacto = perfil.personaConfianza {
                VStack(alignment: .leading, spacing: 14) {
                    Text(contacto.nombre).font(Tipo.seccion)
                    Text("\(contacto.telefono) · \(contacto.canal.titulo)").font(.body)
                    Text("Si necesitas compañía o ayuda, puedes llamarle. También puedes compartir cómo va tu día.")
                        .font(.body).fixedSize(horizontal: false, vertical: true)
                    BotonGrande(titulo: "Llamar a \(contacto.nombre)", icono: "phone") {
                        abrirURL(contacto.urlLlamada) { aceptada in errorLlamada = !aceptada }
                    }
                    BotonGrande(titulo: "Revisar resumen de hoy", icono: "text.bubble", estilo: .secundario) {
                        let ahora = Date.now
                        let resumen = ResumenConfianza.delDia(ahora, medicamentos: medicamentos, perfil: perfil,
                                                             registros: registros, ahora: ahora)
                        borrador = BorradorConfianza(contacto: contacto, texto: resumen.mensaje(nombre: perfil.nombre, fecha: ahora))
                    }
                    Button("Cambiar o quitar contacto") { configurar = true }
                        .font(Tipo.etiqueta).underline().frame(minHeight: 48)
                }
                .foregroundStyle(Paleta.tinta)
                .tarjeta(color: Paleta.salvia)
            } else {
                Text("Puedes elegir a un familiar o amistad. Es opcional y lo pueden configurar juntos.")
                    .font(.body).foregroundStyle(Paleta.tintaSuave)
                    .fixedSize(horizontal: false, vertical: true)
                BotonGrande(titulo: "Elegir persona de confianza", icono: "person.badge.plus", estilo: .secundario) {
                    configurar = true
                }
            }
            Text("Los mensajes se envían solo cuando tú los confirmas. Los avisos automáticos a familiares aún no están disponibles.")
                .font(.body).foregroundStyle(Paleta.tintaSuave)
                .fixedSize(horizontal: false, vertical: true)
        }
        .sheet(isPresented: $configurar) { EditorConfianzaView(perfil: perfil) }
        .sheet(item: $borrador) { VistaResumenConfianza(borrador: $0) }
        .alert("No pude abrir la llamada", isPresented: $errorLlamada) {
            Button("Entendido", role: .cancel) {}
        } message: { Text("Revisa si este dispositivo puede hacer llamadas. El teléfono de tu persona de confianza está en esta sección.") }
        .entradaMiMi(orden: 2)
    }
}

struct BorradorConfianza: Identifiable {
    let id = UUID()
    let contacto: ContactoConfianza
    let texto: String
}
