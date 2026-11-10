import SwiftUI
import SwiftData

/// Inicio (RF-04): solo lo importante. Qué sigue, cómo vas hoy, una vista previa de la semana
/// (lleva a Calendario) y lo que viene más tarde.
struct TuDiaView: View {
    @Environment(Navegacion.self) private var navegacion
    @Query(filter: #Predicate<Medicamento> { $0.activo }, sort: \Medicamento.nombre) private var medicamentos: [Medicamento]
    @Query private var perfiles: [Perfil]
    @Query private var registros: [RegistroToma]
    @Query(sort: \NotaReceta.fecha, order: .reverse) private var notas: [NotaReceta]
    @State private var control = ControlTomas()
    @Environment(\.dynamicTypeSize) private var tamano

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { linea in
            contenido(ahora: linea.date)
        }
        .background(Paleta.fondo.ignoresSafeArea())
        .controlDeTomas(control)
    }

    @ViewBuilder private func contenido(ahora: Date) -> some View {
        let hoy = Agenda.tomas(en: ahora, meds: medicamentos, perfil: perfiles.first, registros: registros)
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                encabezado(ahora: ahora)
                    .entradaMiMi()
                if medicamentos.isEmpty && notas.isEmpty {
                    TarjetaPastel(color: Paleta.lavanda,
                                  ilustracion: Ilustracion(nombre: "ilus-vacio", simbolo: "leaf", color: .clear, color2: .clear, alto: 130)) {
                        Text("Agrega tu primera medicina")
                            .font(Tipo.tarjeta)
                            .foregroundStyle(Paleta.tinta)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("Con una foto de tu receta armo tu día.")
                            .font(.body)
                            .foregroundStyle(Paleta.tinta)
                            .fixedSize(horizontal: false, vertical: true)
                        BotonFlecha(etiqueta: "Agregar medicina") { navegacion.pestana = .escanear }
                            .padding(.top, 6)
                    }
                } else if !medicamentos.isEmpty {
                    principal(hoy, ahora: ahora)
                        .id(hoy.first(where: { [.teToca, .preguntar, .pendiente].contains($0.estado(ahora: ahora)) })?.id ?? "descanso")
                        .transition(.opacity)
                        .entradaMiMi(orden: 1)
                    if !hoy.isEmpty { progreso(hoy, ahora: ahora) }
                    SemanaPrevia(hoy: ahora) { d in
                        Agenda.resumen(Agenda.tomas(en: d, meds: medicamentos, perfil: perfiles.first, registros: registros), ahora: ahora)
                    } alAbrir: {
                        navegacion.pestana = .calendario
                    }
                    masTarde(hoy, ahora: ahora)
                        .entradaMiMi(orden: 3)
                }
                if !notas.isEmpty { recuerda }
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 32)
            .cambioMiMi(hoy.map { $0.registro?.estadoRaw ?? "pendiente" })
        }
    }

    // MARK: Piezas

    private func encabezado(ahora: Date) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(ahora.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(Locale(identifier: "es_MX"))))
                .estiloMayusculas()
            Text(saludo(ahora))
                .font(Tipo.grande)
                .foregroundStyle(Paleta.tinta)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
        }
        .padding(.top, 16)
        .accessibilityElement(children: .combine)
    }

    private func saludo(_ ahora: Date) -> String {
        let h = Calendar.current.component(.hour, from: ahora)
        let base = h < 12 ? "Buenos días" : (h < 19 ? "Buenas tardes" : "Buenas noches")
        let nombre = perfiles.first?.nombre.trimmingCharacters(in: .whitespaces) ?? ""
        return nombre.isEmpty ? base : "\(base),\n\(nombre)"
    }

    /// Una sola tarjeta grande: lo que te toca, lo que sigue o "listo por hoy".
    @ViewBuilder private func principal(_ hoy: [TomaDelDia], ahora: Date) -> some View {
        if let urgente = hoy.first(where: { [.teToca, .preguntar].contains($0.estado(ahora: ahora)) }) {
            let estado = urgente.estado(ahora: ahora)
            TarjetaPastel(color: Paleta.durazno, icono: urgente.med) {
                Text(estado == .preguntar ? urgente.med.preguntaRegistro : "Te toca ahora").estiloMayusculas()
                Text(urgente.med.nombreVisible.capitalizedPrimera)
                    .font(Tipo.titulo)
                    .foregroundStyle(Paleta.tinta)
                    .fixedSize(horizontal: false, vertical: true)
                Text("\(urgente.detalle) · \(urgente.hora)")
                    .font(.body)
                    .foregroundStyle(Paleta.tinta)
                    .fixedSize(horizontal: false, vertical: true)
                if urgente.med.tipoAccion == .cuidado, let indicaciones = urgente.med.indicaciones, !indicaciones.isEmpty {
                    Text(indicaciones.capitalizedPrimera)
                        .font(.body)
                        .foregroundStyle(Paleta.tinta)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } abajo: {
                VStack(spacing: 10) {
                    BotonGrande(titulo: urgente.med.accionRegistro, icono: "checkmark") {
                        control.tomar(urgente)
                    }
                    if estado == .preguntar {
                        BotonGrande(titulo: "No, se me pasó", estilo: .secundario) { control.sePaso(urgente) }
                    }
                }
            }
        } else if let siguiente = hoy.first(where: { $0.estado(ahora: ahora) == .pendiente }) {
            TarjetaPastel(color: Paleta.lavanda, icono: siguiente.med) {
                Text("Lo siguiente").estiloMayusculas()
                Text(siguiente.med.nombreVisible.capitalizedPrimera)
                    .font(Tipo.titulo)
                    .foregroundStyle(Paleta.tinta)
                    .fixedSize(horizontal: false, vertical: true)
                Text("\(siguiente.hora) · \(siguiente.toma.momento.texto)")
                    .font(.body)
                    .foregroundStyle(Paleta.tinta)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .onTapGesture { control.elegida = siguiente }
        } else if !hoy.isEmpty {
            TarjetaPastel(color: Paleta.sol,
                          ilustracion: Ilustracion(nombre: "ilus-listo", simbolo: "checkmark.seal", color: .clear, color2: .clear, alto: 120)) {
                Text("Listo por hoy").font(Tipo.titulo).foregroundStyle(Paleta.tinta)
                Text("Ya registraste todo lo de hoy.")
                    .font(.body)
                    .foregroundStyle(Paleta.tinta)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } else {
            TarjetaPastel(color: Paleta.durazno,
                          ilustracion: Ilustracion(nombre: "ilus-tudia", simbolo: "sun.max", color: .clear, color2: .clear, alto: 120)) {
                Text("Hoy no te toca ninguna").font(Tipo.titulo).foregroundStyle(Paleta.tinta)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Revisa los próximos días en Calendario.")
                    .font(.body)
                    .foregroundStyle(Paleta.tinta)
            }
        }
    }

    private func cuenta(_ hechas: Int, de total: Int) -> some View {
        Text("\(hechas) de \(total) registradas")
            .font(.body.weight(.semibold))
            .foregroundStyle(Paleta.tinta)
            .contentTransition(.numericText())
    }

    private func progreso(_ hoy: [TomaDelDia], ahora: Date) -> some View {
        let hechas = hoy.filter { $0.estado(ahora: ahora).registrada }.count
        return VStack(alignment: .leading, spacing: 10) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Hoy").font(Tipo.tarjeta).foregroundStyle(Paleta.tinta)
                    Spacer()
                    cuenta(hechas, de: hoy.count)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Hoy").font(Tipo.tarjeta).foregroundStyle(Paleta.tinta)
                    cuenta(hechas, de: hoy.count)
                }
            }
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Paleta.base100)
                    Capsule()
                        .fill(Paleta.acento)
                        .frame(width: max(10, g.size.width * CGFloat(hechas) / CGFloat(max(hoy.count, 1))))
                }
            }
            .frame(height: 10)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Hoy: \(hechas) de \(hoy.count) actividades registradas")
        .cambioMiMi(hechas)
        .entradaMiMi(orden: 2)
    }

    /// Notas de la receta (dieta, cuidados, próxima cita) para que no se pierdan.
    private var recuerda: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Tu receta también dice").font(Tipo.tarjeta).foregroundStyle(Paleta.tinta)
                Spacer()
                if notas.count > 3 {
                    Button("Ver todas") { navegacion.pestana = .perfil }
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Paleta.tinta)
                        .underline()
                        .frame(minHeight: 44)
                }
            }
            ForEach(notas.prefix(3)) { nota in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "note.text").foregroundStyle(Paleta.tinta).accessibilityHidden(true)
                    Text(nota.texto.capitalizedPrimera)
                        .font(.body)
                        .foregroundStyle(Paleta.tinta)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.vertical, 4)
            }
        }
        .tarjeta(relleno: 20, color: Paleta.sol.opacity(0.45))
    }

    /// Hasta 3 tomas pendientes después de la principal (hoy y mañana), en filas simples.
    @ViewBuilder private func masTarde(_ hoy: [TomaDelDia], ahora: Date) -> some View {
        let manana = Calendar.current.date(byAdding: .day, value: 1, to: ahora) ?? ahora
        let siguientesTodas = (hoy + Agenda.tomas(en: manana, meds: medicamentos, perfil: perfiles.first, registros: registros))
            .filter { $0.estado(ahora: ahora) == .pendiente }
        // Si la tarjeta principal ya muestra la siguiente toma, no se repite aquí.
        let hayUrgente = hoy.contains { [.teToca, .preguntar].contains($0.estado(ahora: ahora)) }
        let siguientes = Array((hayUrgente ? siguientesTodas[...] : siguientesTodas.dropFirst()).prefix(3))
        if !siguientes.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text("Más tarde").font(Tipo.tarjeta).foregroundStyle(Paleta.tinta)
                    .padding(.bottom, 8)
                ForEach(Array(siguientes.enumerated()), id: \.element.id) { i, t in
                    if i > 0 { Divider() }
                    Button { control.elegida = t } label: {
                        let fila = tamano.isAccessibilitySize
                            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
                            : AnyLayout(HStackLayout(spacing: 14))
                        fila {
                            IconoMedicamento(t.med, tamano: 46)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(t.med.nombreVisible.capitalizedPrimera)
                                    .font(.system(.title3, design: .serif, weight: .semibold))
                                    .foregroundStyle(Paleta.tinta)
                                    .fixedSize(horizontal: false, vertical: true)
                                Text(t.med.dosis)
                                    .font(.body)
                                    .foregroundStyle(Paleta.tintaSuave)
                            }
                            if !tamano.isAccessibilitySize { Spacer() }
                            VStack(alignment: tamano.isAccessibilitySize ? .leading : .trailing, spacing: 2) {
                                Text(t.hora).font(Tipo.etiqueta).foregroundStyle(Paleta.tinta)
                                if !Calendar.current.isDate(t.toma.fecha, inSameDayAs: ahora) {
                                    Text("Mañana").font(.body).foregroundStyle(Paleta.tintaSuave)
                                }
                            }
                        }
                        .padding(.vertical, 10)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(EstiloPresionable())
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }
}

