import SwiftUI
import SwiftData
import PhotosUI
import UIKit

/// Foto de la receta o de la caja → propuesta (RF-02, RF-03). Leer no guarda nada.
struct LeerFotoView: View {
    enum Modo { case receta, caja }

    let modo: Modo
    /// Hay borradores (receta) o datos de una caja nueva listos en el modelo.
    let alLeer: () -> Void
    /// La caja es de una medicina que ya está en el tratamiento.
    let alConocer: (UUID) -> Void
    let sinReceta: () -> Void

    private enum Estado {
        case preparar
        case leyendo(UIImage)
        case ilegible
        case sinIA(String)
    }

    @Environment(ModeloAlta.self) private var modelo
    @Environment(LectorIA.self) private var lector
    @Environment(\.modelContext) private var contexto
    @State private var estado: Estado = .preparar
    @State private var camaraAbierta = false
    @State private var fotoElegida: PhotosPickerItem?

    private var hayCamara: Bool { UIImagePickerController.isSourceTypeAvailable(.camera) }
    private var esReceta: Bool { modo == .receta }

    var body: some View {
        Group {
            switch estado {
            case .preparar: preparar
            case .leyendo(let foto): LeyendoView(foto: foto, etapa: lector.etapa, esReceta: esReceta)
            case .ilegible: ilegible
            case .sinIA(let motivo): sinIA(motivo)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: clave)
        .fullScreenCover(isPresented: $camaraAbierta) {
            CamaraSistema { foto in
                camaraAbierta = false
                Task { await leer(foto) }
            } alCancelar: {
                camaraAbierta = false
            }
            .ignoresSafeArea()
        }
        .onChange(of: fotoElegida) { _, item in
            guard let item else { return }
            fotoElegida = nil
            Task {
                if let datos = try? await item.loadTransferable(type: Data.self), let foto = UIImage(data: datos) {
                    await leer(foto)
                } else {
                    estado = .ilegible
                }
            }
        }
    }

    private var clave: Int {
        switch estado {
        case .preparar: 0
        case .leyendo: 1
        case .ilegible: 2
        case .sinIA: 3
        }
    }

    // MARK: Pantallas

    private var preparar: some View {
        PantallaPregunta(titulo: esReceta ? "Fotografía tu receta" : "Fotografía la caja",
                         subtitulo: esReceta
                            ? "Ponla sobre una mesa con buena luz y que se vea completa."
                            : "Que se vea de frente el nombre y los miligramos.") {
            IlustracionEncuadre(esReceta: esReceta)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
        } botones: {
            if hayCamara {
                BotonGrande(titulo: "Tomar foto", icono: "camera") { camaraAbierta = true }
            }
            PhotosPicker(selection: $fotoElegida, matching: .images) {
                EtiquetaBoton(titulo: "Elegir de mis fotos", icono: "photo.on.rectangle",
                              estilo: hayCamara ? .secundario : .principal)
            }
            .buttonStyle(EstiloBotonGrande(estilo: hayCamara ? .secundario : .principal))
        }
    }

    private var ilegible: some View {
        PantallaPregunta(titulo: "No pude leerla",
                         subtitulo: esReceta ? "¿Otra foto o lo hacemos sin receta?" : "¿Otra foto o la escribes tú?",
                         ilustracion: Ilustracion(nombre: "ilus-ilegible", simbolo: "doc.text.magnifyingglass",
                                                  color: Paleta.acentoSuave, color2: Paleta.agua, alto: 180)) {
            Text("Ayuda que esté plana, sin sombras ni reflejos, y que la letra sea impresa.")
                .font(.body)
                .foregroundStyle(Paleta.tintaSuave)
        } botones: {
            BotonGrande(titulo: "Tomar otra foto", icono: "camera") {
                estado = .preparar
                if hayCamara { camaraAbierta = true }
            }
            BotonGrande(titulo: "Escribirla yo", estilo: .secundario, accion: sinReceta)
        }
    }

    private func sinIA(_ motivo: String) -> some View {
        PantallaPregunta(titulo: "Hoy no puedo leer fotos", subtitulo: motivo) {
            Text("No se perdió nada. Podemos agregar tus medicinas una por una; tarda un minuto.")
                .font(.body)
                .foregroundStyle(Paleta.tinta)
                .tarjeta(relleno: 18)
        } botones: {
            BotonGrande(titulo: "Escribirla yo", icono: "square.and.pencil", accion: sinReceta)
        }
    }

    // MARK: Lectura

    private func leer(_ foto: UIImage) async {
        let reducida = foto.reducida(maximo: 2048)
        estado = .leyendo(reducida)
        guard let imagen = reducida.cgImageOrientado else {
            estado = .ilegible
            return
        }
        do {
            switch modo {
            case .receta:
                let tratamiento = Almacen.medicamentosActivos(en: contexto)
                let r = try await lector.leerReceta(imagen, tratamiento: tratamiento)
                guard r.legible else {
                    estado = .ilegible
                    return
                }
                modelo.borradores = r.indicaciones.map { Borrador(revisada: $0) }
                modelo.consulta = lector.ultimaConsulta
                modelo.notas = lector.ultimasNotas
                modelo.vieneDeReceta = true
                estado = .preparar
                alLeer()
            case .caja:
                let r = try await lector.leerCajaRevisada(imagen)
                guard r.caja.legible, let nombre = r.caja.nombre else {
                    estado = .ilegible
                    return
                }
                modelo.manualFoto = reducida.reducida(maximo: 600).jpegData(compressionQuality: 0.8)
                modelo.manualPastillas = r.caja.pastillas
                let tratamiento = Almacen.medicamentosActivos(en: contexto)
                if let existente = MapeoIndicacion.medicamento(paraCaja: r.caja, en: tratamiento) {
                    estado = .preparar
                    alConocer(existente.id)
                    return
                }
                modelo.manualNombre = nombre.trimmingCharacters(in: .whitespaces)
                modelo.manualConcentracion = r.caja.concentracion ?? ""
                modelo.manualDudosos = r.dudosos
                modelo.manualFuente = r.fuente
                modelo.vieneDeReceta = false
                estado = .preparar
                alLeer()
            }
        } catch LectorIA.Fallo.noDisponible(let motivo) {
            estado = .sinIA(motivo)
        } catch {
            estado = .ilegible
        }
    }
}

/// Foto con una línea que la recorre mientras lee, y la etapa en palabras.
struct LeyendoView: View {
    let foto: UIImage
    let etapa: LectorIA.Etapa
    let esReceta: Bool

