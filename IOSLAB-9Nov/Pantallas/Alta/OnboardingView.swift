import SwiftUI
import SwiftData

/// Primera vez: 4 pantallas que muestran cómo funciona MiMi y una entrevista corta
/// (nombre y rutina) que se puede contestar hablando. Sin cuenta ni registro.
/// `alTerminar(true)` lleva a la pestaña Agregar para tomarle foto a la receta.
struct OnboardingView: View {
    let alTerminar: (_ agregarAhora: Bool) -> Void

    private enum Paso: Int, CaseIterable {
        case hola, receta, aviso, dia, letra, nombre, rutina, listo
    }

    @Environment(\.modelContext) private var contexto
    @State private var paso: Paso = .hola
    @State private var avanzando = true

    // Entrevista
    @State private var nombre = ""
    @State private var desayuno = Perfil.sugerido.desayuno
    @State private var comida = Perfil.sugerido.comida
    @State private var cena = Perfil.sugerido.cena
    @State private var dormir = Perfil.sugerido.dormir
    @State private var entendidos: Set<Momento> = []
    @State private var transcripcionRutina: String?
    @State private var procesando = false
    @State private var dictado = Dictado()
    @FocusState private var nombreEnfocado: Bool

    var body: some View {
        VStack(spacing: 0) {
            barraSuperior
            // El contenido ocupa todo el alto disponible y queda centrado (sin media pantalla en blanco).
            GeometryReader { geo in
                ScrollView {
                    contenido(alto: geo.size.height)
                        .id(paso)
                        .transition(.asymmetric(
                            insertion: .move(edge: avanzando ? .trailing : .leading).combined(with: .opacity),
                            removal: .move(edge: avanzando ? .leading : .trailing).combined(with: .opacity)))
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .frame(minHeight: geo.size.height, alignment: .center)
                }
                .scrollBounceBehavior(.basedOnSize)
                .scrollDismissesKeyboard(.interactively)
            }
            barraInferior
        }
        .background(Paleta.fondo.ignoresSafeArea())
        .onChange(of: dictado.texto) { _, texto in
            if paso == .nombre { nombre = texto }
        }
        .onChange(of: dictado.transcribiendo) { antes, ahora in
            // Al terminar de transcribir la rutina, el modelo propone las horas.
            if antes && !ahora && paso == .rutina { Task { await entenderRutina(dictado.texto) } }
        }
        .onDisappear { dictado.detener() }
        .onAppear(perform: cargarPerfil)
    }

    /// Si quedaron datos de ejemplo de una prueba anterior, se borran: el onboarding empieza limpio.
    /// Si ya había un perfil real, se precargan su nombre y sus horas.
    private func cargarPerfil() {
        guard let perfil = Almacen.perfil(en: contexto) else { return }
        if perfil.esDemo {
            DatosDemo.borrarTodo(en: contexto)
            return
        }
        nombre = perfil.nombre
        desayuno = perfil.desayunoMin
        comida = perfil.comidaMin
        cena = perfil.cenaMin
        dormir = perfil.dormirMin
    }

    // MARK: Barras

    private var barraSuperior: some View {
        HStack {
            if paso != .hola {
                Button {
                    ir(Paso(rawValue: paso.rawValue - 1) ?? .hola, adelante: false)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Paleta.tinta)
                        .frame(width: 48, height: 48)
                }
                .accessibilityLabel("Atrás")
            }
            Spacer()
            if paso.rawValue < Paso.letra.rawValue {
                Button("Saltar") { ir(.letra) }
                    .font(Tipo.etiqueta)
                    .foregroundStyle(Paleta.tintaSuave)
                    .frame(minHeight: 48)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 52)
    }

