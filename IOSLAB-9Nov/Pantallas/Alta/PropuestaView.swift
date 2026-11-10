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
        if faltaPrimeraVez { return "falta elegir a qué hora la tomas por primera vez" }
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
    @Environment(\.dismiss) private var volver
    @State private var editando: EdicionAbierta?
    @State private var guardado = false
    @State private var omitidos: Set<UUID> = []
    @State private var notasQuitadas: Set<String> = []
    @State private var errorAlGuardar = false
    @State private var confirmarSinPendientes = false
    /// Posición dentro de `revisables`; cuando llega al final se muestra el resumen.
    @State private var paso = 0
    /// MiMi ya dijo en voz alta qué leyó y qué no pudo leer.
    @State private var yaResumio = false

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
        // Sin barras durante la revisión: una sola acción clara por pantalla.
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .sheet(item: $editando) { e in
            EditorBorrador(borrador: e.borrador, seccion: e.seccion) { nuevo in
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
        // Al llegar de la foto, MiMi empieza diciendo qué leyó y qué no pudo leer.
        if !yaResumio, paso == 0, modelo.vieneDeReceta, !revisables.isEmpty {
            yaResumio = true
            Voz.decir(resumenLectura)
            return
        }
        guard leerEnVoz, !enResumen else { return }
        Voz.decir(revisables[paso].lectura)
    }

    private func avanzar() { paso = min(paso + 1, revisables.count) }

    // MARK: Una medicina por pantalla (diseño "Revisar receta 3a")

    /// Abre "Corregir" en una sección, o en general si es nil.
    private func abrir(_ b: Borrador, en seccion: SeccionRevision? = nil) {
        editando = EdicionAbierta(borrador: b, seccion: seccion)
    }

    /// Se puede pasar a la siguiente: todo en verde, o lo pendiente no tiene arreglo aquí (depende de una condición).
    private func puedeSeguir(_ b: Borrador) -> Bool { !b.bloqueado || b.dudoso("condicion") }

    private func pantallaMedicina(_ b: Borrador) -> some View {
        let total = revisables.count
        let indice = modelo.borradores.firstIndex(where: { $0.id == b.id }) ?? 0
        let fuera = omitidos.contains(b.id)
        return VStack(spacing: 0) {
            // Encabezado: atrás + "Medicina 1 de 4"
            HStack(spacing: 14) {
                Button {
                    if paso > 0 { paso -= 1 } else { volver() }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Paleta.tinta)
                        .frame(width: 52, height: 52)
                        .background(Circle().fill(Paleta.fondo))
                        .overlay(Circle().strokeBorder(ColoresRevision.linea, lineWidth: 1))
                }
                .buttonStyle(EstiloPresionable())
                .accessibilityLabel(paso > 0 ? "Medicina anterior" : "Regresar")
                Text(total == 1 ? "Revisa tu medicina" : "Medicina \(paso + 1) de \(total)")
                    .font(.headline)
                    .foregroundStyle(ColoresRevision.gris)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if paso == 0, modelo.vieneDeReceta, !faltantesAgrupados.isEmpty { tarjetaLectura }
                    if paso == 0, let consulta = modelo.consulta {
                        Label(consulta, systemImage: "checklist")
                            .font(.body)
                            .foregroundStyle(Paleta.tinta)
                            .fixedSize(horizontal: false, vertical: true)
                            .tarjeta(relleno: 16, color: Paleta.salvia)
                    }
                    if fuera {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("\(Borrador.nombreLegible(b.nombre)): no la voy a guardar.")
                                .font(Tipo.tarjeta)
                                .foregroundStyle(Paleta.tinta)
                                .fixedSize(horizontal: false, vertical: true)
                            BotonGrande(titulo: "Sí la quiero guardar", icono: "arrow.uturn.backward", estilo: .secundario) {
                                omitidos.remove(b.id)
                            }
                        }
                        .tarjeta(relleno: 20, color: ColoresRevision.superficie)
                    } else {
                        RevisionMedicina(borrador: b,
                                         alAbrir: { seccion in abrir(b, en: seccion) },
                                         alConfirmarHorario: { modelo.borradores[indice].dudosos.remove("horario") })
                            .id(b.id)
                        if b.cambioDe != nil { preguntaCambio(indice, b) }
                        Button {
                            omitidos.insert(b.id)
                            avanzar()
                        } label: {
                            Text("No la quiero guardar")
                                .font(.body.weight(.semibold))
                                .underline()
                                .foregroundStyle(ColoresRevision.gris)
                                .frame(maxWidth: .infinity, minHeight: 48)
                        }
                        .accessibilityLabel("No guardar \(b.nombre)")
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 18)
                .padding(.bottom, 24)
            }

            // Pie: una sola acción clara.
            VStack(spacing: 8) {
                let ultimo = paso == total - 1
                let siguiente = ultimo ? "Ver mi plan" : "Siguiente medicina"
                if fuera || puedeSeguir(b) {
                    BotonGrande(titulo: siguiente, icono: "arrow.right") { avanzar() }
                } else {
                    Text(b.cambioDe != nil && b.decisionCambio == .pendiente && RevisionMedicina.filas(de: b).allSatisfy { !$0.falta }
                         ? "Responde arriba si es un cambio de tu doctor."
                         : "Toca lo que está en rojo para completarlo.")
                        .font(.title3)
                        .foregroundStyle(ColoresRevision.gris)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                if !fuera, !b.dudoso("condicion") {
                    Button { abrir(b) } label: {
                        Text("Corregir algo")
                            .font(.title3.weight(.medium))
                            .foregroundStyle(ColoresRevision.gris)
                            .frame(maxWidth: .infinity, minHeight: 52)
                    }
                    .accessibilityLabel("Corregir algo de \(b.nombre)")
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 16)
            .background(Paleta.fondo)
        }
        .background(Paleta.fondo.ignoresSafeArea())
    }

    // MARK: Lo que MiMi no pudo leer

    /// Lo que no se pudo leer de una medicina, en palabras de la persona.
    /// No cuenta lo que la receta no trae (la hora de la primera vez, elegir dentro de un rango): eso se elige después.
    static func faltantes(_ b: Borrador) -> [String] {
        var r: [String] = []
        if b.dudoso("nombre") { r.append("el nombre") }
        if b.dudoso("concentracion") { r.append("los miligramos") }
        if b.dudoso("dosis") || (b.tipoAccion == .toma && b.dosis.isEmpty) { r.append("cuánto tomar") }
        if b.dudoso("momentos") || b.dudoso("cadaHoras") || (b.cadaHoras == nil && b.rangoHoras == nil && b.momentos.isEmpty) {
            r.append("a qué hora")
        }
        if b.dudoso("duracionDias") { r.append("por cuántos días") }
        if b.dudoso("condicion") { r.append("en qué caso se usa") }
        return r
    }

    private static func lista(_ xs: [String]) -> String {
        xs.formatted(.list(type: .and).locale(Locale(identifier: "es_MX")))
    }

    /// Lo que no se pudo leer, juntando las medicinas a las que les falta lo mismo:
    /// [("cuánto tomar", ["Penicilina", "Ambroxol"])]
    private var faltantesAgrupados: [(cosa: String, nombres: [String])] {
        var orden: [String] = []
        var grupos: [String: [String]] = [:]
        for (i, b) in revisables.enumerated() {
            // Con el nombre que se leyó, aunque esté por revisar; sin nombre, por su número.
            let quien = b.nombre.isEmpty ? "La medicina \(i + 1)" : Borrador.nombreLegible(b.nombre)
            for f in Self.faltantes(b) {
                if grupos[f] == nil { orden.append(f) }
                if grupos[f]?.contains(quien) != true { grupos[f, default: []].append(quien) }
            }
        }
        return orden.map { ($0, grupos[$0] ?? []) }
    }

    private var encabezadoLectura: String {
        let n = revisables.count
        let leidas = n == 1 ? "Leí una medicina" : "Leí \(n) medicinas"
        return faltantesAgrupados.isEmpty ? "\(leidas) y encontré todo escrito en tu receta." : "\(leidas). Esto no lo pude leer:"
    }

    /// Lo que MiMi dice en voz alta al llegar de la foto.
    private var resumenLectura: String {
        guard !faltantesAgrupados.isEmpty else { return encabezadoLectura + " Revísalas una por una." }
        let frases = faltantesAgrupados.map { g in
            "A \(Self.lista(g.nombres)) \(g.nombres.count == 1 ? "le" : "les") falta \(g.cosa)."
        }
        return ([encabezadoLectura] + frases + ["Toca lo que está en rojo para completarlo, o díselo a MiMi."]).joined(separator: " ")
    }

    private var tarjetaLectura: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                IconoMiMi(tamano: 44)
                Text(encabezadoLectura)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Paleta.tinta)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            // Un renglón por cosa que falta, con las medicinas juntas.
            ForEach(faltantesAgrupados, id: \.cosa) { g in
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(ColoresRevision.faltaTexto)
                        .accessibilityHidden(true)
                    Text("\(Text("\(Self.lista(g.nombres)):").bold()) falta \(g.cosa)")
                        .font(.body)
                        .foregroundStyle(Paleta.tinta)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .tarjeta(relleno: 18, color: ColoresRevision.faltaBloque)
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

// MARK: - Revisar una medicina (diseño "Revisar receta 3a")

/// Colores del diseño de revisión: verde = ya está bien, rojo = falta.
enum ColoresRevision {
    static let superficie = Color(hex: "#F4F5F3")
    static let linea = Color(hex: "#E4E7E5")
    static let gris = Color(hex: "#5C6366")
    static let escuchar = Color(hex: "#DCE9EA")
    static let okFondo = Color(hex: "#DCEBDF")
    static let okTinta = Color(hex: "#2F6B45")
    static let okTexto = Color(hex: "#1F4D31")
    static let faltaFondo = Color(hex: "#FADBD3")
    static let faltaTexto = Color(hex: "#B03A26")
    static let faltaPill = Color(hex: "#8E2E1E")
    static let faltaBloque = Color(hex: "#FBEDE6")
    static let radioVacio = Color(hex: "#B8BEBC")
    static let deshabilitado = Color(hex: "#E4E7E5")
    static let textoDeshabilitado = Color(hex: "#6B7071")
}

/// Partes de una medicina que se pueden completar o cambiar en "Corregir".
enum SeccionRevision: Hashable, CaseIterable {
    case nombre, tipo, miligramos, cuanto, cuando, cadaHoras, primeraVez, dias
}

/// Lo que se abre en "Corregir": la medicina y, si se tocó una fila, esa sección.
struct EdicionAbierta: Identifiable {
    let borrador: Borrador
    let seccion: SeccionRevision?
    var id: UUID { borrador.id }
}

extension Borrador {
    /// "LOSARTÁN" → "Losartán"; "losartán" → "Losartán". Nunca todo en mayúsculas.
    static func nombreLegible(_ nombre: String) -> String {
        let limpio = nombre.trimmingCharacters(in: .whitespaces)
        let letras = limpio.filter(\.isLetter)
        if letras.count > 2, letras == letras.uppercased() {
            return limpio.lowercased().capitalized(with: Locale(identifier: "es_MX"))
        }
        return limpio.capitalizedPrimera
    }

    /// "VÍA ORAL, SIN SUSPENDER" → "Por la boca, no suspender".
    static func indicacionesLegibles(_ texto: String) -> String {
        var t = texto.lowercased()
        let cambios = [("vía oral", "por la boca"), ("via oral", "por la boca"), ("sin suspender", "no suspender"),
                       ("vía tópica", "sobre la piel"), ("via topica", "sobre la piel"), ("vía oftálmica", "en el ojo"),
                       ("vía ótica", "en el oído"), ("vía nasal", "por la nariz"), ("vía inhalada", "inhalada"),
                       ("c/", "cada ")]
        for (de, a) in cambios { t = t.replacingOccurrences(of: de, with: a) }
        return t.split(separator: " ").joined(separator: " ").capitalizedPrimera
    }
}

extension Date {
    /// "8:00 de la mañana", "3:30 de la tarde", "9:00 de la noche", "2:00 de la madrugada".
    var horaHablada: String {
        let c = Calendar.current.dateComponents([.hour, .minute], from: self)
        let h = c.hour ?? 0
        let m = c.minute ?? 0
        let h12 = h % 12 == 0 ? 12 : h % 12
        let parte = switch h {
        case 0..<6: "de la madrugada"
        case 6..<12: "de la mañana"
        case 12..<19: "de la tarde"
        default: "de la noche"
        }
        return String(format: "%d:%02d ", h12, m) + parte
    }
}

/// Pantalla de una medicina: tarjeta con nombre y "Escuchar", y filas ✓ / ! que se tocan para corregir.
struct RevisionMedicina: View {
    let borrador: Borrador
    let alAbrir: (SeccionRevision?) -> Void
    let alConfirmarHorario: () -> Void

    @Query private var perfiles: [Perfil]

    /// Una fila de la revisión.
    struct Fila: Identifiable {
        let id: String
        let etiqueta: String
        let valor: String
        let falta: Bool
        let seccion: SeccionRevision?
        var nota: String? = nil
        var boton: String? = nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            tarjeta
            Text("¿Dice lo mismo tu receta?")
                .font(.headline)
                .foregroundStyle(ColoresRevision.gris)
                .padding(.top, 6)
            VStack(spacing: 0) {
                ForEach(Self.filas(de: borrador, perfil: perfiles.first)) { fila in
                    filaVista(fila)
                }
            }
            .overlay(alignment: .top) { Rectangle().fill(ColoresRevision.linea).frame(height: 1) }
            if let fuente = borrador.fuente {
                // Explicación: de dónde salió la propuesta, con las palabras de la foto.
                VStack(alignment: .leading, spacing: 6) {
                    Text("Esto dice tu foto")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(ColoresRevision.gris)
                    Text("«\(fuente)»")
                        .font(.title3)
                        .foregroundStyle(Paleta.tinta)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(ColoresRevision.superficie))
                .accessibilityElement(children: .combine)
            }
        }
    }

    private var tarjeta: some View {
        let sub = [borrador.concentracion, borrador.dosis].filter { !$0.isEmpty }.joined(separator: " · ")
        return ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 12) {
                encabezado(sub).frame(maxWidth: .infinity, alignment: .leading)
                botonEscuchar
            }
            VStack(alignment: .leading, spacing: 14) {
                encabezado(sub)
                botonEscuchar
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(ColoresRevision.superficie))
    }

    private func encabezado(_ sub: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(borrador.nombre.isEmpty ? "Sin nombre" : Borrador.nombreLegible(borrador.nombre))
                .font(.system(.largeTitle, design: .serif, weight: .semibold))
                .foregroundStyle(Paleta.tinta)
                .fixedSize(horizontal: false, vertical: true)
            if !sub.isEmpty {
                Text(sub)
                    .font(.title3)
                    .foregroundStyle(Paleta.tinta)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if borrador.tipoAccion != .toma {
                Label(borrador.tipoAccion.titulo, systemImage: borrador.tipoAccion.icono)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Paleta.tinta)
            }
        }
    }

    private var botonEscuchar: some View {
        Button {
            Voz.decir(borrador.lectura)
        } label: {
            Label("Escuchar", systemImage: "play.fill")
                .font(.body.weight(.semibold))
                .foregroundStyle(Paleta.tinta)
                .padding(.horizontal, 16)
                .frame(minHeight: 48)
                .background(Capsule().fill(ColoresRevision.escuchar))
        }
        .buttonStyle(EstiloPresionable())
        .accessibilityLabel("Escuchar \(borrador.nombre)")
    }

    private func filaVista(_ f: Fila) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                alAbrir(f.seccion)
            } label: {
                HStack(alignment: .center, spacing: 14) {
                    Image(systemName: f.falta ? "exclamationmark" : "checkmark")
                        .font(.body.weight(.bold))
                        .foregroundStyle(f.falta ? ColoresRevision.faltaTexto : ColoresRevision.okTinta)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(f.falta ? ColoresRevision.faltaFondo : ColoresRevision.okFondo))
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(f.etiqueta)
                            .font(.body)
                            .foregroundStyle(ColoresRevision.gris)
                        Text(f.valor)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(f.falta ? ColoresRevision.faltaTexto : Paleta.tinta)
                            .fixedSize(horizontal: false, vertical: true)
                        if let nota = f.nota {
                            Text(nota)
                                .font(.body)
                                .foregroundStyle(ColoresRevision.gris)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    if f.seccion != nil || f.id != "condicion" {
                        Image(systemName: "chevron.right")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(f.falta ? ColoresRevision.faltaTexto : ColoresRevision.gris)
                            .accessibilityHidden(true)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(EstiloPresionable())
            .disabled(f.id == "condicion")
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(f.etiqueta): \(f.valor)\(f.falta ? ". Falta" : "")")
            .accessibilityHint(f.id == "condicion" ? "" : "Toca para cambiarlo")

            if let boton = f.boton {
                Button {
                    if f.id == "confirmar" { alConfirmarHorario() } else { alAbrir(f.seccion) }
                } label: {
                    Text(boton)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Paleta.tinta)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Paleta.fondo))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Paleta.tinta, lineWidth: 2))
                }
                .buttonStyle(EstiloPresionable())
            }
        }
        .padding(.vertical, 16)
        .overlay(alignment: .bottom) { Rectangle().fill(ColoresRevision.linea).frame(height: 1) }
    }

    /// Las filas de la revisión, en el orden en que se leen en la receta.
    static func filas(de b: Borrador, perfil: Perfil? = nil) -> [Fila] {
        var r: [Fila] = []
        if b.dudoso("nombre") || b.nombre.isEmpty {
            r.append(Fila(id: "nombre", etiqueta: "Nombre",
                          valor: b.nombre.isEmpty ? "Falta el nombre" : "Revisa: \(Borrador.nombreLegible(b.nombre))",
                          falta: true, seccion: .nombre))
        }
        if b.dudoso("concentracion") {
            r.append(Fila(id: "mg", etiqueta: "Miligramos",
                          valor: b.concentracion.isEmpty ? "Falta revisar los miligramos" : "Revisa: \(b.concentracion)",
                          falta: true, seccion: .miligramos))
        }
        if b.tipoAccion == .toma || !b.dosis.isEmpty || b.dudoso("dosis") {
            let falta = b.dudoso("dosis") || (b.tipoAccion == .toma && b.dosis.isEmpty)
            let valor = b.dosis.isEmpty ? "Falta cuánto tomar" : (b.dudoso("dosis") ? "Revisa: \(b.dosis)" : b.dosis)
            r.append(Fila(id: "cuanto", etiqueta: b.tipoAccion == .toma ? "Cuánto cada vez" : "Cuánto",
                          valor: valor, falta: falta, seccion: .cuanto))
        }
        r.append(filaCuando(b, perfil: perfil))
        let diasDudoso = b.dudoso("duracionDias")
        r.append(Fila(id: "dias", etiqueta: "Por cuánto tiempo",
                      valor: diasDudoso ? "Revisa: \(b.textoDuracion)" : b.textoDuracion,
                      falta: diasDudoso, seccion: .dias))
        if b.dudoso("condicion") {
            r.append(Fila(id: "condicion", etiqueta: "En qué caso se usa",
                          valor: "Depende de una condición. Revísala con tu médico.",
                          falta: true, seccion: nil))
        }
        if let ind = b.indicaciones, !ind.isEmpty {
            r.append(Fila(id: "indicaciones", etiqueta: "Indicaciones",
                          valor: Borrador.indicacionesLegibles(ind), falta: false, seccion: nil))
        }
        return r
    }

    private static func filaCuando(_ b: Borrador, perfil: Perfil?) -> Fila {
        if b.faltaElegirIntervalo, let rango = b.rangoHoras {
            return Fila(id: "cuando", etiqueta: "Cuándo · cada \(rango.lowerBound) a \(rango.upperBound) horas",
                        valor: "Falta elegir cada cuántas horas", falta: true, seccion: .cadaHoras,
                        boton: "Elegir cada cuántas horas")
        }
        if let horas = b.cadaHoras {
            let cada = horas == 1 ? "cada hora" : "cada \(horas) horas"
            guard let inicio = b.inicioIntervalo else {
                return Fila(id: "cuando", etiqueta: "Cuándo · \(cada)", valor: "Falta elegir la hora", falta: true,
                            seccion: .primeraVez, boton: "Elegir a qué hora la tomo")
            }
            let dudoso = b.dudoso("cadaHoras")
            return Fila(id: "cuando", etiqueta: "Cuándo · \(cada)",
                        valor: "Empieza \(inicio.formatted(.dateTime.weekday(.wide).locale(Locale(identifier: "es_MX")))) a las \(inicio.horaHablada)",
                        falta: dudoso, seccion: .cadaHoras)
        }
        guard !b.momentos.isEmpty else {
            return Fila(id: "cuando", etiqueta: "Cuándo", valor: "Falta elegir cuándo", falta: true,
                        seccion: .cuando, boton: "Elegir cuándo la tomo")
        }
        let partes = b.momentos.map { m -> String in
            if case .horaFija = m { return m.texto }
            guard let perfil else { return m.texto }
            let h = perfil.hora(de: m)
            let fecha = Calendar.current.date(bySettingHour: h.hour ?? 0, minute: h.minute ?? 0, second: 0, of: .now) ?? .now
            return "\(m.texto) (\(fecha.horaHablada))"
        }
        let valor = partes.formatted(.list(type: .and).locale(Locale(identifier: "es_MX"))).capitalizedPrimera
        if b.soloConfirmarHorario {
            return Fila(id: "confirmar", etiqueta: "Cuándo · lo acomodé a tu rutina", valor: valor, falta: true,
                        seccion: .cuando, nota: b.motivoHorario?.capitalizedPrimera, boton: "Sí, este horario me queda")
        }
        let falta = b.dudoso("momentos") || b.dudoso("horario")
        return Fila(id: "cuando", etiqueta: "Cuándo", valor: valor, falta: falta, seccion: .cuando,
                    nota: b.motivoHorario?.capitalizedPrimera)
    }
}

