import SwiftUI
import SwiftData

/// Medicamento propuesto que la persona revisa antes de guardarlo (RF-02).
/// Viene de la receta (IA) o del camino sin receta; en los dos casos se confirma igual.
struct Borrador: Identifiable, Equatable {
    let id: UUID
    var nombre: String
    var concentracion: String
    var dosis: String
    var tipoAccion: TipoAccionPlan = .toma
    var momentos: [Momento]
    var cadaHoras: Int?
    var rangoHoras: ClosedRange<Int>?
    var inicioIntervalo: Date?
    var duracionDias: Int?
    var indicaciones: String?
    /// Campos en amarillo (nombres de `MapeoIndicacion.camposRevisables`).
    var dudosos: Set<String>
    var yaRegistrado: Bool
    /// Renglón de la foto donde se leyó ("Esto dice tu receta"). Nil si se escribió a mano.
    var fuente: String?
    var foto: Data?
    var pastillas: Int?
    /// Por qué el modelo eligió esos momentos ("La receta dice cada 12 horas; lo acomodé a tu desayuno y tu cena").
    var motivoHorario: String?
    /// Posible cambio de receta: la medicina registrada con el mismo nombre y otra concentración.
    var cambioDe: UUID?
    var nombreAnterior: String?
    var decisionCambio: DecisionCambio = .pendiente

    enum DecisionCambio: Equatable { case pendiente, reemplazar, conservarAmbas }

    init(revisada: IndicacionRevisada) {
        let p = revisada.propuesta
        id = revisada.id
        nombre = p.nombre.trimmingCharacters(in: .whitespaces)
        concentracion = (p.concentracion ?? "").trimmingCharacters(in: .whitespaces)
        dosis = (p.dosis ?? "").trimmingCharacters(in: .whitespaces)
        tipoAccion = MapeoIndicacion.tipoAccion(de: p)
        momentos = MapeoIndicacion.momentos(de: p).momentos
        let rango = MapeoIndicacion.rangoHoras(de: p)
        rangoHoras = rango
        cadaHoras = rango == nil ? p.cadaHoras.flatMap { $0 > 0 ? $0 : nil } : nil
        duracionDias = p.duracionDias
        indicaciones = p.indicaciones
        dudosos = revisada.dudosos
        yaRegistrado = revisada.yaRegistrado
        fuente = revisada.fuente
        motivoHorario = cadaHoras == nil && rango == nil ? p.motivoHorario : nil
        cambioDe = revisada.cambioDe
        nombreAnterior = revisada.nombreAnterior
    }

    init(nombre: String, concentracion: String = "", dosis: String, momentos: [Momento],
         dudosos: Set<String> = [], fuente: String? = nil, foto: Data? = nil, pastillas: Int? = nil) {
        id = UUID()
        self.nombre = nombre
        self.concentracion = concentracion
        self.dosis = dosis
        self.momentos = momentos
        cadaHoras = nil
        duracionDias = nil
        indicaciones = nil
        self.dudosos = dudosos
        yaRegistrado = false
        self.fuente = fuente
        self.foto = foto
        self.pastillas = pastillas
    }

    func dudoso(_ campo: String) -> Bool { dudosos.contains(campo) }
    var tieneIntervalo: Bool { rangoHoras != nil || cadaHoras != nil }
    var faltaElegirIntervalo: Bool { rangoHoras != nil && cadaHoras == nil }
    var faltaPrimeraVez: Bool { tieneIntervalo && inicioIntervalo == nil }
    var momentosDudosos: Bool { dudoso("momentos") || dudoso("cadaHoras") || dudoso("horario") || faltaPrimeraVez }
    /// Solo falta confirmar el horario que propuso la IA (se resuelve con un toque, sin abrir "Cambiar").
    var soloConfirmarHorario: Bool { dudoso("horario") && !dudoso("momentos") && !momentos.isEmpty && cadaHoras == nil }
    /// Por qué no se puede guardar todavía, en palabras para la persona.
    var motivoPendiente: String {
        if dudoso("condicion") { return "depende de una condición" }
        if faltaElegirIntervalo { return "falta elegir cada cuántas horas" }
        if faltaPrimeraVez { return "falta indicar la primera vez" }
        if cambioDe != nil && decisionCambio == .pendiente { return "falta decir si es un cambio de tu doctor" }
        if dudosos == ["horario"] { return "falta confirmar el horario" }
        return "tiene datos por revisar"
    }
    var bloqueado: Bool {
        !dudosos.isEmpty || faltaElegirIntervalo || faltaPrimeraVez
            || (cadaHoras == nil && momentos.isEmpty)
            || (cambioDe != nil && decisionCambio == .pendiente)
    }