// MARK: - Tarjeta pastel (como las de la referencia)

/// Tarjeta pastel grande: texto a la izquierda, ilustración o medicina a la derecha y, opcional, botones abajo.
struct TarjetaPastel<Texto: View, Abajo: View>: View {
    let color: Color
    var ilustracion: Ilustracion? = nil
    var icono: Medicamento? = nil
    let texto: Texto
    let abajo: Abajo

    init(color: Color, ilustracion: Ilustracion? = nil, icono: Medicamento? = nil,
         @ViewBuilder texto: () -> Texto, @ViewBuilder abajo: () -> Abajo) {
        self.color = color
        self.ilustracion = ilustracion
        self.icono = icono
        self.texto = texto()
        self.abajo = abajo()
    }

    @Environment(\.dynamicTypeSize) private var tamano

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            if tamano.isAccessibilitySize {
                // Con letra muy grande, el dibujo va arriba y más chico para que el texto ocupe todo el ancho.
                if let icono {
                    IconoMedicamento(icono, tamano: 64)
                }
                VStack(alignment: .leading, spacing: 8) { texto }
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) { texto }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if let ilustracion {
                        ilustracion.frame(width: 120)
                    } else if let icono {
                        IconoMedicamento(icono, tamano: 84)
                    }
                }
            }
            if Abajo.self != EmptyView.self { abajo }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Radio.tarjeta + 4, style: .continuous).fill(color))
        .contentShape(RoundedRectangle(cornerRadius: Radio.tarjeta + 4, style: .continuous))
    }
}

