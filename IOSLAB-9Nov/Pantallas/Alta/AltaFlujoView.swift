import SwiftUI
import SwiftData

/// Pasos para agregar medicinas. Cada uno es una pantalla con una sola pregunta.
enum PasoAlta: Hashable {
    case leerReceta, leerCaja
    case cajaConocida(UUID)
    case sinRecetaNombre, sinRecetaVeces, sinRecetaCuando
    case propuesta
    case avisos
}

/// Lo que se va juntando mientras se agrega una medicina. Nada llega al tratamiento sin "Está bien".
@MainActor @Observable
final class ModeloAlta {
    // Propuesta por revisar (de la receta, de la caja o escrita a mano)
    var borradores: [Borrador] = []
    var vieneDeReceta = true

    // Sin receta o desde la caja
    var manualNombre = ""
    var manualConcentracion = ""
    var manualVeces = 1
    var manualMomentos: [Momento] = [.desayuno]
    var manualFoto: Data?
    var manualPastillas: Int?
    var manualDudosos: Set<String> = []
    var manualFuente: String?

    // Guardados al confirmar; van a "¿Cómo te aviso?"
    var guardados: [Medicamento] = []
    /// Qué consultó la IA antes de proponer (se muestra en la primera tarjeta).
    var consulta: String?
    /// Notas generales de la receta (dieta, cuidados, próxima cita), pendientes de confirmar.
    var notas: [String] = []

    func reiniciar() {
        borradores = []
        consulta = nil
        notas = []
        manualNombre = ""
        manualConcentracion = ""
        manualVeces = 1
        manualMomentos = [.desayuno]
        manualFoto = nil
        manualPastillas = nil
        manualDudosos = []
        manualFuente = nil
        guardados = []
    }
}

/// Pestaña "Agregar" (WP-03, CONTRATOS §7): receta, caja o escribirla. Sin cuenta ni registro.
struct AltaFlujoView: View {
    let alTerminar: () -> Void

    @Environment(\.modelContext) private var contexto
    @Environment(Navegacion.self) private var navegacion
    @AppStorage(ClavesApp.usarIA) private var usarIA = true
    @AppStorage(ClavesApp.permitirNube) private var permitirNube = false
    @State private var modelo = ModeloAlta()
    @State private var ruta: [PasoAlta] = []
    @State private var lector = LectorIA()

    init(alTerminar: @escaping () -> Void) {
        self.alTerminar = alTerminar
    }

    var body: some View {
        NavigationStack(path: $ruta) {
            inicio
                .entradaMiMi()
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(for: PasoAlta.self) { paso in
                    destino(paso)
                        .navigationBarTitleDisplayMode(.inline)
                }
        }
        .environment(modelo)
        .environment(lector)
        .tint(Paleta.tinta)
        .onAppear {
            if usarIA { lector.preparar(tratamiento: Almacen.medicamentosActivos(en: contexto)) }
        }
    }

    // MARK: Inicio de la pestaña

    private var inicio: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Agregar medicina")
                        .font(Tipo.grande)
                        .foregroundStyle(Paleta.tinta)
                        .accessibilityAddTraits(.isHeader)
                    Text("Elige cómo quieres hacerlo. Siempre revisas antes de guardar.")
                        .font(.title3)
                        .foregroundStyle(Paleta.tintaSuave)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 20)

                TarjetaCamino(titulo: "Mi receta",
                              detalle: "Le tomo foto y leo todas tus medicinas.",
                              ilustracion: Ilustracion(nombre: "ilus-receta", simbolo: "doc.text.viewfinder",
                                                       color: Paleta.fondo.opacity(0.5), color2: Paleta.fondo.opacity(0.4), alto: 120),
                              color: Paleta.agua,
                              habilitada: iaLista) {
                    modelo.reiniciar()
                    modelo.vieneDeReceta = true
                    ruta.append(.leerReceta)
                }

                TarjetaCamino(titulo: "La caja de la medicina",
                              detalle: "Le tomo foto a la caja para saber cuál es.",
                              ilustracion: Ilustracion(nombre: "ilus-caja", simbolo: "shippingbox",
                                                       color: Paleta.fondo.opacity(0.5), color2: Paleta.fondo.opacity(0.4), alto: 120),
                              color: Paleta.durazno,
                              habilitada: iaLista) {
                    modelo.reiniciar()
                    modelo.vieneDeReceta = false
                    ruta.append(.leerCaja)
                }

                TarjetaOpcion(icono: "square.and.pencil", titulo: "Escribirla yo",
                              detalle: "Te pregunto el nombre y cuándo la tomas.") {
                    modelo.reiniciar()
                    modelo.vieneDeReceta = false
                    ruta.append(.sinRecetaNombre)
                }