    var textoMomentos: String {
        guard !momentos.isEmpty else { return "Sin horario" }
        return momentos.map(\.texto).formatted(.list(type: .and).locale(Locale(identifier: "es_MX"))).capitalizedPrimera
    }

    var textoDuracion: String {
        guard let duracionDias else { return "Sin fecha de fin" }
        return duracionDias == 1 ? "1 día" : "\(duracionDias) días"
    }

    /// Lo que se lee en voz alta con 🔊.
    var lectura: String {
        var partes = [nombre]
        if !concentracion.isEmpty {
            partes[0] += " " + concentracion.replacingOccurrences(of: "mg", with: " miligramos")
        }
        if !dosis.isEmpty { partes.append(dosis) }
        if tipoAccion != .toma { partes.append(tipoAccion.titulo) }
        if !momentos.isEmpty { partes.append(momentos.map(\.texto).formatted(.list(type: .and).locale(Locale(identifier: "es_MX")))) }
        if let cadaHoras {
            partes.append(cadaHoras == 1 ? "cada hora" : "cada \(cadaHoras) horas")
            if let inicioIntervalo {
                partes.append("Primera vez: \(inicioIntervalo.formatted(date: .abbreviated, time: .shortened))")
            }
        } else if let rangoHoras {
            partes.append("Cada \(rangoHoras.lowerBound) a \(rangoHoras.upperBound) horas. Elige el intervalo.")
        }
        if let duracionDias { partes.append("durante \(duracionDias) días") }
        if let indicaciones, !indicaciones.isEmpty { partes.append(indicaciones) }
        return partes.joined(separator: ". ")
    }

    func medicamento(colorHex: String) -> Medicamento {
        Medicamento(nombre: nombre,
                    concentracion: concentracion.isEmpty || tipoAccion == .cuidado ? nil : concentracion,
                    colorHex: colorHex,
                    dosis: dosis,
                    tipoAccion: tipoAccion,
                    momentos: momentos,
                    cadaHoras: cadaHoras,
                    inicioIntervalo: inicioIntervalo,
                    duracionDias: duracionDias,
                    inicio: .now,
                    indicaciones: indicaciones,
                    aviso: .ninguno)
            .conFoto(foto, pastillas: pastillas)
    }
}

/// Una revisión compartida para las medicinas y notas de la receta.
struct PropuestaView: View {
    let alTerminar: ([Medicamento]) -> Void

    @Environment(ModeloAlta.self) private var modelo
    @Environment(\.modelContext) private var contexto
    @State private var editando: Borrador?
    @State private var guardado = false
    @State private var omitidos: Set<UUID> = []
    @State private var notasQuitadas: Set<String> = []
    @State private var errorAlGuardar = false
    @State private var confirmarSinPendientes = false

    private var elegibles: [Borrador] {
        modelo.borradores.filter { !$0.yaRegistrado && !omitidos.contains($0.id) }
    }

    private var notasVisibles: [String] {
        modelo.notas.filter { !notasQuitadas.contains($0) }
    }

    private var listos: [Borrador] { elegibles.filter { !$0.bloqueado } }
    private var pendientes: [Borrador] { elegibles.filter(\.bloqueado) }
    private var hayPendientes: Bool { !pendientes.isEmpty }
    private var nombresPendientes: String {
        pendientes.map(\.nombre).formatted(.list(type: .and).locale(Locale(identifier: "es_MX")))
    }
    private var puedeGuardar: Bool { !listos.isEmpty || !notasVisibles.isEmpty || elegibles.isEmpty }
    private var tituloGuardar: String {
        if hayPendientes { return "Guardar lo listo" }
        return elegibles.isEmpty && notasVisibles.isEmpty ? "Terminar" : "Guardar plan"
    }