    @ViewBuilder private var barraInferior: some View {
        if paso == .listo {
            VStack(spacing: 10) {
                BotonGrande(titulo: "Tomarle foto a mi receta", icono: "camera") { alTerminar(true) }
                BotonGrande(titulo: "Lo hago después", estilo: .texto) { alTerminar(false) }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 8)
        } else {
            HStack {
                IndicadorPaso(actual: paso.rawValue + 1, total: Paso.allCases.count)
                Spacer()
                if procesando || dictado.transcribiendo {
                    ProgressView().controlSize(.large).tint(Paleta.tinta).frame(width: 64, height: 64)
                } else {
                    BotonFlecha(etiqueta: paso == .rutina ? "Guardar y seguir" : "Siguiente") {
                        Task { await avanzar() }
                    }
                    .disabled(dictado.escuchando)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
        }
    }

    // MARK: Contenido

    @ViewBuilder private func contenido(alto: CGFloat) -> some View {
        let ilusAlto = max(300, alto * 0.64)
        switch paso {
        case .hola:
            presentacion(ilus: Ilustracion(nombre: "ilus-bienvenida", simbolo: "hand.wave", color: Paleta.durazno, color2: Paleta.agua),
                         alto: ilusAlto,
                         titulo: "Hola, soy MiMi",
                         texto: "Te ayudo a tomar tus medicinas a tiempo, sin tener que recordar horarios ni nombres.") { EmptyView() }
        case .receta:
            presentacion(ilus: Ilustracion(nombre: "ilus-receta", simbolo: "doc.text.viewfinder", color: Paleta.lavanda, color2: Paleta.durazno),
                         alto: ilusAlto,
                         titulo: "Tómale foto a tu receta",
                         texto: "Leo tus medicinas en tu iPhone. Tú revisas que todo esté bien antes de guardar.") { EmptyView() }
        case .aviso:
            presentacion(ilus: Ilustracion(nombre: "ilus-aviso", simbolo: "alarm", color: Paleta.sol, color2: Paleta.lavanda),
                         alto: ilusAlto,
                         titulo: "Te aviso a la hora",
                         texto: "Suena una alarma con el nombre que tú le pones a cada medicina. Tocas «Ya me la tomé» y listo.") { EmptyView() }
        case .dia:
            presentacion(ilus: Ilustracion(nombre: "ilus-tudia", simbolo: "calendar", color: Paleta.agua, color2: Paleta.sol),
                         alto: ilusAlto,
                         titulo: "Tu día en una vista",
                         texto: "Ves qué te toca, qué ya tomaste y qué sigue. Sin cuenta ni contraseña: todo se queda en tu iPhone.") { EmptyView() }
        case .letra:
            preguntaLetra
        case .nombre:
            preguntaNombre(ilusAlto: max(220, alto * 0.4))
        case .rutina:
            preguntaRutina
        case .listo:
            presentacion(ilus: Ilustracion(nombre: "ilus-listo", simbolo: "checkmark.seal", color: Paleta.salvia, color2: Paleta.durazno),
                         alto: ilusAlto,
                         titulo: nombre.isEmpty ? "¡Listo!" : "¡Listo, \(nombre)!",
                         texto: "Ahora agrega tu primera medicina. Con una foto de tu receta armo tu día.") { EmptyView() }
        }
    }

    private func presentacion<Extra: View>(ilus: Ilustracion, alto: CGFloat, titulo: String, texto: String,
                                           @ViewBuilder extra: () -> Extra) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            ilus.conAlto(alto).padding(.horizontal, -24).padding(.bottom, 4)
            Text(titulo)
                .font(Tipo.grande)
                .foregroundStyle(Paleta.tinta)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text(texto)
                .font(.title3)
                .foregroundStyle(Paleta.tintaSuave)
                .fixedSize(horizontal: false, vertical: true)
            extra()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Tamaño de letra: cada opción se ve con su tamaño y la vista previa cambia al momento.
    private var preguntaLetra: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("¿De qué tamaño lees mejor?")
                .font(Tipo.pregunta)
                .foregroundStyle(Paleta.tinta)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text("Toca una opción y mira cómo cambia. Puedes cambiarlo después en Perfil.")
                .font(.title3)
                .foregroundStyle(Paleta.tintaSuave)
                .fixedSize(horizontal: false, vertical: true)
            SelectorTamanoLetra()
            VStack(alignment: .leading, spacing: 6) {
                Text("Así se verá").estiloMayusculas()
                Text("La de la presión")
                    .font(Tipo.tarjeta)
                    .foregroundStyle(Paleta.tinta)
                Text("1 tableta · con el desayuno, 8:00 a. m.")
                    .font(.body)
                    .foregroundStyle(Paleta.tinta)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .tarjeta(relleno: 20, color: Paleta.durazno)
            .accessibilityElement(children: .combine)
        }
    }

    private func preguntaNombre(ilusAlto: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            Ilustracion(nombre: "ilus-nombre", simbolo: "person.wave.2", color: Paleta.durazno, color2: Paleta.lavanda, alto: ilusAlto)
                .padding(.horizontal, -24)
            Text("¿Cómo te gusta que te llame?")
                .font(Tipo.pregunta)
                .foregroundStyle(Paleta.tinta)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text("Escríbelo o dímelo con tu voz.")
                .font(.title3)
                .foregroundStyle(Paleta.tintaSuave)
            TextField("Tu nombre", text: $nombre)
                .font(.system(.title2, design: .serif, weight: .semibold))
                .foregroundStyle(Paleta.tinta)
                .textContentType(.givenName)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .submitLabel(.next)
                .focused($nombreEnfocado)
                .onSubmit { Task { await avanzar() } }
                .padding(.horizontal, 18)
                .frame(minHeight: 66)
                .overlay(RoundedRectangle(cornerRadius: Radio.control, style: .continuous)
                    .strokeBorder(nombreEnfocado ? Paleta.marcaFuerte : Paleta.borde, lineWidth: nombreEnfocado ? 2 : 1.2))
            BotonVoz(dictado: dictado, titulo: "Decirlo con mi voz")
        }
    }