//                notaIA
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .background(Paleta.fondo.ignoresSafeArea())
    }

    /// Qué hace la IA, dónde corre y cómo apagarla (HCAI: antes de usarla).
    @ViewBuilder private var notaIA: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Cómo leo tus fotos").estiloMayusculas()
            if !usarIA {
                Text("Apagaste la lectura con Apple Intelligence. Puedes agregar tus medicinas escribiéndolas o volver a encenderla en Perfil.")
                    .font(.body)
                    .foregroundStyle(Paleta.tinta)
                    .fixedSize(horizontal: false, vertical: true)
            } else if case .noDisponible(let motivo) = LectorIA.disponibilidad {
                Text("\(motivo) Mientras tanto, puedes escribir tus medicinas.")
                    .font(.body)
                    .foregroundStyle(Paleta.tinta)
                    .fixedSize(horizontal: false, vertical: true)
                if !permitirNube && ServicioDeepSeek.configurado {
                    BotonGrande(titulo: "Opciones de lectura en Perfil", estilo: .texto) {
                        navegacion.pestana = .perfil
                    }
                }
            } else if LectorIA.motor == .deepseek {
                paso("1", "Tu iPhone reconoce el texto de la foto.")
                paso("2", "DeepSeek ordena ese texto por internet: nombre, dosis y horario.")
                paso("3", "Reviso que cada dato esté escrito en la foto; lo que no encuentro te lo marco en amarillo.")
                Label("DeepSeek recibe el texto de tu receta, que puede incluir tu nombre, y datos de tus medicinas y rutina. La foto se queda en el iPhone. Puedes cambiarlo en Perfil.", systemImage: "network")
                    .font(.body)
                    .foregroundStyle(Paleta.tintaSuave)
                    .padding(.top, 4)
            } else {
                paso("1", "Tu iPhone reconoce el texto de la foto.")
                paso("2", "Apple Intelligence lo ordena: nombre, dosis y horario.")
                paso("3", "Reviso que cada dato esté escrito en la foto; lo que no encuentro te lo marco en amarillo.")
                Label("Todo pasa en tu iPhone, sin internet. Nada sale de tu teléfono.", systemImage: "lock")
                    .font(.body)
                    .foregroundStyle(Paleta.tintaSuave)
                    .padding(.top, 4)
            }
        }
        .tarjeta(relleno: 18)
    }

    private func paso(_ n: String, _ texto: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(n)
                .font(.body.weight(.bold))
                .foregroundStyle(Paleta.tinta)
                .frame(width: 28, height: 28)
                .background(Circle().fill(Paleta.fondo))
            Text(texto)
                .font(.body)
                .foregroundStyle(Paleta.tinta)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    private var iaLista: Bool {
        guard usarIA, case .disponible = LectorIA.disponibilidad else { return false }
        return true
    }

    // MARK: Destinos

    @ViewBuilder private func destino(_ paso: PasoAlta) -> some View {
        switch paso {
        case .leerReceta:
            LeerFotoView(modo: .receta,
                         alLeer: { ruta.append(.propuesta) },
                         alConocer: { _ in },
                         sinReceta: { reemplazarUltimo(con: .sinRecetaNombre) })
        case .leerCaja:
            LeerFotoView(modo: .caja,
                         alLeer: { ruta.append(.sinRecetaVeces) },
                         alConocer: { id in reemplazarUltimo(con: .cajaConocida(id)) },
                         sinReceta: { reemplazarUltimo(con: .sinRecetaNombre) })
        case .cajaConocida(let id):
            CajaConocidaView(medicamentoID: id, alTerminar: terminar)
        case .sinRecetaNombre:
            SinRecetaNombreView { ruta.append(.sinRecetaVeces) }
        case .sinRecetaVeces:
            SinRecetaVecesView { ruta.append(.sinRecetaCuando) }
        case .sinRecetaCuando:
            SinRecetaCuandoView { ruta.append(.propuesta) }
        case .propuesta:
            PropuestaView { guardados in
                if guardados.isEmpty { terminar() } else { ruta.append(.avisos) }
            }
        case .avisos:
            ComoTeAvisoView(medicamentos: modelo.guardados, alTerminar: terminar)
                .navigationBarBackButtonHidden(true)
        }
    }

    private func reemplazarUltimo(con paso: PasoAlta) {
        if !ruta.isEmpty { ruta.removeLast() }
        ruta.append(paso)
    }

    /// Vuelve al inicio de la pestaña y avisa (ContentView lleva a Hoy).
    private func terminar() {
        ruta.removeAll()
        modelo.reiniciar()
        alTerminar()
    }
}