    var body: some View {
        PantallaPregunta(titulo: "Tu plan", subtitulo: "Revisa lo que encontramos. Toca Cambiar si algo no coincide.") {
            if let consulta = modelo.consulta {
                Label(consulta, systemImage: "checklist")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Paleta.tinta)
                    .fixedSize(horizontal: false, vertical: true)
                    .tarjeta(relleno: 14, color: Paleta.salvia)
            }
            ForEach(Array(modelo.borradores.enumerated()), id: \.element.id) { i, borrador in
                if omitidos.contains(borrador.id) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("\(borrador.nombre): fuera de este plan.")
                        BotonGrande(titulo: "Volver a incluir", estilo: .texto) { omitidos.remove(borrador.id) }
                    }
                    .tarjeta()
                } else {
                    tarjeta(i, borrador)
                }
            }
            if !notasVisibles.isEmpty {
                pantallaNotas
            }
        } botones: {
            if hayPendientes && puedeGuardar {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(pendientes) { b in
                        Label("\(b.nombre) quedará fuera porque \(b.motivoPendiente).", systemImage: "exclamationmark.circle")
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .font(.body)
                .foregroundStyle(Paleta.tinta)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            BotonGrande(titulo: tituloGuardar, icono: "checkmark") {
                if hayPendientes { confirmarSinPendientes = true } else { guardar() }
            }
            .disabled(guardado || !puedeGuardar)
            .confirmationDialog("¿Guardar sin \(nombresPendientes)?", isPresented: $confirmarSinPendientes,
                                titleVisibility: .visible) {
                Button(pendientes.count == 1 ? "Guardar sin ella" : "Guardar sin ellas", action: guardar)
                Button("Seguir revisando", role: .cancel) {}
            } message: {
                Text("Podrás agregarlas después desde Agregar.")
            }
        }
        .sheet(item: $editando) { b in
            EditorBorrador(borrador: b) { nuevo in
                if let j = modelo.borradores.firstIndex(where: { $0.id == nuevo.id }) {
                    modelo.borradores[j] = nuevo
                }
            }
        }
        .alert("No pude guardar tu plan", isPresented: $errorAlGuardar) {
            Button("Entendido", role: .cancel) {}
        } message: {
            Text("Tus cambios siguen en esta pantalla. Intenta guardar otra vez.")
        }
        .onDisappear { Voz.callar() }
    }

    private func tarjeta(_ i: Int, _ b: Borrador) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if b.yaRegistrado {
                Label("\(b.nombre): ya la tienes registrada.", systemImage: "checkmark.seal.fill")
                    .font(.headline)
                    .foregroundStyle(Paleta.tomada)
                    .tarjeta(relleno: 16, color: Paleta.tomadaFondo)
            } else {
                TarjetaBorrador(borrador: b) {
                    modelo.borradores[i].dudosos.remove("horario")
                }
                if b.cambioDe != nil { preguntaCambio(i, b) }
                if b.bloqueado {
                    Label("Pendiente: \(b.motivoPendiente).", systemImage: "exclamationmark.circle")
                        .font(.headline)
                        .foregroundStyle(Paleta.tinta)
                    Text("Quedará fuera si guardas ahora.")
                        .font(.body)
                        .foregroundStyle(Paleta.tintaSuave)
                }
                if !b.dudoso("condicion") {
                    let accion = b.faltaElegirIntervalo ? "Elegir intervalo" : "Cambiar"
                    BotonGrande(titulo: accion, icono: "pencil", estilo: .secundario) { editando = b }
                        .accessibilityLabel("\(accion): \(b.nombre)")
                }
                BotonGrande(titulo: "Dejar fuera", estilo: .texto) { omitidos.insert(b.id) }
                    .accessibilityLabel("Dejar fuera \(b.nombre)")
            }
        }
    }

    /// "Ya tienes Losartán 50 mg; esta receta dice 100 mg. ¿Es un cambio?" Lo decide la persona.
    private func preguntaCambio(_ i: Int, _ b: Borrador) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("¿Es un cambio de tu doctor?")
                .font(Tipo.tarjeta)
                .foregroundStyle(Paleta.tinta)
            let nueva = b.rangoHoras.map { "cada \($0.lowerBound) a \($0.upperBound) horas" } ?? "\(b.nombre) \(b.concentracion)"
            Text("Ya tienes \(b.nombreAnterior ?? b.nombre). Esta receta dice \(nueva).")
                .font(.body)
                .foregroundStyle(Paleta.tinta)
                .fixedSize(horizontal: false, vertical: true)
            TarjetaOpcion(icono: "arrow.triangle.2.circlepath", titulo: "Sí, cambia la anterior",
                          detalle: "Dejo de avisarte la de antes y uso esta.",
                          elegida: b.decisionCambio == .reemplazar) {
                modelo.borradores[i].decisionCambio = .reemplazar
            }
            TarjetaOpcion(icono: "plus.square.on.square", titulo: "No, son dos distintas",
                          detalle: "Guardo las dos.",
                          elegida: b.decisionCambio == .conservarAmbas) {
                modelo.borradores[i].decisionCambio = .conservarAmbas
            }
        }
        .tarjeta(relleno: 18, color: Paleta.acentoSuave)
    }

    private var pantallaNotas: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Otros cuidados").font(Tipo.seccion).accessibilityAddTraits(.isHeader)
            ForEach(notasVisibles, id: \.self) { nota in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "note.text")
                        .font(.title3)
                        .foregroundStyle(Paleta.tinta)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(Paleta.fondo))
                        .accessibilityHidden(true)
                    Text(nota.capitalizedPrimera)
                        .font(.system(.title3, design: .serif))
                        .foregroundStyle(Paleta.tinta)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    VStack(spacing: 6) {
                        Button { Voz.decir(nota) } label: {
                            Image(systemName: "speaker.wave.2")
                                .frame(width: 44, height: 44)
                        }
                        .accessibilityLabel("Leer en voz alta")
                        Button { notasQuitadas.insert(nota) } label: {
                            Image(systemName: "xmark")
                                .frame(width: 44, height: 44)
                        }
                        .accessibilityLabel("Quitar esta nota")
                    }
                    .font(.headline)
                    .foregroundStyle(Paleta.tinta)
                }
                .tarjeta(relleno: 16, color: Paleta.sol.opacity(0.55))
            }
        }
    }

    private func guardar() {
        guard !guardado, puedeGuardar else { return }
        Voz.callar()
        guardado = true
        let existentes = (try? contexto.fetch(FetchDescriptor<Medicamento>())) ?? []
        var usados = existentes.filter(\.activo).map(\.colorHex)
        var nuevos: [Medicamento] = []
        var reemplazados: Set<UUID> = []
        for b in listos {
            let color = Paleta.siguiente(usados: usados)
            usados.append(color)
            let med = b.medicamento(colorHex: color)
            contexto.insert(med)
            nuevos.append(med)
            // Cambio confirmado por la persona: la anterior deja de estar activa y se cancelan sus avisos.
            if b.decisionCambio == .reemplazar, let id = b.cambioDe, let anterior = Almacen.medicamento(id: id, en: contexto) {
                anterior.activo = false
                reemplazados.insert(id)
            }
        }
        for nota in notasVisibles {
            contexto.insert(NotaReceta(texto: nota))
        }
        do {
            try contexto.save()
        } catch {
            contexto.rollback()
            guardado = false
            errorAlGuardar = true
            return
        }
        Task {
            for id in reemplazados {
                await ServicioAvisosSistema.compartido.cancelar(medicamentoID: id)
            }
        }
        modelo.guardados = nuevos
        alTerminar(nuevos)
    }
}