    @Environment(\.accessibilityReduceMotion) private var reducirMovimiento
    @Environment(\.scenePhase) private var fase
    @State private var visible = false

    private var texto: String {
        switch etapa {
        case .inactivo, .buscandoTexto: "Buscando el texto…"
        case .ordenando: esReceta ? "Organizando las indicaciones…" : "Viendo qué medicina es…"
        case .revisando: "Revisando cada dato…"
        }
    }

    var body: some View {
        VStack(spacing: 28) {
            Spacer(minLength: 0)
            Image(uiImage: foto)
                .resizable()
                .scaledToFill()
                .frame(width: 220, height: 280)
                .clipShape(RoundedRectangle(cornerRadius: Radio.tarjeta, style: .continuous))
                .overlay(alignment: .top) {
                    TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reducirMovimiento || fase != .active || !visible)) { reloj in
                        let progreso = reducirMovimiento ? 0.5 : (1 - cos(reloj.date.timeIntervalSinceReferenceDate * .pi / 1.4)) / 2
                        Capsule()
                            .fill(Paleta.acento)
                            .frame(height: 4)
                            .padding(.horizontal, 10)
                            .offset(y: 8 + 260 * progreso)
                    }
                }
                .overlay(RoundedRectangle(cornerRadius: Radio.tarjeta, style: .continuous)
                    .strokeBorder(Paleta.tinta, lineWidth: 1.5))
                .accessibilityHidden(true)
            VStack(spacing: 10) {
                ProgressView().controlSize(.large).tint(Paleta.tinta)
                Text(texto)
                    .font(Tipo.titulo)
                    .foregroundStyle(Paleta.tinta)
                    .contentTransition(.opacity)
                    .animation(.easeInOut, value: texto)
                Text("Tarda unos segundos.")
                    .font(.title3)
                    .foregroundStyle(Paleta.tintaSuave)
            }
            .multilineTextAlignment(.center)
            .accessibilityElement(children: .combine)
            Spacer(minLength: 0)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Paleta.fondo.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .entradaMiMi()
        .onAppear { visible = true }
        .onDisappear { visible = false }
    }
}