/// Tarjeta pastel grande con ilustración, como las de la referencia.
struct TarjetaCamino: View {
    let titulo: String
    let detalle: String
    let ilustracion: Ilustracion
    let color: Color
    var habilitada = true
    let accion: () -> Void

    @Environment(\.dynamicTypeSize) private var tamano

    var body: some View {
        Button(action: accion) {
            HStack(alignment: .bottom, spacing: 0) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(titulo)
                        .font(Tipo.tarjeta)
                        .foregroundStyle(Paleta.tinta)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(detalle)
                        .font(.body)
                        .foregroundStyle(Paleta.tinta)
                        .fixedSize(horizontal: false, vertical: true)
                    if habilitada {
                        Image(systemName: "arrow.right")
                            .font(.headline)
                            .foregroundStyle(Color.white)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(Paleta.marcaFuerte))
                            .padding(.top, 6)
                            .accessibilityHidden(true)
                    } else {
                        // En lugar de atenuar el texto (difícil de leer), se dice por qué no está disponible.
                        Label("Ahora no está disponible. Puedes escribirla tú.", systemImage: "info.circle")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Paleta.tinta)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 6)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if !tamano.isAccessibilitySize {
                    ilustracion
                        .frame(width: 130)
                }
            }
            .padding(22)
            .frame(maxWidth: .infinity, minHeight: 170, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: Radio.tarjeta, style: .continuous).fill(color))
            .contentShape(RoundedRectangle(cornerRadius: Radio.tarjeta, style: .continuous))
        }
        .buttonStyle(EstiloPresionable())
        .disabled(!habilitada)
        .saturation(habilitada ? 1 : 0)
        .accessibilityElement(children: .combine)
        .accessibilityHint(habilitada ? "" : "No disponible ahora")
    }
}

/// La caja corresponde a una medicina que ya tienes: se ofrece guardar la foto como su ícono.
struct CajaConocidaView: View {
    let medicamentoID: UUID
    let alTerminar: () -> Void

    @Environment(\.modelContext) private var contexto
    @Environment(ModeloAlta.self) private var modelo

    var body: some View {
        if let med = Almacen.medicamento(id: medicamentoID, en: contexto) {
            PantallaPregunta(titulo: "Es tu \(med.nombreVisible)",
                             subtitulo: "Ya la tienes registrada: \(med.nombreTecnico).") {
                HStack(spacing: 16) {
                    IconoMedicamento(colorHex: med.colorHex, foto: modelo.manualFoto ?? med.fotoCaja, tamano: 96)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("\(med.dosis) · \(med.textoPauta)")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(Paleta.tinta)
                            .fixedSize(horizontal: false, vertical: true)
                        if let p = modelo.manualPastillas {
                            Text("La caja trae \(p) pastillas.")
                                .font(.body)
                                .foregroundStyle(Paleta.tintaSuave)
                        }
                    }
                }
                Text("Si guardas la foto, la vas a ver en Hoy y en Perfil para reconocerla.")
                    .font(.body)
                    .foregroundStyle(Paleta.tintaSuave)
            } botones: {
                BotonGrande(titulo: "Guardar la foto de la caja", icono: "checkmark") {
                    if let foto = modelo.manualFoto { med.fotoCaja = foto }
                    if let p = modelo.manualPastillas { med.pastillasPorCaja = p }
                    try? contexto.save()
                    alTerminar()
                }
                BotonGrande(titulo: "No, gracias", estilo: .texto, accion: alTerminar)
            }
        } else {
            Color.clear.onAppear(perform: alTerminar)
        }
    }
}