extension TarjetaPastel where Abajo == EmptyView {
    init(color: Color, ilustracion: Ilustracion? = nil, icono: Medicamento? = nil, @ViewBuilder texto: () -> Texto) {
        self.init(color: color, ilustracion: ilustracion, icono: icono, texto: texto) { EmptyView() }
    }
}

/// Vista previa de la semana en Inicio: toca para abrir Calendario.
struct SemanaPrevia: View {
    let hoy: Date
    let resumen: (Date) -> ResumenCalendario
    let alAbrir: () -> Void

    @Environment(\.dynamicTypeSize) private var tamano
    private var lado: CGFloat { tamano.isAccessibilitySize ? 60 : 36 }

    var body: some View {
        Button(action: alAbrir) {
            VStack(alignment: .leading, spacing: 14) {
                ViewThatFits(in: .horizontal) {
                    HStack {
                        titulo
                        Spacer()
                        verCalendario
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        titulo
                        verCalendario
                    }
                }
                if tamano.isAccessibilitySize {
                    // Con letra muy grande se muestran ayer, hoy y los dos días siguientes.
                    let semana = Agenda.semana(de: hoy)
                    let i = semana.firstIndex { Calendar.current.isDate($0, inSameDayAs: hoy) } ?? 0
                    let visibles = Array(semana[max(0, i - 1)..<min(semana.count, i + 3)])
                    HStack(spacing: 0) { ForEach(visibles, id: \.self) { dia($0) } }
                } else {
                    HStack(spacing: 0) { ForEach(Agenda.semana(de: hoy), id: \.self) { dia($0) } }
                }
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(EstiloPresionable())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Esta semana. Abre el calendario")
        .accessibilityAddTraits(.isButton)
    }

    private var titulo: some View {
        Text("Esta semana").font(Tipo.tarjeta).foregroundStyle(Paleta.tinta)
    }

    private var verCalendario: some View {
        HStack(spacing: 6) {
            Text("Ver calendario")
                .font(.body.weight(.semibold))
                .underline()
            Image(systemName: "chevron.right").font(.body.weight(.semibold))
        }
        .foregroundStyle(Paleta.tinta)
    }

    private func dia(_ d: Date) -> some View {
        let esHoy = Calendar.current.isDate(d, inSameDayAs: hoy)
        return VStack(spacing: 6) {
            Text(d.formatted(.dateTime.weekday(.narrow).locale(Locale(identifier: "es_MX"))).uppercased())
                .font(.body.weight(.semibold))
                .foregroundStyle(Paleta.tintaSuave)
            Text(d.formatted(.dateTime.day()))
                .font(.system(.body, design: .serif, weight: .semibold))
                .minimumScaleFactor(0.7)
                .foregroundStyle(esHoy ? Color.white : Paleta.tinta)
                .frame(width: lado, height: lado)
                .background { if esHoy { Circle().fill(Paleta.marcaFuerte) } }
            MarcaDia(resumen: resumen(d)).frame(height: 8)
        }
        .frame(maxWidth: .infinity)
    }
}

/// Punto coral si faltan tomas, palomita si están todas.
struct MarcaDia: View {
    let resumen: ResumenCalendario

    var body: some View {
        switch resumen {
        case .sinTomas: Color.clear.frame(width: 6, height: 6)
        case .completo:
            Image(systemName: "checkmark").font(.caption2.weight(.bold)).foregroundStyle(Paleta.tomada)
        case .conTomas:
            Circle().fill(Paleta.acento).frame(width: 6, height: 6)
        }
    }
}

// MARK: - Datos compartidos por Inicio y Calendario

/// Cómo se ve una toma. Nunca solo color: siempre icono y palabra.
enum EstadoVisible: Equatable {
    case pendiente, teToca, preguntar, sinRegistro
    case tomada(Date)
    case sePaso

    var registrada: Bool {
        switch self {
        case .tomada, .sePaso: true
        default: false
        }
    }
}

enum ResumenCalendario: Equatable {
    case sinTomas, completo
    case conTomas(Int)
}

/// Una toma de un día con su medicamento y su registro.
struct TomaDelDia: Identifiable {
    let toma: TomaProgramada
    let med: Medicamento
    let registro: RegistroToma?

    var id: String { toma.id }

    func estado(ahora: Date) -> EstadoVisible {
        if let registro {
            return registro.estado == .tomada ? .tomada(registro.registrada ?? registro.programada) : .sePaso
        }
        if !Calendar.current.isDate(toma.fecha, inSameDayAs: ahora) {
            return toma.fecha > ahora ? .pendiente : .sinRegistro
        }
        if ahora < toma.fecha.addingTimeInterval(-15 * 60) { return .pendiente }
        if ahora <= toma.fecha.addingTimeInterval(30 * 60) { return .teToca }
        return .preguntar
    }

    var hora: String { toma.fecha.formatted(date: .omitted, time: .shortened) }
    var detalle: String { [med.dosis, toma.momento.texto].filter { !$0.isEmpty }.joined(separator: " · ") }
}

enum Agenda {
    static func tomas(en d: Date, meds: [Medicamento], perfil: Perfil?, registros: [RegistroToma]) -> [TomaDelDia] {
        guard let perfil else { return [] }
        let regs = Dictionary(registros.map { ($0.idToma, $0) }, uniquingKeysWith: { a, _ in a })
        return meds
            .filter { !Plan.termino($0, ahora: Calendar.current.startOfDay(for: d)) }
            .flatMap { med in
                Plan.tomas(de: med, perfil: perfil, desde: d, dias: 1).compactMap { toma -> TomaDelDia? in
                    // Una medicina agregada hoy empieza con la siguiente toma, no con las que ya pasaron.
                    if toma.fecha < med.inicio.addingTimeInterval(-15 * 60), regs[toma.id] == nil { return nil }
                    return TomaDelDia(toma: toma, med: med, registro: regs[toma.id])
                }
            }
            .sorted { $0.toma.fecha < $1.toma.fecha }
    }

    static func resumen(_ tomas: [TomaDelDia], ahora: Date) -> ResumenCalendario {
        guard !tomas.isEmpty else { return .sinTomas }
        let registradas = tomas.filter { $0.estado(ahora: ahora).registrada }.count
        return registradas == tomas.count ? .completo : .conTomas(tomas.count - registradas)
    }

    static var calendario: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.locale = Locale(identifier: "es_MX")
        c.firstWeekday = 2
        return c
    }

    /// Lunes a domingo de la semana de `d`.
    static func semana(de d: Date) -> [Date] {
        let cal = calendario
        guard let s = cal.dateInterval(of: .weekOfYear, for: d) else { return [] }
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: s.start) }
    }
}