/// Encuadre de cámara con una hoja (receta) o una caja dentro.
struct IlustracionEncuadre: View {
    let esReceta: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(esReceta ? Paleta.durazno : Paleta.lavanda)
                .frame(width: 200, height: 200)
                .offset(x: -60, y: -20)
            Circle()
                .fill(Paleta.agua)
                .frame(width: 90, height: 90)
                .offset(x: 95, y: -95)
            if esReceta {
                VStack(alignment: .leading, spacing: 12) {
                    Capsule().fill(Paleta.tinta).frame(width: 70, height: 6)
                    ForEach([1.0, 0.8, 0.92, 0.6, 0.85], id: \.self) { ancho in
                        Capsule().fill(Paleta.base200).frame(width: 110 * ancho, height: 6)
                    }
                    Spacer(minLength: 0)
                    Capsule().fill(Paleta.base300).frame(width: 54, height: 6)
                }
                .padding(20)
                .frame(width: 150, height: 196, alignment: .topLeading)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.white))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Paleta.tinta, lineWidth: 1.5))
                .rotationEffect(.degrees(-4))
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "pills")
                        .font(.system(size: 44, weight: .ultraLight))
                    Capsule().fill(Paleta.tinta).frame(width: 80, height: 6)
                    Capsule().fill(Paleta.base200).frame(width: 50, height: 6)
                }
                .foregroundStyle(Paleta.tinta)
                .frame(width: 190, height: 130)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.white))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Paleta.tinta, lineWidth: 1.5))
                .rotationEffect(.degrees(-3))
            }
            EsquinasEncuadre()
                .stroke(Paleta.acento, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .frame(width: 230, height: 250)
        }
        .frame(height: 270)
        .accessibilityHidden(true)
    }
}

/// Cuatro esquinas de encuadre de cámara.
struct EsquinasEncuadre: Shape {
    func path(in r: CGRect) -> Path {
        let l: CGFloat = 30
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY + l)); p.addLine(to: CGPoint(x: r.minX, y: r.minY)); p.addLine(to: CGPoint(x: r.minX + l, y: r.minY))
        p.move(to: CGPoint(x: r.maxX - l, y: r.minY)); p.addLine(to: CGPoint(x: r.maxX, y: r.minY)); p.addLine(to: CGPoint(x: r.maxX, y: r.minY + l))
        p.move(to: CGPoint(x: r.maxX, y: r.maxY - l)); p.addLine(to: CGPoint(x: r.maxX, y: r.maxY)); p.addLine(to: CGPoint(x: r.maxX - l, y: r.maxY))
        p.move(to: CGPoint(x: r.minX + l, y: r.maxY)); p.addLine(to: CGPoint(x: r.minX, y: r.maxY)); p.addLine(to: CGPoint(x: r.minX, y: r.maxY - l))
        return p
    }
}

/// Cámara del sistema (UIImagePickerController).
struct CamaraSistema: UIViewControllerRepresentable {
    let alTomar: (UIImage) -> Void
    let alCancelar: () -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinador { Coordinador(alTomar: alTomar, alCancelar: alCancelar) }

    final class Coordinador: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let alTomar: (UIImage) -> Void
        let alCancelar: () -> Void

        init(alTomar: @escaping (UIImage) -> Void, alCancelar: @escaping () -> Void) {
            self.alTomar = alTomar
            self.alCancelar = alCancelar
        }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let foto = info[.originalImage] as? UIImage {
                alTomar(foto)
            } else {
                alCancelar()
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            alCancelar()
        }
    }
}
