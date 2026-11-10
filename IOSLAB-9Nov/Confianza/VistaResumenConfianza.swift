import SwiftUI
import MessageUI

/// Revisar no envía: el último paso siempre sucede en el canal elegido.
struct VistaResumenConfianza: View {
    let borrador: BorradorConfianza
    @Environment(\.dismiss) private var cerrar
    @Environment(\.openURL) private var abrirURL
    @State private var componer = false
    @State private var aviso: String?
    @State private var avisoAlCerrarMensaje: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text("Así va tu día").font(Tipo.grande).accessibilityAddTraits(.isHeader)
                    Text("Para \(borrador.contacto.nombre) · \(borrador.contacto.telefono)")
                        .font(Tipo.etiqueta)
                    Text(borrador.texto).font(.title3)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                        .tarjeta(color: Paleta.salvia)
                    Text("Este resumen refleja lo que registraste en MiMi al abrir esta vista. No incluye nombres de medicinas ni dosis. Puedes revisarlo antes de enviar.")
                        .font(.body).foregroundStyle(Paleta.tintaSuave)
                    BotonGrande(titulo: "Abrir \(borrador.contacto.canal.titulo)", icono: "message") { compartir() }
                    if borrador.contacto.canal == .whatsapp {
                        Text("Al continuar, WhatsApp recibirá este texto y el teléfono de destino mediante su enlace de composición. Tendrás que tocar Enviar allí. Si se abre el navegador, el enlace puede quedar en su historial.")
                            .font(.body).foregroundStyle(Paleta.tintaSuave)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Text("MiMi no envía mensajes automáticamente.")
                        .font(.body.weight(.semibold))
                }
                .foregroundStyle(Paleta.tinta).padding(24).entradaMiMi()
            }
            .background(Paleta.fondo.ignoresSafeArea())
            .navigationTitle("Revisar resumen").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cerrar") { cerrar() } } }
            .sheet(isPresented: $componer, onDismiss: {
                aviso = avisoAlCerrarMensaje
                avisoAlCerrarMensaje = nil
            }) {
                CompositorMensaje(contacto: borrador.contacto, texto: borrador.texto) { resultado in
                    componer = false
                    switch resultado {
                    case .sent: avisoAlCerrarMensaje = "Mensajes recibió tu solicitud de envío. MiMi no puede confirmar la entrega."
                    case .failed: avisoAlCerrarMensaje = "Mensajes no pudo enviar el resumen. Puedes intentarlo de nuevo."
                    case .cancelled: break
                    @unknown default: break
                    }
                }
            }
            .alert("Resumen de MiMi", isPresented: Binding(get: { aviso != nil }, set: { if !$0 { aviso = nil } })) {
                Button("Entendido") { aviso = nil }
            } message: { Text(aviso ?? "") }
        }
        .tamanoLetraElegido()
    }

    private func compartir() {
        switch borrador.contacto.canal {
        case .mensajes:
            guard MFMessageComposeViewController.canSendText() else {
                aviso = "Este dispositivo no tiene Mensajes disponible para enviar. Puedes cambiar el canal en tu persona de confianza."
                return
            }
            componer = true
        case .whatsapp:
            guard let url = borrador.contacto.urlWhatsApp(texto: borrador.texto) else {
                aviso = "No pude preparar el enlace de WhatsApp. Revisa el teléfono del contacto."
                return
            }
            abrirURL(url) { aceptada in
                if !aceptada { aviso = "No pude abrir WhatsApp. Revisa que esté instalado o cambia el canal en tu persona de confianza." }
            }
        }
    }
}

private struct CompositorMensaje: UIViewControllerRepresentable {
    let contacto: ContactoConfianza
    let texto: String
    let alTerminar: (MessageComposeResult) -> Void

    func makeUIViewController(context: Context) -> MFMessageComposeViewController {
        let vista = MFMessageComposeViewController()
        vista.recipients = [contacto.telefono]
        vista.body = texto
        vista.messageComposeDelegate = context.coordinator
        return vista
    }

    func updateUIViewController(_ uiViewController: MFMessageComposeViewController, context: Context) {}
    func makeCoordinator() -> Coordinador { Coordinador(alTerminar: alTerminar) }

    final class Coordinador: NSObject, MFMessageComposeViewControllerDelegate {
        let alTerminar: (MessageComposeResult) -> Void
        init(alTerminar: @escaping (MessageComposeResult) -> Void) { self.alTerminar = alTerminar }

        func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) {
            alTerminar(result)
        }
    }
}