    private var preguntaRutina: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("¿A qué hora haces cada cosa?")
                .font(Tipo.pregunta)
                .foregroundStyle(Paleta.tinta)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
                .padding(.top, 8)
            Text("Con estas horas te aviso. Ya puse las más comunes.")
                .font(.title3)
                .foregroundStyle(Paleta.tintaSuave)
                .fixedSize(horizontal: false, vertical: true)
            BotonVoz(dictado: dictado, titulo: "Contármelo con mi voz",
                     ayuda: "Por ejemplo: «desayuno a las 8, como a las 3 y me duermo a las 11».")
                .disabled(procesando)
            if let transcripcionRutina, !procesando && !dictado.escuchando && !dictado.transcribiendo {
                let mensaje = entendidos.isEmpty
                    ? "No pude identificar tus horarios. Puedes volver a hablar o ajustar las horas aquí."
                    : "Revisa las horas marcadas. Puedes ajustar las demás aquí."
                Label(mensaje, systemImage: entendidos.isEmpty ? "info.circle" : "sparkles")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Paleta.tinta)
                    .tarjeta(relleno: 14, color: Paleta.acentoSuave)
                DisclosureGroup("Ver lo que escuché") {
                    Text(transcripcionRutina)
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .foregroundStyle(Paleta.tinta)
                .frame(minHeight: 44)
            }
            VStack(spacing: 0) {
                FilaHora(momento: .desayuno, minutos: $desayuno, resaltar: entendidos.contains(.desayuno))
                Divider().padding(.vertical, 8)
                FilaHora(momento: .comida, minutos: $comida, resaltar: entendidos.contains(.comida))
                Divider().padding(.vertical, 8)
                FilaHora(momento: .cena, minutos: $cena, resaltar: entendidos.contains(.cena))
                Divider().padding(.vertical, 8)
                FilaHora(momento: .dormir, minutos: $dormir, resaltar: entendidos.contains(.dormir))
            }
            .padding(18)
            .overlay(RoundedRectangle(cornerRadius: Radio.tarjeta, style: .continuous).strokeBorder(Paleta.borde, lineWidth: 1.2))
        }
    }

    // MARK: Acciones

    private func ir(_ nuevo: Paso, adelante: Bool = true) {
        dictado.detener()
        avanzando = adelante
        withAnimation(.snappy(duration: 0.35)) { paso = nuevo }
    }

    private func avanzar() async {
        switch paso {
        case .nombre:
            let dicho = nombre.trimmingCharacters(in: .whitespacesAndNewlines)
            if !dicho.isEmpty {
                procesando = true
                nombre = await LectorEntrevista.nombre(de: dicho)
                procesando = false
            }
            nombreEnfocado = false
            ir(.rutina)
        case .rutina:
            guardarPerfil()
            ir(.listo)
        case .listo:
            alTerminar(false)
        default:
            ir(Paso(rawValue: paso.rawValue + 1) ?? .nombre)
        }
    }

    private func entenderRutina(_ texto: String) async {
        guard !texto.isEmpty else { return }
        transcripcionRutina = texto
        procesando = true
        defer { procesando = false }
        let horas = await LectorEntrevista.rutina(de: texto)
        guard paso == .rutina else { return }
        withAnimation {
            if let m = horas[.desayuno] { desayuno = m }
            if let m = horas[.comida] { comida = m }
            if let m = horas[.cena] { cena = m }
            if let m = horas[.dormir] { dormir = m }
            entendidos = Set(horas.keys)
        }
    }

    private func guardarPerfil() {
        let limpio = nombre.trimmingCharacters(in: .whitespacesAndNewlines)
        if let perfil = Almacen.perfil(en: contexto) {
            perfil.nombre = limpio
            perfil.desayunoMin = desayuno
            perfil.comidaMin = comida
            perfil.cenaMin = cena
            perfil.dormirMin = dormir
            perfil.esDemo = false
        } else {
            contexto.insert(Perfil(nombre: limpio, desayunoMin: desayuno, comidaMin: comida, cenaMin: cena, dormirMin: dormir))
        }
        try? contexto.save()
    }
}