/// Opción tipo radio del diseño: círculo de 28 pt, coral con ✓ al elegirla y borde negro en la tarjeta.
struct OpcionRadio: View {
    let titulo: String
    var subtitulo: String? = nil
    let elegido: Bool
    let accion: () -> Void

    var body: some View {
        Button(action: accion) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .strokeBorder(elegido ? Paleta.acento : ColoresRevision.radioVacio, lineWidth: 2)
                    if elegido {
                        Circle().fill(Paleta.acento)
                        Image(systemName: "checkmark")
                            .font(.footnote.weight(.bold))
                            .foregroundStyle(Color.white)
                    }
                }
                .frame(width: 28, height: 28)
                .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(titulo)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Paleta.tinta)
                        .fixedSize(horizontal: false, vertical: true)
                    if let subtitulo {
                        Text(subtitulo)
                            .font(.body)
                            .foregroundStyle(ColoresRevision.gris)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: subtitulo == nil ? 64 : 68, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Paleta.fondo))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(elegido ? Paleta.tinta : ColoresRevision.linea, lineWidth: 2))
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(EstiloPresionable())
        .accessibilityAddTraits(elegido ? .isSelected : [])
    }
}

/// "Corregir": primero lo que falta (abierto, en rosa), luego "Lo demás ya está bien" (cerrado, con "Cambiar").
/// MiMi escucha con el botón de micrófono. Al tocar "Listo", lo revisado deja de estar en rojo.
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
    /// Lo que la persona ya tocó en esta hoja (un bloque "Falta" pasa a "✓ Listo").
    @State private var tocadas: Set<SeccionRevision> = []
    /// Secciones de "Lo demás" abiertas con "Cambiar".
    @State private var abiertas: Set<SeccionRevision>
    /// Lo que faltaba al abrir; se queda arriba aunque ya se haya elegido.
    private let faltaban: [SeccionRevision]
    /// Completar por voz: MiMi llena los campos y la persona revisa antes de tocar "Listo".
    @State private var dictado = Dictado()
    @State private var entendido: String?

    enum Inicio: Hashable { case ahora, enUnaHora, desayuno, otra }

    init(borrador: Borrador, seccion: SeccionRevision? = nil, alGuardar: @escaping (Borrador) -> Void) {
        self.alGuardar = alGuardar
        _b = State(initialValue: borrador)
        _horas = State(initialValue: borrador.cadaHoras.map { String($0) } ?? "")
        _porHoras = State(initialValue: borrador.tieneIntervalo)
        _primeraVez = State(initialValue: borrador.inicioIntervalo ?? Self.proximoMinuto(.now))
        _inicio = State(initialValue: borrador.inicioIntervalo == nil ? nil : .otra)
        let faltan = Self.faltantes(de: borrador)
        faltaban = faltan
        // La sección que se tocó en la pantalla se abre (si no está ya arriba como "Falta").
        let abrir: Set<SeccionRevision> = seccion.map { faltan.contains($0) ? Set<SeccionRevision>() : Set([$0]) } ?? []
        _abiertas = State(initialValue: abrir)
    }

    private static func faltantes(de b: Borrador) -> [SeccionRevision] {
        var r: [SeccionRevision] = []
        if b.dudoso("nombre") || b.nombre.isEmpty { r.append(.nombre) }
        if b.dudoso("concentracion") { r.append(.miligramos) }
        if b.dudoso("dosis") || (b.tipoAccion == .toma && b.dosis.isEmpty) { r.append(.cuanto) }
        if b.tieneIntervalo {
            if b.faltaElegirIntervalo || b.dudoso("cadaHoras") { r.append(.cadaHoras) }
            if b.faltaPrimeraVez { r.append(.primeraVez) }
        } else if b.momentos.isEmpty || b.dudoso("momentos") || b.dudoso("horario") {
            r.append(.cuando)
        }
        if b.dudoso("duracionDias") { r.append(.dias) }
        return r
    }

    private static func proximoMinuto(_ fecha: Date) -> Date {
        Calendar.current.dateInterval(of: .minute, for: fecha)?.end ?? fecha
    }

    private var intervaloValido: Int? {
        guard let horas = Int(horas), horas > 0, b.rangoHoras?.contains(horas) != false else { return nil }
        return horas
    }

    private func horaRutina(_ m: Momento) -> Date {
        let h = perfiles.first?.hora(de: m) ?? DateComponents(hour: 8, minute: 0)
        return Calendar.current.date(bySettingHour: h.hour ?? 8, minute: h.minute ?? 0, second: 0, of: .now) ?? .now
    }

    /// Mañana a la hora del desayuno de la rutina (8:00 si no hay rutina).
    private var mananaDesayuno: Date {
        let manana = Calendar.current.date(byAdding: .day, value: 1, to: horaRutina(.desayuno)) ?? .now
        return manana
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

    /// "8:00 de la mañana y 8:00 de la noche": las horas del primer día con ese intervalo.
    private var horasDeAviso: String? {
        guard porHoras, let fechaInicio, let n = intervaloValido else { return nil }
        let veces = max(1, min(24 / n, 6))
        let horas = (0..<veces).map { fechaInicio.addingTimeInterval(TimeInterval($0 * n * 3600)).horaHablada }
        return horas.formatted(.list(type: .and).locale(Locale(identifier: "es_MX")))
    }

    /// ¿Ya quedó resuelta esta sección?
    private func resuelta(_ s: SeccionRevision) -> Bool {
        switch s {
        case .nombre: !b.nombre.trimmingCharacters(in: .whitespaces).isEmpty && (tocadas.contains(.nombre) || !b.dudoso("nombre"))
        case .tipo: true
        case .miligramos: tocadas.contains(.miligramos)
        case .cuanto: (b.tipoAccion != .toma || !b.dosis.trimmingCharacters(in: .whitespaces).isEmpty)
            && (tocadas.contains(.cuanto) || !b.dudoso("dosis"))
        case .cuando: !b.momentos.isEmpty && (tocadas.contains(.cuando) || !(b.dudoso("momentos") || b.dudoso("horario")))
        case .cadaHoras: intervaloValido != nil && (tocadas.contains(.cadaHoras) || !b.dudoso("cadaHoras"))
        case .primeraVez: fechaInicio != nil
        case .dias: tocadas.contains(.dias)
        }
    }

    /// Lo que falta para poder tocar "Listo", dicho como acción ("Elige una hora para seguir").
    private var falta: String? {
        if b.nombre.trimmingCharacters(in: .whitespaces).isEmpty { return "Escribe el nombre para seguir" }
        if b.tipoAccion == .toma && b.dosis.trimmingCharacters(in: .whitespaces).isEmpty { return "Elige cuánto tomas para seguir" }
        if porHoras {
            if intervaloValido == nil { return "Elige cada cuántas horas para seguir" }
            if fechaInicio == nil { return "Elige una hora para seguir" }
        } else if b.momentos.isEmpty {
            return "Elige cuándo la tomas para seguir"
        }
        for s in faltaban where !resuelta(s) {
            switch s {
            case .nombre: return "Revisa el nombre para seguir"
            case .miligramos: return "Revisa los miligramos para seguir"
            case .cuanto: return "Elige cuánto tomas para seguir"
            case .cuando: return "Elige cuándo la tomas para seguir"
            case .cadaHoras: return "Elige cada cuántas horas para seguir"
            case .primeraVez: return "Elige una hora para seguir"
            case .dias: return "Elige por cuántos días para seguir"
            case .tipo: break
            }
        }
        return nil
    }

    /// Secciones de "Lo demás ya está bien", según cómo se toma.
    private var demas: [SeccionRevision] {
        var r: [SeccionRevision] = [.nombre, .tipo]
        if b.tipoAccion != .cuidado { r.append(.miligramos) }
        r.append(.cuanto)
        r += porHoras ? [.cadaHoras, .primeraVez] : [.cuando]
        r.append(.dias)
        return r.filter { !faltaban.contains($0) }
    }

    private let columnas = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    var body: some View {
        VStack(spacing: 0) {
            // Encabezado: Cancelar a la izquierda, "Corregir" al centro. Sin "Listo" arriba.
            ZStack {
                Text("Corregir")
                    .font(.headline)
                    .foregroundStyle(Paleta.tinta)
                    .accessibilityAddTraits(.isHeader)
                HStack {
                    Button {
                        dictado.detener()
                        cerrar()
                    } label: {
                        Text("Cancelar")
                            .font(.title3)
                            .foregroundStyle(Paleta.tinta)
                            .padding(.horizontal, 18)
                            .frame(minHeight: 48)
                            .overlay(Capsule().strokeBorder(ColoresRevision.linea, lineWidth: 1))
                    }
                    .buttonStyle(EstiloPresionable())
                    Spacer()
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)
            .overlay(alignment: .bottom) { Rectangle().fill(ColoresRevision.linea).frame(height: 1) }

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ForEach(faltaban, id: \.self) { s in bloqueFalta(s) }
                    if !demas.isEmpty {
                        Text(faltaban.isEmpty ? "Toca «Cambiar» en lo que quieras corregir" : "Lo demás ya está bien")
                            .font(.headline)
                            .foregroundStyle(ColoresRevision.gris)
                            .padding(.top, 4)
                        VStack(spacing: 0) {
                            ForEach(demas, id: \.self) { s in filaDemas(s) }
                        }
                        .overlay(alignment: .top) { Rectangle().fill(ColoresRevision.linea).frame(height: 1) }
                    }
                    estadoMiMi
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 110)   // espacio para el botón de MiMi
            }
            .overlay(alignment: .bottomTrailing) { botonMiMi }

            // Pie fijo: un solo botón.
            Button { listo() } label: {
                Label(falta ?? "Listo", systemImage: falta == nil ? "checkmark" : "hand.point.up.left")
                    .labelStyle(.titleAndIcon)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(falta == nil ? Color.white : ColoresRevision.textoDeshabilitado)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, minHeight: 64)
                    .background(RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(falta == nil ? Paleta.tinta : ColoresRevision.deshabilitado))
            }
            .buttonStyle(EstiloPresionable())
            .disabled(falta != nil)
            .padding(.horizontal, 24)
            .padding(.top, 14)
            .padding(.bottom, 16)
            .overlay(alignment: .top) { Rectangle().fill(ColoresRevision.linea).frame(height: 1) }
        }
        .background(Paleta.fondo.ignoresSafeArea())
        .presentationDetents([.large])
        .presentationCornerRadius(28)
        .interactiveDismissDisabled()
        .onChange(of: dictado.transcribiendo) { _, ahora in
            if !ahora, !dictado.texto.isEmpty {
                aplicarDictado(dictado.texto)
                dictado.texto = ""
            }
        }
        .onDisappear { dictado.detener() }
    }

    // MARK: Bloques

    private func pregunta(_ s: SeccionRevision) -> String {
        switch s {
        case .nombre: "¿Cómo se llama?"
        case .tipo: "¿Qué es?"
        case .miligramos: "¿De cuántos miligramos?"
        case .cuanto: b.tipoAccion == .toma ? "¿Cuánto tomas cada vez?" : "¿Cuánto? (si la receta lo dice)"
        case .cuando: "¿Cuándo la tomas?"
        case .cadaHoras: "¿Cada cuántas horas?"
        case .primeraVez: "¿A qué hora la tomas la primera vez?"
        case .dias: "¿Por cuántos días?"
        }
    }

    private func etiqueta(_ s: SeccionRevision) -> String {
        switch s {
        case .nombre: "Nombre"
        case .tipo: "Qué es"
        case .miligramos: "Miligramos"
        case .cuanto: "Cuánto cada vez"
        case .cuando: "Cuándo"
        case .cadaHoras: "Cada cuántas horas"
        case .primeraVez: "Primera vez"
        case .dias: "Por cuántos días"
        }
    }

    private func valor(_ s: SeccionRevision) -> String {
        switch s {
        case .nombre: b.nombre.isEmpty ? "Sin nombre" : Borrador.nombreLegible(b.nombre)
        case .tipo: textoTipo
        case .miligramos: b.concentracion.isEmpty ? "Sin dato" : b.concentracion
        case .cuanto: b.dosis.isEmpty ? "Sin dato" : b.dosis
        case .cuando: b.textoMomentos
        case .cadaHoras: intervaloValido.map { $0 == 1 ? "Cada hora" : "Cada \($0) horas" } ?? "Sin elegir"
        case .primeraVez: fechaInicio.map { $0.horaHablada.capitalizedPrimera } ?? "Sin elegir"
        case .dias: b.textoDuracion
        }
    }

    private var textoTipo: String {
        switch b.tipoAccion {
        case .toma: "Algo que tomo"
        case .aplicacion: "Algo que me pongo"
        case .cuidado: "Algo que hago"
        }
    }

    /// Lo que faltaba: abierto, en rosa con "Falta"; al resolverse pasa a gris con "✓ Listo".
    private func bloqueFalta(_ s: SeccionRevision) -> some View {
        let ok = resuelta(s)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Text(pregunta(s))
                    .font(.system(.title2, design: .serif, weight: .semibold))
                    .foregroundStyle(Paleta.tinta)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityAddTraits(.isHeader)
                Text(ok ? "✓ Listo" : "Falta")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(ok ? ColoresRevision.okTinta : ColoresRevision.faltaPill)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(ok ? ColoresRevision.okFondo : ColoresRevision.faltaFondo))
            }
            opciones(s)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(ok ? ColoresRevision.superficie : ColoresRevision.faltaBloque))
        .animation(MovimientoMiMi.cambio, value: ok)
    }

    /// Lo que ya está bien: cerrado con ✓ y "Cambiar"; abierto muestra las opciones y "Cerrar".
    private func filaDemas(_ s: SeccionRevision) -> some View {
        let abierta = abiertas.contains(s)
        return VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(MovimientoMiMi.cambio) {
                    if abierta { abiertas.remove(s) } else { abiertas.insert(s) }
                }
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: "checkmark")
                        .font(.body.weight(.bold))
                        .foregroundStyle(ColoresRevision.okTinta)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(ColoresRevision.okFondo))
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(etiqueta(s))
                            .font(.body)
                            .foregroundStyle(ColoresRevision.gris)
                        Text(valor(s))
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(Paleta.tinta)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Text(abierta ? "Cerrar" : "Cambiar")
                        .font(.headline)
                        .underline()
                        .foregroundStyle(Paleta.tinta)
                }
                .padding(.vertical, 16)
                .contentShape(Rectangle())
            }
            .buttonStyle(EstiloPresionable())
            .accessibilityLabel("\(etiqueta(s)): \(valor(s))")
            .accessibilityHint(abierta ? "Cierra las opciones" : "Muestra las opciones para cambiarlo")
            if abierta {
                opciones(s)
                    .padding(.bottom, 16)
            }
        }
        .overlay(alignment: .bottom) { Rectangle().fill(ColoresRevision.linea).frame(height: 1) }
    }

    // MARK: Opciones de cada sección

    @ViewBuilder private func opciones(_ s: SeccionRevision) -> some View {
        switch s {
        case .nombre:
            campo("Por ejemplo, Losartán", texto: $b.nombre) { tocadas.insert(.nombre) }
        case .tipo:
            VStack(spacing: 10) {
                OpcionRadio(titulo: "Una pastilla, jarabe o algo que tomo", elegido: b.tipoAccion == .toma) { b.tipoAccion = .toma }
                OpcionRadio(titulo: "Una crema, gotas o algo que me pongo", elegido: b.tipoAccion == .aplicacion) { b.tipoAccion = .aplicacion }
                OpcionRadio(titulo: "Algo que hago, como caminar", elegido: b.tipoAccion == .cuidado) { b.tipoAccion = .cuidado }
            }
        case .miligramos:
            campo("Por ejemplo, 50 mg", texto: $b.concentracion) { tocadas.insert(.miligramos) }
            if b.dudoso("concentracion") {
                BotonGrande(titulo: "Está bien así", icono: "checkmark", estilo: .secundario) { tocadas.insert(.miligramos) }
            }
        case .cuanto:
            VStack(spacing: 10) {
                if b.tipoAccion == .toma {
                    LazyVGrid(columns: columnas, spacing: 10) {
                        ForEach(["½ tableta", "1 tableta", "2 tabletas", "1 cápsula"], id: \.self) { d in
                            OpcionRadio(titulo: d, elegido: b.dosis == d) {
                                b.dosis = d
                                tocadas.insert(.cuanto)
                            }
                        }
                    }
                }
                campo("Otra cantidad", texto: $b.dosis) { tocadas.insert(.cuanto) }
            }
        case .cuando:
            VStack(spacing: 10) {
                if b.tipoAccion != .toma && b.rangoHoras == nil {
                    OpcionRadio(titulo: "Cada cierto número de horas", elegido: false) {
                        porHoras = true
                        tocadas.insert(.cuando)
                    }
                }
                LazyVGrid(columns: columnas, spacing: 10) {
                    ForEach(Momento.rutina, id: \.self) { m in
                        OpcionRadio(titulo: m.nombre, subtitulo: horaRutina(m).horaHablada, elegido: b.momentos.contains(m)) {
                            alternar(m)
                            tocadas.insert(.cuando)
                        }
                    }
                }
            }
        case .cadaHoras:
            VStack(spacing: 10) {
                let lista: [Int] = b.rangoHoras.map { r in r.upperBound - r.lowerBound < 6 ? Array(r) : [] } ?? [4, 6, 8, 12]
                if let r = b.rangoHoras {
                    Text("Tu receta dice cada \(r.lowerBound) a \(r.upperBound) horas. Elige una:")
                        .font(.body)
                        .foregroundStyle(Paleta.tinta)
                        .fixedSize(horizontal: false, vertical: true)
                }
                LazyVGrid(columns: columnas, spacing: 10) {
                    ForEach(lista, id: \.self) { h in
                        OpcionRadio(titulo: h == 1 ? "Cada hora" : "Cada \(h) horas", elegido: horas == String(h)) {
                            horas = String(h)
                            tocadas.insert(.cadaHoras)
                        }
                    }
                }
                campo("Otro número de horas", texto: $horas) { tocadas.insert(.cadaHoras) }
                    .keyboardType(.numberPad)
                if b.tipoAccion != .toma && b.rangoHoras == nil {
                    OpcionRadio(titulo: "Mejor con mis comidas o al dormir", elegido: false) {
                        porHoras = false
                        tocadas.insert(.cadaHoras)
                    }
                }
            }
        case .primeraVez:
            VStack(spacing: 10) {
                let ahora = Self.proximoMinuto(.now)
                OpcionRadio(titulo: "Ahora", subtitulo: ahora.horaHablada, elegido: inicio == .ahora) { inicio = .ahora }
                OpcionRadio(titulo: "En 1 hora", subtitulo: ahora.addingTimeInterval(3600).horaHablada,
                            elegido: inicio == .enUnaHora) { inicio = .enUnaHora }
                OpcionRadio(titulo: "Mañana con el desayuno", subtitulo: mananaDesayuno.horaHablada,
                            elegido: inicio == .desayuno) { inicio = .desayuno }
                OpcionRadio(titulo: "Otro día u hora", subtitulo: "Elígelo en el reloj", elegido: inicio == .otra) { inicio = .otra }
                if inicio == .otra {
                    DatePicker("Primera vez", selection: $primeraVez)
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                        .frame(maxWidth: .infinity)
                        .environment(\.locale, Locale(identifier: "es_MX"))
                }
                if let horasDeAviso {
                    Text("Te aviso a las \(Text(horasDeAviso).bold()).")
                        .font(.title3)
                        .foregroundStyle(ColoresRevision.okTexto)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(ColoresRevision.okFondo))
                }
            }
        case .dias:
            LazyVGrid(columns: columnas, spacing: 10) {
                ForEach([nil, 7, 14, 30] as [Int?], id: \.self) { d in
                    OpcionRadio(titulo: d.map { "\($0) días" } ?? "Siempre",
                                elegido: b.duracionDias == d && (tocadas.contains(.dias) || !faltaban.contains(.dias))) {
                        b.duracionDias = d
                        tocadas.insert(.dias)
                    }
                }
            }
        }
    }

    private func campo(_ ejemplo: String, texto: Binding<String>, alCambiar: @escaping () -> Void) -> some View {
        TextField(ejemplo, text: texto)
            .font(.title3)
            .foregroundStyle(Paleta.tinta)
            .padding(.horizontal, 18)
            .frame(minHeight: 60)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Paleta.fondo))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(ColoresRevision.linea, lineWidth: 2))
            .onChange(of: texto.wrappedValue) { alCambiar() }
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

    // MARK: MiMi

    /// Botón flotante de MiMi (micrófono), abajo a la derecha, arriba del pie.
    private var botonMiMi: some View {
        Button {
            Voz.callar()
            Task { await dictado.alternar() }
        } label: {
            Image(systemName: dictado.escuchando ? "stop.fill" : "mic.fill")
                .font(.title2.weight(.semibold))
                .foregroundStyle(Color.white)
                .frame(width: 68, height: 68)
                .background(Circle().fill(Paleta.acento))
                .overlay(Circle().strokeBorder(Color.white, lineWidth: 4))
                .shadow(color: Color.black.opacity(0.22), radius: 9, y: 6)
        }
        .buttonStyle(EstiloPresionable())
        .disabled(dictado.transcribiendo)
        .padding(.trailing, 20)
        .padding(.bottom, 18)
        .accessibilityLabel(dictado.escuchando ? "Ya terminé de hablar" : "Hablarle a MiMi")
        .accessibilityHint("Di, por ejemplo: una tableta con el desayuno por siete días")
    }

    @ViewBuilder private var estadoMiMi: some View {
        let texto: String? = if dictado.escuchando {
            "Te escucho… cuando dejes de hablar, me detengo solo."
        } else if dictado.transcribiendo {
            "Pensando…"
        } else if let error = dictado.error {
            error
        } else {
            entendido
        }
        HStack(alignment: .top, spacing: 12) {
            IconoMiMi(tamano: 40)
            Text(texto ?? "También me lo puedes decir: toca el micrófono y di, por ejemplo, «una tableta con el desayuno por siete días».")
                .font(.body)
                .foregroundStyle(Paleta.tinta)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Paleta.salvia))
        .accessibilityElement(children: .combine)
    }

    /// Llena lo que entendió y dice qué cambió. No guarda: la persona revisa y toca "Listo".
    private func aplicarDictado(_ texto: String) {
        let r = DictadoReceta.leer(texto)
        var partes: [String] = []
        if let dosis = r.dosis {
            b.dosis = dosis
            tocadas.insert(.cuanto)
            partes.append(dosis)
        }
        if let n = r.cadaHoras {
            porHoras = true
            horas = String(n)
            tocadas.insert(.cadaHoras)
            partes.append(n == 1 ? "cada hora" : "cada \(n) horas")
        }
        if !porHoras, !r.momentos.isEmpty {
            b.momentos = r.momentos.sorted { orden($0) < orden($1) }
            tocadas.insert(.cuando)
            partes.append(b.momentos.map(\.texto).formatted(.list(type: .and).locale(Locale(identifier: "es_MX"))))
        }
        if porHoras, let hora = r.hora {
            primeraVez = DictadoReceta.proxima(hora)
            inicio = .otra
            partes.append("empiezas a las \(primeraVez.horaHablada)")
        }
        if r.siempre {
            b.duracionDias = nil
            tocadas.insert(.dias)
            partes.append("sin fecha de fin")
        } else if let dias = r.dias {
            b.duracionDias = dias
            tocadas.insert(.dias)
            partes.append("por \(dias) días")
        }
        guard !partes.isEmpty else {
            entendido = nil
            dictado.error = "No te entendí. Prueba con: «una tableta en la mañana por siete días»."
            Voz.decir("No te entendí. Prueba otra vez, o elige en la pantalla.")
            return
        }
        dictado.error = nil
        let frase = "Entendí: " + partes.joined(separator: ", ") + ". Revísalo y toca Listo."
        entendido = frase
        Voz.decir(frase)
    }

    private func listo() {
        guard falta == nil else { return }
        dictado.detener()
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