// MARK: - Acciones de toma (Inicio y Calendario)

struct AvisoDeshacer: Equatable {
    let idToma: String
    let texto: String
}

/// Registrar, "se me pasó" y deshacer. Siempre por un toque visible de la persona.
@MainActor @Observable
final class ControlTomas {
    var deshacer: AvisoDeshacer?
    var elegida: TomaDelDia?
    var confirmaciones = 0
    private var tarea: Task<Void, Never>?

    private var contexto: ModelContext { Almacen.contenedor.mainContext }

    func tomar(_ t: TomaDelDia) {
        guard (try? Registro.marcarTomada(idToma: t.id, contexto: contexto)) != nil else { return }
        confirmaciones += 1
        Task { await ServicioAvisosSistema.compartido.cancelarRepeticiones(idToma: t.id) }
        if Navegacion.compartida.tomaResaltada == t.id { Navegacion.compartida.tomaResaltada = nil }
        let hora = Date.now.formatted(date: .omitted, time: .shortened)
        let estado = t.med.tipoAccion.estadoRegistrado.lowercased()
        mostrar(AvisoDeshacer(idToma: t.id, texto: "\(t.med.nombreVisible.capitalizedPrimera): \(estado) a las \(hora)"))
    }

    func sePaso(_ t: TomaDelDia) {
        guard (try? Registro.marcarSePaso(idToma: t.id, contexto: contexto)) != nil else { return }
        Task { await ServicioAvisosSistema.compartido.cancelarRepeticiones(idToma: t.id) }
        if Navegacion.compartida.tomaResaltada == t.id { Navegacion.compartida.tomaResaltada = nil }
        mostrar(AvisoDeshacer(idToma: t.id, texto: "Marcada como «Se pasó»."))
    }

