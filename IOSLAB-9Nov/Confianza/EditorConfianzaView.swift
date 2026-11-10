import SwiftUI
import SwiftData

/// Configuración que el familiar puede hacer una sola vez, sin cuentas ni claves de terceros.
struct EditorConfianzaView: View {
    let perfil: Perfil
    @Environment(\.modelContext) private var contexto
    @Environment(\.dismiss) private var cerrar
    @State private var nombre: String
    @State private var telefono: String
    @State private var canal: CanalConfianza
    @State private var acepta: Bool
    @State private var error: String?
    @State private var quitar = false

    init(perfil: Perfil) {
        self.perfil = perfil
        let contacto = perfil.personaConfianza
        _nombre = State(initialValue: contacto?.nombre ?? "")
        _telefono = State(initialValue: contacto?.telefono ?? "")
        _canal = State(initialValue: contacto?.canal ?? .mensajes)
        _acepta = State(initialValue: contacto != nil)
    }

    private var contactoValido: ContactoConfianza? {
        try? ContactoConfianza(nombre: nombre, telefono: telefono, canal: canal)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Label("Tu persona de confianza", systemImage: "person.2.fill")
                        .font(Tipo.titulo).foregroundStyle(Paleta.tinta)
                        .accessibilityAddTraits(.isHeader)
                    Text("Elige a alguien con quien puedas hablar. Pueden configurar esto juntos, y cambiarlo o quitarlo cuando quieras.")
                        .font(.title3).foregroundStyle(Paleta.tintaSuave)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Su nombre").font(Tipo.etiqueta)
                        TextField("Por ejemplo, Ana", text: $nombre)
                            .textContentType(.name).textInputAutocapitalization(.words)
                            .campoConfianza()
                            .accessibilityLabel("Nombre de tu persona de confianza")
                        Text("Su teléfono con código de país").font(Tipo.etiqueta)
                        TextField("+52 55 1234 5678", text: $telefono)
                            .keyboardType(.phonePad).textContentType(.telephoneNumber)
                            .campoConfianza()
                            .accessibilityLabel("Teléfono de tu persona de confianza, con código de país")
                        if !telefono.isEmpty && contactoValido == nil {
                            Text("Usa + y el código de país; revisa también el nombre.")
                                .font(.body).foregroundStyle(Paleta.tintaSuave)
                        }
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Para compartir un resumen").font(Tipo.etiqueta)
                        ForEach(CanalConfianza.allCases, id: \.self) { opcion in
                            TarjetaOpcion(icono: "message", titulo: opcion.titulo,
                                          elegida: canal == opcion) { canal = opcion }
                        }
                    }
                    Toggle("Esta persona está de acuerdo en que la contacte", isOn: $acepta)
                        .font(.body).tint(Paleta.marcaFuerte)
                    Label("El contacto se guarda en este iPhone. MiMi no envía avisos automáticos. Tú revisas y confirmas cada mensaje en Mensajes o WhatsApp.", systemImage: "lock")
                        .font(.body).fixedSize(horizontal: false, vertical: true)
                        .tarjeta(color: Paleta.salvia)
                    BotonGrande(titulo: "Guardar persona de confianza", icono: "checkmark") { guardar() }
                        .disabled(!acepta || contactoValido == nil)
                    if perfil.personaConfianza != nil {
                        BotonGrande(titulo: "Quitar persona de confianza", estilo: .texto) { quitar = true }
                    }
                }
                .foregroundStyle(Paleta.tinta)
                .padding(24)
                .entradaMiMi()
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: nombre) { _, _ in acepta = false }
            .onChange(of: telefono) { _, _ in acepta = false }
            .onChange(of: canal) { _, _ in acepta = false }
            .background(Paleta.fondo.ignoresSafeArea())
            .navigationTitle("Persona de confianza")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { cerrar() } } }
            .confirmationDialog("¿Quitar a tu persona de confianza?", isPresented: $quitar, titleVisibility: .visible) {
                Button("Quitar contacto", role: .destructive) { persistir(nil) }
                Button("Cancelar", role: .cancel) {}
            }
            .alert("No pude guardar el contacto", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                Button("Entendido") { error = nil }
            } message: { Text(error ?? "Intenta de nuevo.") }
        }
        .tamanoLetraElegido()
    }

    private func guardar() {
        guard acepta else { return }
        do { persistir(try ContactoConfianza(nombre: nombre, telefono: telefono, canal: canal)) }
        catch { self.error = error.localizedDescription }
    }

    private func persistir(_ contacto: ContactoConfianza?) {
        do {
            try perfil.guardarConfianza(contacto, en: contexto)
            cerrar()
        } catch { self.error = "Tus cambios siguen aquí. Intenta guardar de nuevo." }
    }
}

private extension View {
    func campoConfianza() -> some View {
        self.font(.title3).autocorrectionDisabled()
            .padding(16).frame(minHeight: 60)
            .background(RoundedRectangle(cornerRadius: Radio.control).fill(Paleta.fondo))
            .overlay(RoundedRectangle(cornerRadius: Radio.control).strokeBorder(Paleta.borde, lineWidth: 1.2))
    }
}