/// Tarjeta de lectura de un borrador con 🔊 y campos dudosos en amarillo.
struct TarjetaBorrador: View {
    let borrador: Borrador
    /// Confirma con un toque el horario que propuso la IA a partir de la rutina.
    var alConfirmarHorario: (() -> Void)? = nil

    @Query private var perfiles: [Perfil]

    /// "Con el desayuno (8:00 a. m.) y con la cena (8:00 p. m.)", con las horas de la rutina.
    private var textoCuando: String {
        if borrador.faltaElegirIntervalo, let rango = borrador.rangoHoras {
            return "Cada \(rango.lowerBound) a \(rango.upperBound) horas"
        }
        if let horas = borrador.cadaHoras {
            let frecuencia = horas == 1 ? "Cada hora" : "Cada \(horas) horas"
            guard let inicio = borrador.inicioIntervalo else { return frecuencia + " · Falta la primera hora" }
            return frecuencia + " · Empieza \(inicio.formatted(date: .abbreviated, time: .shortened))"
        }
        guard !borrador.momentos.isEmpty else { return "Sin horario" }
        let partes = borrador.momentos.map { m -> String in
            guard let p = perfiles.first else { return m.texto }
            if case .horaFija = m { return m.texto }
            let h = p.hora(de: m)
            let fecha = Calendar.current.date(bySettingHour: h.hour ?? 0, minute: h.minute ?? 0, second: 0, of: .now) ?? .now
            return "\(m.texto) (\(fecha.formatted(date: .omitted, time: .shortened)))"
        }
        return partes.formatted(.list(type: .and).locale(Locale(identifier: "es_MX"))).capitalizedPrimera
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(borrador.nombre.isEmpty ? "Sin nombre" : borrador.nombre)
                        .font(Tipo.titulo)
                        .foregroundStyle(Paleta.tinta)
                        .fixedSize(horizontal: false, vertical: true)
                        .dudoso(borrador.dudoso("nombre"))
                    if borrador.tipoAccion != .toma {
                        Label(borrador.tipoAccion.titulo, systemImage: borrador.tipoAccion.icono)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Paleta.tinta)
                    }
                    if !borrador.concentracion.isEmpty || borrador.dudoso("concentracion") {
                        Text(borrador.concentracion.isEmpty ? "¿Cuántos mg?" : borrador.concentracion)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(Paleta.marca)
                            .dudoso(borrador.dudoso("concentracion"))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Button {
                    Voz.decir(borrador.lectura)
                } label: {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.title2)
                        .foregroundStyle(Paleta.marca)
                        .frame(width: 60, height: 60)
                        .background(Circle().fill(Paleta.marcaSuave))
                }
                .buttonStyle(EstiloPresionable())
                .accessibilityLabel("Leer en voz alta")
            }

            Divider().overlay(Paleta.borde)

            if borrador.tipoAccion == .toma || !borrador.dosis.isEmpty || borrador.dudoso("dosis") {
                dato(icono: borrador.tipoAccion.icono, titulo: "Cuánto",
                     valor: borrador.dosis.isEmpty ? "Falta la cantidad" : borrador.dosis,
                     dudoso: borrador.dudoso("dosis"))
            }
            VStack(alignment: .leading, spacing: 10) {
                dato(icono: "clock", titulo: "Cuándo",
                     valor: textoCuando,
                     dudoso: borrador.momentosDudosos)
                if let motivo = borrador.motivoHorario, !motivo.isEmpty {
                    Label(motivo.capitalizedPrimera, systemImage: "sparkles")
                        .font(.subheadline)
                        .foregroundStyle(Paleta.tintaSuave)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if borrador.soloConfirmarHorario, let alConfirmarHorario {
                    Button(action: alConfirmarHorario) {
                        Label("Sí, este horario me queda", systemImage: "checkmark")
                            .font(Tipo.etiqueta)
                            .foregroundStyle(Color.white)
                            .padding(.horizontal, 16)
                            .frame(minHeight: 48)
                            .background(Capsule().fill(Paleta.marcaFuerte))
                    }
                    .buttonStyle(EstiloPresionable())
                    .accessibilityLabel("Confirmar el horario de \(borrador.nombre)")
                }
            }
            dato(icono: "calendar", titulo: "Por cuánto tiempo", valor: borrador.textoDuracion,
                 dudoso: borrador.dudoso("duracionDias"))
            if let indicaciones = borrador.indicaciones, !indicaciones.isEmpty {
                dato(icono: "info.circle", titulo: "Indicaciones", valor: indicaciones.capitalizedPrimera, dudoso: false)
            }
            if let fuente = borrador.fuente {
                // Explicación: de dónde salió la propuesta, con las palabras de la foto.
                VStack(alignment: .leading, spacing: 6) {
                    Text("Esto dice tu foto").estiloMayusculas()
                    Text("«\(fuente)»")
                        .font(.system(.body, design: .serif))
                        .italic()
                        .foregroundStyle(Paleta.tinta)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Paleta.fondo))
                .accessibilityElement(children: .combine)
            }
        }
        .tarjeta(relleno: 22)
    }

    private func dato(icono: String, titulo: String, valor: String, dudoso: Bool) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icono)
                .font(.headline)
                .foregroundStyle(Paleta.marca)
                .frame(width: 40, height: 40)
                .background(Circle().fill(Paleta.marcaSuave))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(titulo)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Paleta.tintaSuave)
                Text(valor)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Paleta.tinta)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .dudoso(dudoso)
        .accessibilityElement(children: .combine)
    }
}