    func revertir(_ idToma: String) {
        try? Registro.deshacer(idToma: idToma, contexto: contexto)
        tarea?.cancel()
        deshacer = nil
    }

    private func mostrar(_ aviso: AvisoDeshacer) {
        tarea?.cancel()
        deshacer = aviso
        tarea = Task { [weak self] in
            try? await Task.sleep(for: .seconds(30))
            guard !Task.isCancelled else { return }
            self?.deshacer = nil
        }
    }
}

private struct ModificadorTomas: ViewModifier {
    let control: ControlTomas

    func body(content: Content) -> some View {
        @Bindable var control = control
        content
            .overlay(alignment: .bottom) {
                if let aviso = control.deshacer {
                    BarraDeshacer(aviso: aviso) { control.revertir(aviso.idToma) }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 10)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .cambioMiMi(control.deshacer)
            .onChange(of: control.deshacer != nil) { _, visible in
                Navegacion.compartida.deshacerVisible = visible
            }
            .sensoryFeedback(.success, trigger: control.confirmaciones)
            .sheet(item: $control.elegida) { t in
                DetalleTomaView(toma: t,
                                alTomar: { control.tomar(t) },
                                alSePaso: { control.sePaso(t) },
                                alDeshacer: { control.revertir(t.id) })
            }
    }
}

extension View {
    func controlDeTomas(_ control: ControlTomas) -> some View { modifier(ModificadorTomas(control: control)) }
}

// MARK: - Componentes de toma

/// Fila de una toma dentro de un bloque pastel del calendario.
struct FilaToma: View {
    let toma: TomaDelDia
    let estado: EstadoVisible
    let resaltada: Bool
    let acciones: Bool
    let alAbrir: () -> Void
    let alTomar: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Button(action: alAbrir) {
                HStack(spacing: 14) {
                    IconoMedicamento(toma.med, tamano: 52)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(toma.med.nombreVisible.capitalizedPrimera)
                            .font(.system(.title3, design: .serif, weight: .semibold))
                            .foregroundStyle(Paleta.tinta)
                            .fixedSize(horizontal: false, vertical: true)
                        Text([toma.med.dosis, toma.hora].filter { !$0.isEmpty }.joined(separator: " · "))
                            .font(.body)
                            .foregroundStyle(Paleta.tinta)
                        ChipEstado(estado: estado, tipoAccion: toma.med.tipoAccion)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(EstiloPresionable())
            .accessibilityElement(children: .combine)
            .accessibilityHint("Abre los detalles")

            if acciones && !estado.registrada && estado != .pendiente {
                Button(action: alTomar) {
                    Image(systemName: "checkmark")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Color.white)
                        .frame(width: 52, height: 52)
                        .background(Circle().fill(Paleta.marcaFuerte))
                }
                .buttonStyle(EstiloPresionable())
                .accessibilityLabel("\(toma.med.accionRegistro): \(toma.med.nombreVisible)")
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, resaltada ? 10 : 0)
        .background {
            if resaltada {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Paleta.tinta, lineWidth: 2)
            }
        }
    }
}

