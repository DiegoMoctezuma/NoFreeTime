import SwiftUI
import SwiftData

/// Perfil: tus medicinas, tu nombre y rutina, la IA (encender o apagar), privacidad y datos de ejemplo.
struct PerfilView: View {
    @Query private var perfiles: [Perfil]

    var body: some View {
        NavigationStack {
            Group {
                if let perfil = perfiles.first {
                    PerfilContenido(perfil: perfil)
                } else {
                    Color.clear
                }
            }
            .background(Paleta.fondo.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

private struct PerfilContenido: View {
    @Bindable var perfil: Perfil

    @Query(filter: #Predicate<Medicamento> { $0.activo }, sort: \Medicamento.nombre) private var activos: [Medicamento]
    @Environment(\.modelContext) private var contexto
    @AppStorage(ClavesApp.altaTerminada) private var altaTerminada = false
    @AppStorage(ClavesApp.usarIA) private var usarIA = true
    @AppStorage(ClavesApp.permitirNube) private var permitirNube = true
    @AppStorage(ClavesApp.leerEnVoz) private var leerEnVoz = false
    @State private var confirmarEjemplo = false
    @State private var confirmarBorrar = false
    @State private var tareaReprogramar: Task<Void, Never>?
    @State private var mensajePrueba: String?
    @State private var probando = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                encabezado
                    .entradaMiMi()

                SeccionMedicinas()
                    .entradaMiMi(orden: 1)

                SeccionNotas()
                    .entradaMiMi(orden: 2)

                seccion("Tu nombre") {
                    TextField("Tu nombre", text: $perfil.nombre)
                        .font(.system(.title3, design: .serif, weight: .semibold))
                        .foregroundStyle(Paleta.tinta)
                        .textContentType(.givenName)
                        .submitLabel(.done)
                        .onSubmit { try? contexto.save() }
                        .padding(.horizontal, 18)
                        .frame(minHeight: 60)
                        .overlay(RoundedRectangle(cornerRadius: Radio.control, style: .continuous)
                            .strokeBorder(Paleta.borde, lineWidth: 1.2))
                }

                seccion("Tu rutina", nota: "Si cambias una hora, muevo tus avisos.") {
                    VStack(spacing: 0) {
                        FilaHora(momento: .desayuno, minutos: $perfil.desayunoMin)
                        Divider().padding(.vertical, 8)
                        FilaHora(momento: .comida, minutos: $perfil.comidaMin)
                        Divider().padding(.vertical, 8)
                        FilaHora(momento: .cena, minutos: $perfil.cenaMin)
                        Divider().padding(.vertical, 8)
                        FilaHora(momento: .dormir, minutos: $perfil.dormirMin)
                    }
                    .padding(18)
                    .overlay(RoundedRectangle(cornerRadius: Radio.tarjeta, style: .continuous).strokeBorder(Paleta.borde, lineWidth: 1.2))
                }

                seccion("Tamaño de letra", nota: "Cambia el tamaño en toda la app.") {
                    SelectorTamanoLetra()
                }

                seccion("Leer en voz alta") {
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle(isOn: $leerEnVoz) {
                            Text("Leer cada medicina cuando reviso una receta")
                                .font(Tipo.etiqueta)
                                .foregroundStyle(Paleta.tinta)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .tint(Paleta.acento)
                        Text("Siempre puedes tocar la bocina para que te lea una tarjeta.")
                            .font(.body)
                            .foregroundStyle(Paleta.tinta)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(18)
                    .overlay(RoundedRectangle(cornerRadius: Radio.tarjeta, style: .continuous).strokeBorder(Paleta.borde, lineWidth: 1.2))
                }

//                seccion("Lectura con Apple Intelligence") {
//                    VStack(alignment: .leading, spacing: 12) {
//                        Toggle(isOn: $usarIA) {
//                            Text("Leer recetas y cajas con fotos")
//                                .font(Tipo.etiqueta)
//                                .foregroundStyle(Paleta.tinta)
//                        }
//                        .tint(Paleta.acento)
//                        Text(textoIA)
//                            .font(.body)
//                            .foregroundStyle(Paleta.tintaSuave)
//                            .fixedSize(horizontal: false, vertical: true)
//                        if usarIA && ServicioDeepSeek.configurado {
//                            Divider()
//                            Toggle(isOn: $permitirNube) {
//                                Text("Leer con DeepSeek por internet")
//                                    .font(Tipo.etiqueta)
//                                    .foregroundStyle(Paleta.tinta)
//                                    .fixedSize(horizontal: false, vertical: true)
//                            }
//                            .tint(Paleta.acento)
//                            Text("DeepSeek recibe el texto de tu receta, que puede incluir tu nombre, y datos de tus medicinas y rutina. La foto se queda en el iPhone. Puedes apagar esta opción cuando quieras.")
//                                .font(.subheadline)
//                                .foregroundStyle(Paleta.tintaSuave)
//                                .fixedSize(horizontal: false, vertical: true)
//                        }
//                    }
//                    .tarjeta(relleno: 18)
//                }

                seccion("Tu información") {
                    Label("No hay cuenta ni contraseña. Tus fotos y registros se guardan en este iPhone.",
                          systemImage: "lock")
                        .font(.body)
                        .foregroundStyle(Paleta.tinta)
                        .fixedSize(horizontal: false, vertical: true)
                        .tarjeta(relleno: 18, color: Paleta.salvia)
                }

                seccion("Datos de ejemplo", nota: perfil.esDemo ? "Estás viendo los datos ficticios de don Ernesto." : nil) {
                    VStack(spacing: 10) {
                        BotonGrande(titulo: "Cargar datos de ejemplo", icono: "tray.and.arrow.down", estilo: .secundario) {
                            confirmarEjemplo = true
                        }
                        BotonGrande(titulo: "Borrar todo y empezar de nuevo", estilo: .texto) {
                            confirmarBorrar = true
                        }
                    }
                }

                if mostrarPruebas {
                    seccion("Para el demo") {
                        VStack(spacing: 10) {
                            BotonGrande(titulo: "Probar alarma en 10 segundos", icono: "alarm.fill", estilo: .secundario) {
                                Task { await probarAviso(.alarma) }
                            }
                            .disabled(probando)
                            BotonGrande(titulo: "Probar notificación en 10 segundos", icono: "bell.fill", estilo: .secundario) {
                                Task { await probarAviso(.recordatorio) }
                            }
                            .disabled(probando)
                            if let mensajePrueba {
                                Text(mensajePrueba)
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(Paleta.tinta)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            NavigationLink {
                                ComoTeAvisoView(medicamentos: activos) {}
                            } label: {
                                EtiquetaBoton(titulo: "Probar avisos", icono: "alarm", estilo: .secundario)
                            }
                            .buttonStyle(EstiloBotonGrande(estilo: .secundario))
                            #if DEBUG
                            NavigationLink {
                                PruebaLectorView()
                            } label: {
                                EtiquetaBoton(titulo: "Probar lector de receta y caja", icono: "doc.text.viewfinder", estilo: .secundario)
                            }
                            .buttonStyle(EstiloBotonGrande(estilo: .secundario))
                            #endif
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .scrollDismissesKeyboard(.interactively)
        .onChange(of: rutina) { _, _ in programarCambio() }
        .confirmationDialog("¿Cargar los datos de ejemplo?", isPresented: $confirmarEjemplo, titleVisibility: .visible) {
            Button("Cargar ejemplo") { Task { await cargarEjemplo() } }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Se reemplaza lo que tienes por los datos ficticios de don Ernesto.")
        }
        .confirmationDialog("¿Borrar todo?", isPresented: $confirmarBorrar, titleVisibility: .visible) {
            Button("Borrar todo", role: .destructive) { Task { await borrarTodo() } }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Se borran tus medicinas, tus tomas y tu rutina de este iPhone.")
        }
    }

    private var encabezado: some View {
        HStack(spacing: 16) {
            Text(inicial)
                .font(.system(.title, design: .serif, weight: .semibold))
                .foregroundStyle(Paleta.tinta)
                .frame(width: 72, height: 72)
                .background(Circle().fill(Paleta.durazno))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("Perfil").estiloMayusculas()
                Text(perfil.nombre.isEmpty ? "Tu perfil" : perfil.nombre)
                    .font(Tipo.grande)
                    .foregroundStyle(Paleta.tinta)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
            }
        }
        .padding(.top, 20)
    }

    private var inicial: String {
        perfil.nombre.trimmingCharacters(in: .whitespaces).first.map { String($0).uppercased() } ?? "M"
    }

    private var textoIA: String {
        if !usarIA {
            return "Apagada. Agregas tus medicinas escribiéndolas; todo lo demás funciona igual."
        }
        switch LectorIA.motor {
        case .apple:
            return "Encendida. Lee en tu iPhone, sin internet. Tú decides qué incluir al tocar «Guardar plan»."
        case .deepseek:
            return "Encendida. Lee con DeepSeek por internet. Tú decides qué incluir al tocar «Guardar plan»."
        case .ninguno:
            if case .noDisponible(let motivo) = LectorIA.disponibilidadApple {
                return motivo + " Mientras tanto, puedes escribir tus medicinas."
            }
            return "Puedes escribir tus medicinas."
        }
    }

    private var rutina: [Int] { [perfil.desayunoMin, perfil.comidaMin, perfil.cenaMin, perfil.dormirMin] }

    /// Demo (PRD A6): adelanta a 10 segundos la siguiente toma de la primera medicina, como alarma o como notificación.
    /// Para ver la alarma en pantalla completa, bloquear el iPhone después de tocar el botón.
    private func probarAviso(_ tipo: TipoAviso) async {
        guard let med = activos.first else {
            mensajePrueba = "Primero agrega una medicina."
            return
        }
        probando = true
        defer { probando = false }
        let servicio = ServicioAvisosSistema.compartido
        guard await servicio.pedirPermiso(para: tipo) == .concedido else {
            mensajePrueba = tipo == .alarma
                ? "Falta permitir las alarmas de MiMi en Ajustes del iPhone."
                : "Falta permitir las notificaciones de MiMi en Ajustes del iPhone."
            return
        }
        let tomas = Plan.tomas(de: med, perfil: perfil, desde: .now, dias: 2)
        guard let toma = tomas.first(where: { Registro.registro(idToma: $0.id, contexto: contexto) == nil }) ?? tomas.first else {
            mensajePrueba = "\(med.nombreVisible.capitalizedPrimera) no tiene tomas próximas."
            return
        }
        do {
            try await servicio.programarPrueba(med, toma: toma, segundos: 10, tipo: tipo)
            let que = tipo == .alarma ? "la alarma" : "la notificación"
            mensajePrueba = "Listo: en 10 segundos llega \(que) de \(med.nombreVisible). Bloquea el iPhone para verla completa."
        } catch {
            mensajePrueba = "No se pudo programar: \(error.localizedDescription)"
        }
    }

    /// Botones de prueba del demo (PRD A6): en DEBUG o con los datos de ejemplo.
    private var mostrarPruebas: Bool {
        #if DEBUG
        return true
        #else
        return perfil.esDemo
        #endif
    }

    private func seccion<C: View>(_ titulo: String, nota: String? = nil, @ViewBuilder contenido: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(titulo)
                .font(Tipo.tarjeta)
                .foregroundStyle(Paleta.tinta)
                .accessibilityAddTraits(.isHeader)
            if let nota {
                Text(nota).font(.body).foregroundStyle(Paleta.tintaSuave)
                    .fixedSize(horizontal: false, vertical: true)
            }
            contenido()
        }
    }

    /// Espera a que la persona deje de mover el selector antes de reprogramar.
    private func programarCambio() {
        try? contexto.save()
        tareaReprogramar?.cancel()
        tareaReprogramar = Task {
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            await Reprogramador.reprogramarTodo(contexto: contexto)
        }
    }

    private func cancelarAvisos() async {
        let meds = (try? contexto.fetch(FetchDescriptor<Medicamento>())) ?? []
        for med in meds { await ServicioAvisosSistema.compartido.cancelar(medicamentoID: med.id) }
    }

    private func cargarEjemplo() async {
        await cancelarAvisos()
        DatosDemo.cargar(en: contexto)
        altaTerminada = true
    }

    private func borrarTodo() async {
        await cancelarAvisos()
        altaTerminada = false
        DatosDemo.borrarTodo(en: contexto)
    }
}

#Preview("Perfil") {
    PerfilView()
        .modelContainer(Almacen.vistaPrevia())
        .environment(Navegacion.compartida)
}
