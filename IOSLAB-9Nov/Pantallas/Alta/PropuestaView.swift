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

    /// "1 tableta · Con el desayuno y con la cena", para el resumen final.
    var resumenCorto: String {
        var cuando = textoMomentos
        if let cadaHoras { cuando = cadaHoras == 1 ? "Cada hora" : "Cada \(cadaHoras) horas" }
        else if let rangoHoras { cuando = "Cada \(rangoHoras.lowerBound) a \(rangoHoras.upperBound) horas" }
        return [dosis, cuando].filter { !$0.isEmpty }.joined(separator: " · ")
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

/// Revisión de la receta: una medicina por pantalla y, al final, un resumen antes de guardar (RF-02).
/// Nada se guarda hasta que la persona toca "Guardar plan" en el resumen.
struct PropuestaView: View {
    let alTerminar: ([Medicamento]) -> Void

    @Environment(ModeloAlta.self) private var modelo
    @Environment(\.modelContext) private var contexto
    @AppStorage(ClavesApp.leerEnVoz) private var leerEnVoz = false
    @State private var editando: Borrador?
    @State private var guardado = false
    @State private var omitidos: Set<UUID> = []
    @State private var notasQuitadas: Set<String> = []
    @State private var errorAlGuardar = false
    @State private var confirmarSinPendientes = false
    /// Posición dentro de `revisables`; cuando llega al final se muestra el resumen.
    @State private var paso = 0

    /// Medicinas nuevas que se revisan una por una. Las ya registradas solo se mencionan en el resumen.
    private var revisables: [Borrador] { modelo.borradores.filter { !$0.yaRegistrado } }
    private var yaRegistradas: [Borrador] { modelo.borradores.filter(\.yaRegistrado) }
    private var enResumen: Bool { paso >= revisables.count }

    private var elegibles: [Borrador] {
        modelo.borradores.filter { !$0.yaRegistrado && !omitidos.contains($0.id) }
    }

    private var notasVisibles: [String] {
        modelo.notas.filter { !notasQuitadas.contains($0) }
    }

    private var listos: [Borrador] { elegibles.filter { !$0.bloqueado } }
    private var pendientes: [Borrador] { elegibles.filter(\.bloqueado) }
    private var fuera: [Borrador] { modelo.borradores.filter { omitidos.contains($0.id) } }
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
        Group {
            if enResumen {
                resumen
            } else {
                pantallaMedicina(revisables[paso])
            }
        }
        .id(enResumen ? "resumen" : "medicina-\(paso)")
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.25), value: paso)
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
            Text("Tus cambios siguen aquí. Intenta guardar otra vez.")
        }
        .onAppear(perform: leerSiToca)
        .onChange(of: paso) { leerSiToca() }
        .onDisappear { Voz.callar() }
    }

    /// Con "Leer en voz alta" activado (Perfil), cada medicina se lee sola al aparecer.
    private func leerSiToca() {
        Voz.callar()
        guard leerEnVoz, !enResumen else { return }
        Voz.decir(revisables[paso].lectura)
    }

    private func avanzar() { paso = min(paso + 1, revisables.count) }

    // MARK: Una medicina por pantalla

    private func pantallaMedicina(_ b: Borrador) -> some View {
        let total = revisables.count
        let indice = modelo.borradores.firstIndex(where: { $0.id == b.id }) ?? 0
        return PantallaPregunta(titulo: total == 1 ? "Revisa tu medicina" : "Medicina \(paso + 1) de \(total)",
                                subtitulo: "Compárala con tu receta. Si algo no coincide, toca Corregir.",
                                paso: total > 1 ? (paso + 1, total) : nil) {
            if paso == 0, let consulta = modelo.consulta {
                Label(consulta, systemImage: "checklist")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Paleta.tinta)
                    .fixedSize(horizontal: false, vertical: true)
                    .tarjeta(relleno: 16, color: Paleta.salvia)
            }
            if omitidos.contains(b.id) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("\(b.nombre.capitalizedPrimera): no la voy a guardar.")
                        .font(Tipo.tarjeta)
                        .foregroundStyle(Paleta.tinta)
                        .fixedSize(horizontal: false, vertical: true)
                    BotonGrande(titulo: "Sí la quiero guardar", icono: "arrow.uturn.backward", estilo: .secundario) {
                        omitidos.remove(b.id)
                    }
                }
                .tarjeta(relleno: 20)
            } else {
                TarjetaBorrador(borrador: b) {
                    modelo.borradores[indice].dudosos.remove("horario")
                }
                .id(b.id)
                if b.cambioDe != nil { preguntaCambio(indice, b) }
                if b.bloqueado {
                    Label("Antes de guardarla: \(b.motivoPendiente).", systemImage: "exclamationmark.circle")
                        .font(.headline)
                        .foregroundStyle(Paleta.tinta)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .tarjeta(relleno: 16, color: Paleta.acentoSuave)
                }
            }
        } botones: {
            botonesMedicina(b)
        }
    }

    /// Qué botón resuelve lo que falta, cuando se resuelve corrigiendo.
    /// Nil si se resuelve en la misma pantalla (confirmar horario, decidir si es cambio) o no tiene arreglo (condición).
    private func accionPendiente(_ b: Borrador) -> String? {
        guard b.bloqueado, !b.dudoso("condicion") else { return nil }
        if b.faltaElegirIntervalo { return "Elegir cada cuántas horas" }
        if b.faltaPrimeraVez { return "Elegir la primera vez" }
        if b.cadaHoras == nil && b.momentos.isEmpty { return "Elegir cuándo" }
        if b.soloConfirmarHorario || b.dudosos.isEmpty { return nil }
        return "Corregir lo que está en amarillo"
    }

    @ViewBuilder private func botonesMedicina(_ b: Borrador) -> some View {
        let ultimo = paso == revisables.count - 1
        let siguiente = ultimo ? "Ver mi plan" : "Siguiente medicina"
        if omitidos.contains(b.id) {
            BotonGrande(titulo: siguiente, icono: "arrow.right") { avanzar() }
        } else {
            if let accion = accionPendiente(b) {
                BotonGrande(titulo: accion, icono: "pencil") { editando = b }
                    .accessibilityLabel("\(accion): \(b.nombre)")
                BotonGrande(titulo: "Revisarla después", estilo: .texto) { avanzar() }
            } else {
                BotonGrande(titulo: b.bloqueado ? siguiente : (ultimo ? "Está bien, ver mi plan" : "Está bien, siguiente"),
                            icono: b.bloqueado ? "arrow.right" : "checkmark") { avanzar() }
                if !b.dudoso("condicion") {
                    BotonGrande(titulo: "Corregir", icono: "pencil", estilo: .secundario) { editando = b }
                        .accessibilityLabel("Corregir \(b.nombre)")
                }
            }
            BotonGrande(titulo: "No la quiero guardar", estilo: .texto) {
                omitidos.insert(b.id)
                avanzar()
            }
            .accessibilityLabel("No guardar \(b.nombre)")
        }
        if paso > 0 {
            BotonGrande(titulo: "Anterior", icono: "chevron.left", estilo: .texto) { paso -= 1 }
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

    // MARK: Resumen final

    private var resumen: some View {
        let nada = elegibles.isEmpty && notasVisibles.isEmpty
        return PantallaPregunta(titulo: "Tu plan",
                                subtitulo: nada ? "No hay nada nuevo que guardar." : "Esto es lo que voy a guardar. Puedes revisar cualquiera.") {
            if !listos.isEmpty {
                grupo("Se guardan") {
                    ForEach(listos) { b in
                        filaResumen(b, detalle: b.resumenCorto, icono: "checkmark.circle.fill", color: Paleta.tomadaFondo)
                    }
                }
            }
            if !pendientes.isEmpty {
                grupo("Les falta algo") {
                    ForEach(pendientes) { b in
                        filaResumen(b, detalle: "Si guardas ahora, quedará fuera porque \(b.motivoPendiente).",
                                    icono: "exclamationmark.circle", color: Paleta.acentoSuave)
                    }
                }
            }
            if !fuera.isEmpty {
                grupo("No se guardan") {
                    ForEach(fuera) { b in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(b.nombre.capitalizedPrimera)
                                .font(Tipo.tarjeta)
                                .foregroundStyle(Paleta.tinta)
                            BotonGrande(titulo: "Sí la quiero guardar", icono: "arrow.uturn.backward", estilo: .secundario) {
                                omitidos.remove(b.id)
                            }
                        }
                        .tarjeta(relleno: 18)
                    }
                }
            }
            if !yaRegistradas.isEmpty {
                grupo("Ya las tienes") {
                    ForEach(yaRegistradas) { b in
                        Label(b.nombre.capitalizedPrimera, systemImage: "checkmark.seal.fill")
                            .font(.headline)
                            .foregroundStyle(Paleta.tinta)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .tarjeta(relleno: 16, color: Paleta.tomadaFondo)
                    }
                }
            }
            if !notasVisibles.isEmpty {
                pantallaNotas
            }
        } botones: {
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
            if !revisables.isEmpty {
                BotonGrande(titulo: "Revisar otra vez", icono: "arrow.uturn.backward", estilo: .texto) { paso = 0 }
            }
        }
    }

    private func grupo<C: View>(_ titulo: String, @ViewBuilder contenido: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(titulo)
                .font(Tipo.seccion)
                .foregroundStyle(Paleta.tinta)
                .accessibilityAddTraits(.isHeader)
            contenido()
        }
    }

    private func filaResumen(_ b: Borrador, detalle: String, icono: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: icono)
                    .font(.title3)
                    .foregroundStyle(Paleta.tinta)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(b.nombre.capitalizedPrimera)
                        .font(Tipo.tarjeta)
                        .foregroundStyle(Paleta.tinta)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(detalle)
                        .font(.body)
                        .foregroundStyle(Paleta.tinta)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .accessibilityElement(children: .combine)
            if let i = revisables.firstIndex(where: { $0.id == b.id }) {
                BotonGrande(titulo: "Revisar", icono: "eye", estilo: .secundario) { paso = i }
                    .accessibilityLabel("Revisar \(b.nombre)")
            }
        }
        .tarjeta(relleno: 18, color: color)
    }

    private var pantallaNotas: some View {
        grupo("Otros cuidados de tu receta") {
            ForEach(notasVisibles, id: \.self) { nota in
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "note.text")
                            .font(.title3)
                            .foregroundStyle(Paleta.tinta)
                            .accessibilityHidden(true)
                        Text(nota.capitalizedPrimera)
                            .font(.title3)
                            .foregroundStyle(Paleta.tinta)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 10) { botonesNota(nota) }
                        VStack(alignment: .leading, spacing: 8) { botonesNota(nota) }
                    }
                }
                .tarjeta(relleno: 18, color: Paleta.sol.opacity(0.55))
            }
        }
    }

    @ViewBuilder private func botonesNota(_ nota: String) -> some View {
        Button { Voz.decir(nota) } label: {
            Label("Leer", systemImage: "speaker.wave.2.fill").botonChico()
        }
        .buttonStyle(EstiloPresionable())
        .accessibilityLabel("Leer esta nota en voz alta")
        Button { notasQuitadas.insert(nota) } label: {
            Label("No guardar esta nota", systemImage: "xmark").botonChico()
        }
        .buttonStyle(EstiloPresionable())
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

private extension View {
    /// Botón secundario pequeño en ancho, pero con texto legible y 52 pt de alto.
    func botonChico() -> some View {
        self.font(Tipo.etiqueta)
            .foregroundStyle(Paleta.tinta)
            .padding(.horizontal, 16)
            .frame(minHeight: 52)
            .background(Capsule().fill(Paleta.fondo))
            .overlay(Capsule().strokeBorder(Paleta.borde, lineWidth: 1))
    }
}

/// Tarjeta de una medicina propuesta: lo esencial a la vista y el resto en "Ver más".
/// Los campos dudosos van en amarillo; si hay alguno, "Ver más" se abre solo.
struct TarjetaBorrador: View {
    let borrador: Borrador
    /// Confirma con un toque el horario que propuso la IA a partir de la rutina.
    var alConfirmarHorario: (() -> Void)? = nil

    @Query private var perfiles: [Perfil]
    @State private var mostrarMas: Bool

    init(borrador: Borrador, alConfirmarHorario: (() -> Void)? = nil) {
        self.borrador = borrador
        self.alConfirmarHorario = alConfirmarHorario
        _mostrarMas = State(initialValue: !borrador.dudosos.isEmpty)
    }

    /// "Con el desayuno (8:00 a. m.) y con la cena (8:00 p. m.)", con las horas de la rutina.
    private var textoCuando: String {
        if borrador.faltaElegirIntervalo, let rango = borrador.rangoHoras {
            return "Cada \(rango.lowerBound) a \(rango.upperBound) horas"
        }
        if let horas = borrador.cadaHoras {
            let frecuencia = horas == 1 ? "Cada hora" : "Cada \(horas) horas"
            guard let inicio = borrador.inicioIntervalo else { return frecuencia + ". Falta la primera vez" }
            return frecuencia + ". Empieza \(inicio.formatted(date: .abbreviated, time: .shortened))"
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
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 12) {
                    encabezado.frame(maxWidth: .infinity, alignment: .leading)
                    botonLeer
                }
                VStack(alignment: .leading, spacing: 12) {
                    encabezado
                    botonLeer
                }
            }

            Divider().overlay(Paleta.borde)

            if borrador.tipoAccion == .toma || !borrador.dosis.isEmpty || borrador.dudoso("dosis") {
                dato(icono: borrador.tipoAccion.icono, titulo: "Cuánto",
                     valor: borrador.dosis.isEmpty ? "Falta la cantidad" : borrador.dosis,
                     dudoso: borrador.dudoso("dosis"))
            }
            VStack(alignment: .leading, spacing: 12) {
                dato(icono: "clock", titulo: "Cuándo",
                     valor: textoCuando,
                     dudoso: borrador.momentosDudosos)
                if let motivo = borrador.motivoHorario, !motivo.isEmpty {
                    Label(motivo.capitalizedPrimera, systemImage: "sparkles")
                        .font(.body)
                        .foregroundStyle(Paleta.tinta)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if borrador.soloConfirmarHorario, let alConfirmarHorario {
                    BotonGrande(titulo: "Sí, este horario me queda", icono: "checkmark") { alConfirmarHorario() }
                        .accessibilityLabel("Confirmar el horario de \(borrador.nombre)")
                }
            }

            Button {
                withAnimation(.easeInOut(duration: 0.2)) { mostrarMas.toggle() }
            } label: {
                Label(mostrarMas ? "Ver menos" : "Ver más", systemImage: mostrarMas ? "chevron.up" : "chevron.down")
                    .font(Tipo.etiqueta)
                    .foregroundStyle(Paleta.tinta)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .overlay(Capsule().strokeBorder(Paleta.borde, lineWidth: 1.5))
                    .contentShape(Capsule())
            }
            .buttonStyle(EstiloPresionable())
            .accessibilityHint("Muestra cuántos días, las indicaciones y lo que dice tu foto")

            if mostrarMas {
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
                            .font(.title3)
                            .foregroundStyle(Paleta.tinta)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Paleta.fondo))
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .tarjeta(relleno: 22)
    }

    private var encabezado: some View {
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
    }

    private var botonLeer: some View {
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
                    .font(.body.weight(.semibold))
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

/// "Corregir": arregla lo que leyó la IA, en palabras sencillas. Al tocar "Listo", lo revisado deja de estar en amarillo.
struct EditorBorrador: View {
    let alGuardar: (Borrador) -> Void

    @Environment(\.dismiss) private var cerrar
    @Query private var perfiles: [Perfil]
    @State private var b: Borrador
    @State private var horas: String
    @State private var porHoras: Bool
    @State private var primeraVez: Date
    /// La primera vez de una medicina "cada X horas" la elige la persona; no se adivina.
    @State private var inicio: Inicio?

    enum Inicio: Hashable { case ahora, enUnaHora, desayuno, otra }

    init(borrador: Borrador, alGuardar: @escaping (Borrador) -> Void) {
        self.alGuardar = alGuardar
        _b = State(initialValue: borrador)
        _horas = State(initialValue: borrador.cadaHoras.map { String($0) } ?? "")
        _porHoras = State(initialValue: borrador.tieneIntervalo)
        _primeraVez = State(initialValue: borrador.inicioIntervalo ?? Self.proximoMinuto(.now))
        _inicio = State(initialValue: borrador.inicioIntervalo == nil ? nil : .otra)
    }

    private static func proximoMinuto(_ fecha: Date) -> Date {
        Calendar.current.dateInterval(of: .minute, for: fecha)?.end ?? fecha
    }

    private var intervaloValido: Int? {
        guard let horas = Int(horas), horas > 0, b.rangoHoras?.contains(horas) != false else { return nil }
        return horas
    }

    /// Mañana a la hora del desayuno de la rutina (8:00 si no hay rutina).
    private var mananaDesayuno: Date {
        let h = perfiles.first?.hora(de: .desayuno) ?? DateComponents(hour: 8, minute: 0)
        let manana = Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now
        return Calendar.current.date(bySettingHour: h.hour ?? 8, minute: h.minute ?? 0, second: 0, of: manana) ?? manana
    }

    private var fechaInicio: Date? {
        switch inicio {
        case .ahora: Self.proximoMinuto(.now)
        case .enUnaHora: Self.proximoMinuto(.now.addingTimeInterval(3600))
        case .desayuno: mananaDesayuno
        case .otra: Calendar.current.dateInterval(of: .minute, for: primeraVez)?.start ?? primeraVez
        case nil: nil
        }
    }

    /// Lo que falta para poder tocar "Listo", en palabras para la persona.
    private var falta: String? {
        if b.nombre.trimmingCharacters(in: .whitespaces).isEmpty { return "Falta el nombre." }
        if b.tipoAccion == .toma && b.dosis.trimmingCharacters(in: .whitespaces).isEmpty { return "Falta cuánto tomas cada vez." }
        if porHoras {
            if intervaloValido == nil { return "Falta elegir cada cuántas horas." }
            if fechaInicio == nil { return "Falta elegir cuándo es la primera vez." }
        } else if b.momentos.isEmpty {
            return "Falta elegir cuándo."
        }
        return nil
    }

    private let dosisRapidas = ["½ tableta", "1 tableta", "2 tabletas", "1 cápsula"]
    private let horasRapidas = [4, 6, 8, 12]
    private let duraciones: [Int?] = [nil, 7, 10, 14, 30]
    private let columnas = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    if b.tieneIntervalo { pauta }
                    seccion("¿Cómo se llama?") {
                        campo("Por ejemplo, Losartán", texto: $b.nombre)
                    }
                    seccion("¿Qué es?") {
                        ChipSeleccion(titulo: "Una pastilla, jarabe o algo que tomo", icono: TipoAccionPlan.toma.icono,
                                      elegido: b.tipoAccion == .toma) { b.tipoAccion = .toma }
                        ChipSeleccion(titulo: "Una crema, gotas o algo que me pongo", icono: TipoAccionPlan.aplicacion.icono,
                                      elegido: b.tipoAccion == .aplicacion) { b.tipoAccion = .aplicacion }
                        ChipSeleccion(titulo: "Algo que hago, como caminar o medir mi presión", icono: TipoAccionPlan.cuidado.icono,
                                      elegido: b.tipoAccion == .cuidado) { b.tipoAccion = .cuidado }
                    }
                    if b.tipoAccion != .cuidado {
                        seccion("¿De cuántos miligramos? (si lo sabes)") {
                            campo("Por ejemplo, 50 mg", texto: $b.concentracion)
                        }
                    }
                    seccion(b.tipoAccion == .toma ? "¿Cuánto tomas cada vez?" : "¿Cuánto? (si la receta lo dice)") {
                        if b.tipoAccion == .toma {
                            LazyVGrid(columns: columnas, spacing: 12) {
                                ForEach(dosisRapidas, id: \.self) { d in
                                    ChipSeleccion(titulo: d, elegido: b.dosis == d) { b.dosis = d }
                                }
                            }
                        }
                        campo("Escribe otra cantidad", texto: $b.dosis)
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
                    VStack(alignment: .leading, spacing: 12) {
                        if let falta {
                            Label(falta, systemImage: "exclamationmark.circle")
                                .font(.headline)
                                .foregroundStyle(Paleta.tinta)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        BotonGrande(titulo: "Listo", icono: "checkmark") { listo() }
                            .disabled(falta != nil)
                        BotonGrande(titulo: "Cancelar", estilo: .texto) { cerrar() }
                    }
                }
                .padding(24)
            }
            .background(Paleta.fondo.ignoresSafeArea())
            .navigationTitle("Corregir")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { cerrar() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") { listo() }
                        .fontWeight(.bold)
                        .disabled(falta != nil)
                }
            }
        }
        .presentationCornerRadius(32)
    }

    private var pauta: some View {
        seccion("¿Cuándo?") {
            if b.tipoAccion != .toma && b.rangoHoras == nil {
                ChipSeleccion(titulo: "Con mis comidas o al dormir", icono: "sun.max", elegido: !porHoras) { porHoras = false }
                ChipSeleccion(titulo: "Cada cierto número de horas", icono: "clock", elegido: porHoras) { porHoras = true }
            }
            if porHoras {
                if let rango = b.rangoHoras {
                    Text("Tu receta dice cada \(rango.lowerBound) a \(rango.upperBound) horas. Elige una:")
                        .font(.body)
                        .foregroundStyle(Paleta.tinta)
                        .fixedSize(horizontal: false, vertical: true)
                    if rango.upperBound - rango.lowerBound < 6 {
                        ForEach(rango, id: \.self) { intervalo in
                            let valor = String(intervalo)
                            ChipSeleccion(titulo: intervalo == 1 ? "Cada hora" : "Cada \(valor) horas",
                                          elegido: horas == valor) { horas = valor }
                        }
                    } else {
                        campo("Número de horas", texto: $horas).keyboardType(.numberPad)
                    }
                } else {
                    subtitulo("¿Cada cuántas horas?")
                    LazyVGrid(columns: columnas, spacing: 12) {
                        ForEach(horasRapidas, id: \.self) { h in
                            ChipSeleccion(titulo: "Cada \(h) horas", elegido: horas == String(h)) { horas = String(h) }
                        }
                    }
                    campo("Otro número de horas", texto: $horas).keyboardType(.numberPad)
                }
                subtitulo("¿Cuándo es la primera vez?")
                ChipSeleccion(titulo: "Ahora", icono: "clock", elegido: inicio == .ahora) { inicio = .ahora }
                ChipSeleccion(titulo: "En 1 hora", icono: "clock.arrow.circlepath", elegido: inicio == .enUnaHora) { inicio = .enUnaHora }
                ChipSeleccion(titulo: "Mañana con el desayuno (\(mananaDesayuno.formatted(date: .omitted, time: .shortened)))",
                              icono: Momento.desayuno.icono, elegido: inicio == .desayuno) { inicio = .desayuno }
                ChipSeleccion(titulo: "Otro día u hora", icono: "calendar", elegido: inicio == .otra) { inicio = .otra }
                if inicio == .otra {
                    DatePicker("Primera vez", selection: $primeraVez)
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                        .frame(maxWidth: .infinity)
                        .environment(\.locale, Locale(identifier: "es_MX"))
                }
            } else {
                LazyVGrid(columns: columnas, spacing: 12) {
                    ForEach(Momento.rutina, id: \.self) { m in
                        ChipSeleccion(titulo: m.nombre, icono: m.icono, elegido: b.momentos.contains(m)) { alternar(m) }
                    }
                }
            }
        }
    }

    private func subtitulo(_ texto: String) -> some View {
        Text(texto)
            .font(.title3.weight(.semibold))
            .foregroundStyle(Paleta.tinta)
            .padding(.top, 6)
            .accessibilityAddTraits(.isHeader)
    }

    private func seccion<C: View>(_ titulo: String, @ViewBuilder contenido: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(titulo)
                .font(Tipo.seccion)
                .foregroundStyle(Paleta.tinta)
                .fixedSize(horizontal: false, vertical: true)
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
        guard falta == nil else { return }
        b.nombre = b.nombre.trimmingCharacters(in: .whitespaces)
        b.concentracion = b.concentracion.trimmingCharacters(in: .whitespaces)
        b.dosis = b.dosis.trimmingCharacters(in: .whitespaces)
        // Lo que la persona vio y dejó en "Listo" queda revisado.
        var revisado: Set<String> = ["concentracion", "duracionDias"]
        if !b.nombre.isEmpty { revisado.insert("nombre") }
        if !b.dosis.isEmpty || b.tipoAccion != .toma { revisado.insert("dosis") }
        if !b.momentos.isEmpty { revisado.formUnion(["momentos", "cadaHoras", "horario"]) }
        if porHoras, let intervaloValido, let fechaInicio {
            b.cadaHoras = intervaloValido
            b.momentos = []
            b.inicioIntervalo = fechaInicio
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