/// Insignia de estado: icono + palabra.
struct ChipEstado: View {
    let estado: EstadoVisible
    let tipoAccion: TipoAccionPlan

    var body: some View {
        Label(texto, systemImage: icono)
            .font(.body.weight(.semibold))
            .fixedSize(horizontal: false, vertical: true)
            .foregroundStyle(primerPlano)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Capsule().fill(fondo))
    }

    private var texto: String {
        switch estado {
        case .pendiente: "Pendiente"
        case .teToca: "Te toca"
        case .preguntar: tipoAccion.preguntaRegistro
        case .sinRegistro: "Sin registrar"
        case .tomada(let f): "\(tipoAccion.estadoRegistrado) \(f.formatted(date: .omitted, time: .shortened))"
        case .sePaso: "Se pasó"
        }
    }

    private var icono: String {
        switch estado {
        case .pendiente: "circle"
        case .teToca: "bell.fill"
        case .preguntar: "questionmark.circle.fill"
        case .sinRegistro: "minus.circle"
        case .tomada: "checkmark.circle.fill"
        case .sePaso: "exclamationmark.circle.fill"
        }
    }

    private var primerPlano: Color {
        switch estado {
        case .pendiente, .sinRegistro, .preguntar: Paleta.tinta
        case .teToca: Paleta.sobreAcento
        case .tomada: Paleta.tomada
        case .sePaso: Paleta.sePaso
        }
    }

    private var fondo: Color {
        switch estado {
        case .pendiente, .sinRegistro: Color.white.opacity(0.7)
        case .teToca: Paleta.acentoSuave
        case .preguntar: Paleta.dudoso
        case .tomada: Paleta.tomadaFondo
        case .sePaso: Paleta.sePasoFondo
        }
    }
}