/// Botón de micrófono con sus tres estados: listo, escuchando y entendiendo.
struct BotonVoz: View {
    let dictado: Dictado
    let titulo: String
    var ayuda: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                Task { await dictado.alternar() }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: dictado.escuchando ? "stop.fill" : "mic.fill")
                        .font(.title3)
                        .foregroundStyle(dictado.escuchando ? Color.white : Paleta.tinta)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(dictado.escuchando ? Paleta.acento : Paleta.marcaSuave))
                        .symbolEffect(.pulse, isActive: dictado.escuchando)
                    Text(dictado.escuchando ? "Te escucho… cuando dejes de hablar, me detengo solo"
                         : dictado.transcribiendo ? "Entendiendo lo que dijiste…" : titulo)
                        .font(Tipo.etiqueta)
                        .foregroundStyle(Paleta.tinta)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .padding(10)
                .frame(minHeight: 64)
                .background(RoundedRectangle(cornerRadius: Radio.control, style: .continuous).fill(Paleta.tarjeta))
            }
            .buttonStyle(EstiloPresionable())
            .disabled(dictado.transcribiendo)
            .accessibilityHint(dictado.escuchando ? "Se detiene solo al terminar de hablar. También puedes tocar para terminar" : "Toca para responder hablando")
            if let error = dictado.error {
                Label(error, systemImage: "exclamationmark.circle")
                    .font(.body)
                    .foregroundStyle(Paleta.tintaSuave)
            } else if let ayuda {
                Text(ayuda)
                    .font(.body)
                    .foregroundStyle(Paleta.tintaSuave)
            }
        }
    }
}

#Preview("Onboarding") {
    OnboardingView { _ in }
        .modelContainer(for: [Perfil.self, Medicamento.self, RegistroToma.self], inMemory: true)
}

private extension Ilustracion {
    /// Misma ilustración con otro alto (para llenar la pantalla del onboarding).
    func conAlto(_ alto: CGFloat) -> Ilustracion {
        var copia = self
        copia.alto = alto
        return copia
    }
}
