import SwiftUI
import SwiftData

/// Calendario (pestaña propia): semana completa y las tomas del día elegido por Mañana, Tarde y Noche.
/// Solo las tomas de hoy se pueden registrar desde aquí.
struct CalendarioView: View {
    @Environment(Navegacion.self) private var navegacion
    @Query(filter: #Predicate<Medicamento> { $0.activo }, sort: \Medicamento.nombre) private var medicamentos: [Medicamento]
    @Query private var perfiles: [Perfil]
    @Query private var registros: [RegistroToma]
    @State private var dia = Calendar.current.startOfDay(for: .now)
    @State private var control = ControlTomas()

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { linea in
            contenido(ahora: linea.date)
        }
        .background(Paleta.fondo.ignoresSafeArea())
        .controlDeTomas(control)
    }

    @ViewBuilder private func contenido(ahora: Date) -> some View {
        let lista = Agenda.tomas(en: dia, meds: medicamentos, perfil: perfiles.first, registros: registros)
        let esHoy = Calendar.current.isDate(dia, inSameDayAs: ahora)
        ScrollViewReader { lector in
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    Text("Calendario")
                        .font(Tipo.grande)
                        .foregroundStyle(Paleta.tinta)
                        .accessibilityAddTraits(.isHeader)
                        .padding(.top, 16)

                    CalendarioSemana(seleccion: $dia, hoy: ahora) { d in
                        Agenda.resumen(Agenda.tomas(en: d, meds: medicamentos, perfil: perfiles.first, registros: registros), ahora: ahora)
                    }
                    .entradaMiMi()

                    VStack(alignment: .leading, spacing: 4) {
                        Text(tituloDia(ahora: ahora))
                            .font(Tipo.titulo)
                            .foregroundStyle(Paleta.tinta)
                        Text(lista.isEmpty ? "Sin actividades" : "\(lista.count) \(lista.count == 1 ? "actividad" : "actividades")")
                            .font(.body)
                            .foregroundStyle(Paleta.tintaSuave)
                    }

                    if medicamentos.isEmpty {
                        Text("Cuando agregues tu plan, aquí verás cada día.")
                            .font(.title3)
                            .foregroundStyle(Paleta.tintaSuave)
                    } else if lista.isEmpty {
                        Text("Este día no tienes nada programado.")
                            .font(.title3)
                            .foregroundStyle(Paleta.tintaSuave)
                    } else {
                        ForEach(Franja.allCases, id: \.self) { franja in
                            let deFranja = lista.filter { $0.toma.franja == franja }
                            if !deFranja.isEmpty {
                                bloque(franja, tomas: deFranja, ahora: ahora, acciones: esHoy)
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
            .onAppear { irAResaltada(lector) }
            .onChange(of: navegacion.tomaResaltada) { _, _ in irAResaltada(lector) }
        }
    }

    private func tituloDia(ahora: Date) -> String {
        let cal = Calendar.current
        if cal.isDate(dia, inSameDayAs: ahora) { return "Hoy" }
        if let manana = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: ahora)), cal.isDate(dia, inSameDayAs: manana) {
            return "Mañana"
        }
        return dia.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(Locale(identifier: "es_MX"))).capitalizedPrimera
    }

    /// Bloque pastel por franja, como las tarjetas de la referencia.
    private func bloque(_ franja: Franja, tomas: [TomaDelDia], ahora: Date, acciones: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(franja.titulo)
                    .font(Tipo.tarjeta)
                    .foregroundStyle(Paleta.tinta)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Image(systemName: franja.icono)
                    .font(.title2.weight(.light))
                    .foregroundStyle(Paleta.tinta)
                    .accessibilityHidden(true)
            }
            .padding(.bottom, 8)
            ForEach(Array(tomas.enumerated()), id: \.element.id) { i, t in
                if i > 0 { Divider().overlay(Paleta.tinta.opacity(0.12)) }
                FilaToma(toma: t,
                         estado: t.estado(ahora: ahora),
                         resaltada: navegacion.tomaResaltada == t.id,
                         acciones: acciones,
                         alAbrir: { control.elegida = t },
                         alTomar: { control.tomar(t) })
                    .id(t.id)
            }
        }
        .padding(22)
        .background(RoundedRectangle(cornerRadius: Radio.tarjeta + 4, style: .continuous).fill(Paleta.pastel(franja)))
        .entradaMiMi(orden: 1)
        .cambioMiMi(tomas.map { $0.registro?.estadoRaw ?? "pendiente" })
    }

    private func irAResaltada(_ lector: ScrollViewProxy) {
        guard let id = navegacion.tomaResaltada else { return }
        dia = Calendar.current.startOfDay(for: .now)
        withAnimation(.snappy) { lector.scrollTo(id, anchor: .center) }
    }
}