/// Aviso de 30 s con "Deshacer" (RF-06).
struct BarraDeshacer: View {
    let aviso: AvisoDeshacer
    let alDeshacer: () -> Void

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                mensaje
                botonDeshacer
            }
            VStack(alignment: .leading, spacing: 10) {
                mensaje
                botonDeshacer
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Paleta.marcaFuerte))
        .shadow(color: Color.black.opacity(0.18), radius: 16, y: 6)
    }

    private var mensaje: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title3)
                .foregroundStyle(Paleta.acento)
                .accessibilityHidden(true)
            Text(aviso.texto)
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.white)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// Botón grande y claro: la persona tiene 30 segundos para arrepentirse.
    private var botonDeshacer: some View {
        Button(action: alDeshacer) {
            Label("Deshacer", systemImage: "arrow.uturn.backward")
                .font(Tipo.etiqueta)
                .foregroundStyle(Paleta.tinta)
                .padding(.horizontal, 18)
                .frame(minHeight: 52)
                .background(Capsule().fill(Color.white))
        }
        .buttonStyle(EstiloPresionable())
    }
}

/// Detalle de una toma en hoja: foto grande, 🔊 y las acciones.
struct DetalleTomaView: View {
    let toma: TomaDelDia
    let alTomar: () -> Void
    let alSePaso: () -> Void
    let alDeshacer: () -> Void

    @Environment(\.dismiss) private var cerrar

    var body: some View {
        let estado = toma.estado(ahora: .now)
        let esHoy = Calendar.current.isDateInToday(toma.toma.fecha)
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .top, spacing: 16) {
                IconoMedicamento(toma.med, tamano: 92)
                VStack(alignment: .leading, spacing: 6) {
                    Text(toma.med.nombreVisible.capitalizedPrimera)
                        .font(Tipo.titulo)
                        .foregroundStyle(Paleta.tinta)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(toma.med.nombreTecnico)
                        .font(.body)
                        .foregroundStyle(Paleta.tintaSuave)
                    ChipEstado(estado: estado, tipoAccion: toma.med.tipoAccion)
                }
                Spacer(minLength: 0)
                Button {
                    Voz.decir("\(toma.med.nombreVisible). \(toma.detalle), a las \(toma.hora).")
                } label: {
                    Image(systemName: "speaker.wave.2")
                        .font(.title2)
                        .foregroundStyle(Paleta.tinta)
                        .frame(width: 56, height: 56)
                        .background(Circle().fill(Paleta.marcaSuave))
                }
                .accessibilityLabel("Leer en voz alta")
            }
            Text("\(toma.detalle.capitalizedPrimera) · \(toma.hora)")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Paleta.tinta)
            if let ind = toma.med.indicaciones, !ind.isEmpty {
                Label(ind.capitalizedPrimera, systemImage: "info.circle")
                    .font(.body)
                    .foregroundStyle(Paleta.tinta)
            }
            if estado == .sePaso {
                Text("Marcada como «Se pasó».")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Paleta.sePaso)
                    .tarjeta(relleno: 16, color: Paleta.sePasoFondo)
            }
            Spacer(minLength: 0)
            VStack(spacing: 10) {
                if estado.registrada {
                    BotonGrande(titulo: "Deshacer", icono: "arrow.uturn.backward", estilo: .secundario) {
                        alDeshacer()
                        cerrar()
                    }
                } else if esHoy && estado != .pendiente {
                    BotonGrande(titulo: toma.med.accionRegistro, icono: "checkmark") {
                        alTomar()
                        cerrar()
                    }
                    BotonGrande(titulo: "No, se me pasó", estilo: .secundario) {
                        alSePaso()
                        cerrar()
                    }
                } else if esHoy {
                    BotonGrande(titulo: "\(toma.med.accionRegistro) antes", icono: "checkmark", estilo: .secundario) {
                        alTomar()
                        cerrar()
                    }
                }
            }
        }
        .padding(24)
        .padding(.top, 8)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(32)
        .presentationBackground(Paleta.fondo)
        .onDisappear { Voz.callar() }
    }
}

#Preview("Inicio") {
    TuDiaView()
        .modelContainer(Almacen.vistaPrevia())
        .environment(Navegacion.compartida)
}