/// "Cambiar": corrige lo que leyó la IA. Al tocar "Listo", lo revisado deja de estar en amarillo.
struct EditorBorrador: View {
    let alGuardar: (Borrador) -> Void

    @Environment(\.dismiss) private var cerrar
    @State private var b: Borrador
    @State private var horas: String
    @State private var porHoras: Bool
    @State private var primeraVez: Date

    init(borrador: Borrador, alGuardar: @escaping (Borrador) -> Void) {
        self.alGuardar = alGuardar
        _b = State(initialValue: borrador)
        _horas = State(initialValue: borrador.cadaHoras.map { String($0) } ?? "")
        _porHoras = State(initialValue: borrador.tieneIntervalo)
        let proximoMinuto = Calendar.current.dateInterval(of: .minute, for: .now)?.end ?? .now
        _primeraVez = State(initialValue: borrador.inicioIntervalo ?? proximoMinuto)
    }

    private var intervaloValido: Int? {
        guard let horas = Int(horas), horas > 0, b.rangoHoras?.contains(horas) != false else { return nil }
        return horas
    }

    private let dosisRapidas = ["½ tableta", "1 tableta", "2 tabletas", "1 cápsula"]
    private let duraciones: [Int?] = [nil, 7, 10, 14, 30]
    private let columnas = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    if b.tieneIntervalo { pauta }
                    seccion("Nombre") {
                        campo("Losartán", texto: $b.nombre)
                    }
                    seccion("Tipo de indicación") {
                        Picker("Tipo de indicación", selection: $b.tipoAccion) {
                            ForEach(TipoAccionPlan.allCases, id: \.self) { tipo in
                                Text(tipo.titulo).tag(tipo)
                            }
                        }
                        .pickerStyle(.inline)
                    }
                    if b.tipoAccion != .cuidado {
                        seccion("Concentración") {
                            campo("50 mg", texto: $b.concentracion)
                        }
                    }
                    seccion(b.tipoAccion == .toma ? "¿Cuánto usas cada vez?" : "Cantidad, si la receta la indica") {
                        if b.tipoAccion == .toma {
                            LazyVGrid(columns: columnas, spacing: 12) {
                                ForEach(dosisRapidas, id: \.self) { d in
                                    ChipSeleccion(titulo: d, elegido: b.dosis == d) { b.dosis = d }
                                }
                            }
                        }
                        campo("Otra cantidad", texto: $b.dosis)
                    }
                    if !b.tieneIntervalo { pauta }
                    seccion("¿Por cuántos días?") {
                        LazyVGrid(columns: columnas, spacing: 12) {
                            ForEach(duraciones, id: \.self) { d in
                                ChipSeleccion(titulo: d.map { "\($0) días" } ?? "Siempre",
                                              elegido: b.duracionDias == d) { b.duracionDias = d }
                            }
                        }
                    }
                }
                .padding(24)
            }
            .background(Paleta.fondo.ignoresSafeArea())
            .navigationTitle("Cambiar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { cerrar() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") { listo() }
                        .fontWeight(.bold)
                        .disabled(b.nombre.trimmingCharacters(in: .whitespaces).isEmpty
                                  || (b.tipoAccion == .toma && b.dosis.trimmingCharacters(in: .whitespaces).isEmpty)
                                  || (porHoras ? intervaloValido == nil : b.momentos.isEmpty))
                }
            }
        }
        .presentationCornerRadius(32)
    }

    private var pauta: some View {
        seccion("¿Cuándo?") {
            if b.tipoAccion != .toma && b.rangoHoras == nil {
                ChipSeleccion(titulo: "Cada cierto número de horas", icono: "clock", elegido: porHoras) { porHoras = true }
                ChipSeleccion(titulo: "En momentos del día", icono: "sun.max", elegido: !porHoras) { porHoras = false }
            }
            if porHoras {
                if let rango = b.rangoHoras {
                    Text("La receta dice cada \(rango.lowerBound) a \(rango.upperBound) horas.")
                    if rango.upperBound - rango.lowerBound < 6 {
                        ForEach(rango, id: \.self) { intervalo in
                            let valor = String(intervalo)
                            ChipSeleccion(titulo: intervalo == 1 ? "Cada hora" : "Cada \(valor) horas",
                                          elegido: horas == valor) { horas = valor }
                        }
                    } else {
                        campo("Horas dentro del rango", texto: $horas).keyboardType(.numberPad)
                    }
                } else {
                    campo("Horas entre cada vez", texto: $horas).keyboardType(.numberPad)
                }
                DatePicker("Primera vez", selection: $primeraVez)
            } else {
                LazyVGrid(columns: columnas, spacing: 12) {
                    ForEach(Momento.rutina, id: \.self) { m in
                        ChipSeleccion(titulo: m.nombre, icono: m.icono, elegido: b.momentos.contains(m)) { alternar(m) }
                    }
                }
            }
        }
    }

    private func seccion<C: View>(_ titulo: String, @ViewBuilder contenido: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(titulo)
                .font(Tipo.seccion)
                .foregroundStyle(Paleta.tinta)
                .accessibilityAddTraits(.isHeader)
            contenido()
        }
    }

    private func campo(_ ejemplo: String, texto: Binding<String>) -> some View {
        TextField(ejemplo, text: texto)
            .font(.title3)
            .foregroundStyle(Paleta.tinta)
            .padding(.horizontal, 18)
            .frame(minHeight: 60)
            .background(RoundedRectangle(cornerRadius: Radio.control, style: .continuous).fill(Paleta.tarjeta))
            .overlay(RoundedRectangle(cornerRadius: Radio.control, style: .continuous).strokeBorder(Paleta.borde, lineWidth: 1))
    }

    private func alternar(_ m: Momento) {
        if let i = b.momentos.firstIndex(of: m) {
            b.momentos.remove(at: i)
        } else {
            b.momentos.append(m)
            b.momentos.sort { orden($0) < orden($1) }
        }
    }

    private func orden(_ m: Momento) -> Int { Momento.rutina.firstIndex(of: m) ?? 99 }

    private func listo() {
        b.nombre = b.nombre.trimmingCharacters(in: .whitespaces)
        b.concentracion = b.concentracion.trimmingCharacters(in: .whitespaces)
        b.dosis = b.dosis.trimmingCharacters(in: .whitespaces)
        // Lo que la persona vio y dejó en "Listo" queda revisado.
        var revisado: Set<String> = ["concentracion", "duracionDias"]
        if !b.nombre.isEmpty { revisado.insert("nombre") }
        if !b.dosis.isEmpty || b.tipoAccion != .toma { revisado.insert("dosis") }
        if !b.momentos.isEmpty { revisado.formUnion(["momentos", "cadaHoras", "horario"]) }
        if porHoras, let intervaloValido {
            b.cadaHoras = intervaloValido
            b.momentos = []
            b.inicioIntervalo = Calendar.current.dateInterval(of: .minute, for: primeraVez)?.start ?? primeraVez
            revisado.formUnion(["momentos", "cadaHoras", "horario"])
        } else {
            b.cadaHoras = nil
            b.inicioIntervalo = nil
        }
        b.dudosos.subtract(revisado)
        alGuardar(b)
        cerrar()
    }
}

extension Medicamento {
    /// Agrega la foto de la caja y su cantidad (si vienen de la foto de la caja).
    func conFoto(_ foto: Data?, pastillas: Int?) -> Medicamento {
        if let foto { fotoCaja = foto }
        if let pastillas { pastillasPorCaja = pastillas }
        return self
    }
}