/// Semana (lunes a domingo) con flechas para cambiar de semana y botón "Hoy".
struct CalendarioSemana: View {
    @Binding var seleccion: Date
    let hoy: Date
    let resumen: (Date) -> ResumenCalendario

    @Environment(\.dynamicTypeSize) private var tamano
    private var cal: Calendar { Agenda.calendario }
    private var lado: CGFloat { tamano.isAccessibilitySize ? 64 : 44 }

    var body: some View {
        VStack(spacing: 16) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    tituloMes
                    Spacer()
                    controles
                }
                VStack(alignment: .leading, spacing: 8) {
                    tituloMes
                    HStack(spacing: 8) {
                        controles
                        Spacer()
                    }
                }
            }
            if tamano.isAccessibilitySize {
                // Con letra muy grande, los 7 días no caben: se desliza de lado y se centra el elegido.
                ScrollViewReader { lector in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Agenda.semana(de: seleccion), id: \.self) { d in
                                celda(d, ancho: 84).id(cal.startOfDay(for: d))
                            }
                        }
                    }
                    .onAppear { lector.scrollTo(cal.startOfDay(for: seleccion), anchor: .center) }
                    .onChange(of: seleccion) { lector.scrollTo(cal.startOfDay(for: seleccion), anchor: .center) }
                }
            } else {
                HStack(spacing: 0) {
                    ForEach(Agenda.semana(de: seleccion), id: \.self) { d in
                        celda(d)
                    }
                }
            }
        }
    }

    private var tituloMes: some View {
        Text(seleccion.formatted(.dateTime.month(.wide).year().locale(Locale(identifier: "es_MX"))).capitalizedPrimera)
            .font(Tipo.seccion)
            .foregroundStyle(Paleta.tinta)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder private var controles: some View {
        if !cal.isDate(seleccion, inSameDayAs: hoy) {
            Button("Hoy") { withAnimation(.snappy) { seleccion = cal.startOfDay(for: hoy) } }
                .font(Tipo.etiqueta)
                .foregroundStyle(Paleta.tinta)
                .padding(.horizontal, 12)
                .frame(minHeight: 44)
        }
        flecha("chevron.left", "Semana anterior", -7)
        flecha("chevron.right", "Semana siguiente", 7)
    }

    private func flecha(_ icono: String, _ etiqueta: String, _ dias: Int) -> some View {
        Button {
            if let nueva = cal.date(byAdding: .day, value: dias, to: seleccion) {
                withAnimation(.snappy) { seleccion = cal.startOfDay(for: nueva) }
            }
        } label: {
            Image(systemName: icono)
                .font(.headline)
                .foregroundStyle(Paleta.tinta)
                .frame(width: 44, height: 44)
                .overlay(Circle().strokeBorder(Paleta.borde, lineWidth: 1.2))
        }
        .accessibilityLabel(etiqueta)
    }

    private func celda(_ d: Date, ancho: CGFloat? = nil) -> some View {
        let elegido = cal.isDate(d, inSameDayAs: seleccion)
        let esHoy = cal.isDate(d, inSameDayAs: hoy)
        let r = resumen(d)
        return Button {
            withAnimation(.snappy) { seleccion = cal.startOfDay(for: d) }
        } label: {
            VStack(spacing: 8) {
                Text(d.formatted(.dateTime.weekday(.narrow).locale(Locale(identifier: "es_MX"))).uppercased())
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Paleta.tintaSuave)
                Text(d.formatted(.dateTime.day()))
                    .font(.system(.title3, design: .serif, weight: .semibold))
                    .foregroundStyle(elegido ? Color.white : Paleta.tinta)
                    .frame(width: lado, height: lado)
                    .minimumScaleFactor(0.7)
                    .background {
                        if elegido {
                            Circle().fill(Paleta.marcaFuerte)
                        } else if esHoy {
                            Circle().strokeBorder(Paleta.tinta, lineWidth: 1.5)
                        }
                    }
                MarcaDia(resumen: r).frame(height: 8)
            }
            .frame(minWidth: ancho, maxWidth: ancho ?? .infinity, minHeight: 88)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(etiquetaAccesible(d, r))
        .accessibilityAddTraits(elegido ? .isSelected : [])
    }

    private func etiquetaAccesible(_ d: Date, _ r: ResumenCalendario) -> String {
        let fecha = d.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(Locale(identifier: "es_MX")))
        switch r {
        case .sinTomas: return "\(fecha). Sin actividades"
        case .completo: return "\(fecha). Todas registradas"
        case .conTomas(let n): return "\(fecha). \(n) \(n == 1 ? "actividad" : "actividades") por registrar"
        }
    }
}

#Preview("Calendario") {
    CalendarioView()
        .modelContainer(Almacen.vistaPrevia())
        .environment(Navegacion.compartida)
}
