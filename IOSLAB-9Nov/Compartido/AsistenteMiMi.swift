import SwiftUI
import SwiftData

// MiMi, la asistente de la app: un globito abajo a la derecha que lleva a cada pestaña,
// abre la cámara de la receta y contesta qué toca hoy.
// La voz o el texto solo se usan para entender qué se pidió (lista cerrada de acciones);
// la respuesta la arma el código con lo guardado. MiMi nunca registra ni guarda nada sola.

/// Lo que MiMi entendió de lo que dijo o escribió la persona.
enum IntencionMiMi: Equatable {
    case ir(Pestana)
    case agregarReceta
    case agregarCaja
    case hoy
    case yaTome(String)
    case misMedicinas
    case queHago
    case desconocida

    /// Palabras clave, sin modelo: funciona sin internet y siempre igual.
    static func entender(_ texto: String) -> IntencionMiMi {
        let t = normalizar(texto)
        guard !t.isEmpty else { return .desconocida }
        func tiene(_ frases: String...) -> Bool { frases.contains { t.contains($0) } }

        if tiene("ya me tome", "ya me la tome", "ya tome", "me la tome", "ya me lo tome") { return .yaTome(t) }
        if tiene("que hago", "ayuda", "ayudame", "como funciona", "para que sirve", "donde estoy", "no entiendo", "como le hago") { return .queHago }
        if tiene("receta") { return .agregarReceta }
        if tiene("caja") { return .agregarCaja }
        if tiene("agregar", "agrega", "anadir", "nueva medicina", "nuevo medicamento", "escanear") { return .ir(.escanear) }
        if tiene("calendario", "semana") { return .ir(.calendario) }
        if tiene("que medicinas tengo", "cuales medicinas", "mis medicinas", "que medicamentos tengo", "mis medicamentos") { return .misMedicinas }
        if tiene("perfil", "ajustes", "configuracion", "mis datos", "tamano de letra", "letra") { return .ir(.perfil) }
        if tiene("hoy", "me toca", "tengo que tomar", "que tomo", "siguiente", "pendiente", "me falta") { return .hoy }
        if tiene("inicio", "principal", "pantalla de inicio") { return .ir(.hoy) }
        return .desconocida
    }

    /// "¿Ya me tomé la de la PRESIÓN?" → "ya me tome la de la presion"
    static func normalizar(_ texto: String) -> String {
        let sinAcentos = texto.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "es_MX"))
        let soloLetras = sinAcentos.map { $0.isLetter || $0.isNumber ? $0 : " " }
        return String(soloLetras).split(separator: " ").joined(separator: " ")
    }
}

/// Respuesta de MiMi: lo que dice y, si aplica, un botón para hacerlo.
struct RespuestaMiMi: Equatable {
    var texto: String
    var boton: String? = nil
    var accion: AccionMiMi? = nil
}

enum AccionMiMi: Equatable {
    case ir(Pestana)
    case alta(PasoAlta)
}

/// Arma las respuestas a partir de lo guardado. Sin modelo de lenguaje: no puede inventar una dosis.
enum RespuestasMiMi {
    static func hoy(meds: [Medicamento], perfil: Perfil?, registros: [RegistroToma], ahora: Date = .now) -> RespuestaMiMi {
        guard !meds.isEmpty else {
            return RespuestaMiMi(texto: "Todavía no tienes medicinas guardadas. Si quieres, te ayudo a agregar tu receta.",
                                 boton: "Agregar mi receta", accion: .alta(.leerReceta))
        }
        let lista = Agenda.tomas(en: ahora, meds: meds, perfil: perfil, registros: registros)
        guard !lista.isEmpty else { return RespuestaMiMi(texto: "Hoy no tienes nada que tomar.") }
        let faltan = lista.filter { !$0.estado(ahora: ahora).registrada }
        guard !faltan.isEmpty else {
            return RespuestaMiMi(texto: "Ya registraste todo lo de hoy: \(lista.count) de \(lista.count). ¡Muy bien!")
        }
        let partes = faltan.prefix(3).map { "\($0.med.nombreVisible) a las \($0.hora)" }
        var lista3 = partes.formatted(.list(type: .and).locale(Locale(identifier: "es_MX")))
        if faltan.count > 3 { lista3 += ", y \(faltan.count - 3) más" }
        let cuantas = faltan.count == 1 ? "te falta una" : "te faltan \(faltan.count)"
        return RespuestaMiMi(texto: "Sí. Hoy \(cuantas): \(lista3).", boton: "Ver mi día", accion: .ir(.hoy))
    }

    static func yaTome(_ frase: String, meds: [Medicamento], perfil: Perfil?, registros: [RegistroToma], ahora: Date = .now) -> RespuestaMiMi {
        let lista = Agenda.tomas(en: ahora, meds: meds, perfil: perfil, registros: registros)
        let ignorar: Set<String> = ["ya", "me", "la", "lo", "el", "de", "del", "tome", "mimi", "para", "que", "las", "los", "una", "hoy"]
        let palabras = IntencionMiMi.normalizar(frase).split(separator: " ").map(String.init).filter { $0.count > 2 && !ignorar.contains($0) }
        let med = meds.first { med in
            let nombres = IntencionMiMi.normalizar([med.nombre, med.apodo ?? ""].joined(separator: " "))
            return palabras.contains { nombres.contains($0) }
        }
        guard let med else {
            let hechas = lista.filter { $0.estado(ahora: ahora).registrada }.count
            return RespuestaMiMi(texto: "Hoy llevas \(hechas) de \(lista.count) registradas. Dime el nombre de la medicina y te digo si ya la registraste.",
                                 boton: "Ver mi día", accion: .ir(.hoy))
        }
        let suyas = lista.filter { $0.med.id == med.id }
        let nombre = med.nombreVisible
        func horaTomada(_ t: TomaDelDia) -> Date? {
            if case .tomada(let cuando) = t.estado(ahora: ahora) { return cuando }
            return nil
        }
        if let cuando = suyas.compactMap(horaTomada).last {
            return RespuestaMiMi(texto: "Sí. Hoy registraste \(nombre) a las \(cuando.formatted(date: .omitted, time: .shortened)).")
        }
        if let siguiente = suyas.first(where: { !$0.estado(ahora: ahora).registrada }) {
            return RespuestaMiMi(texto: "Todavía no la registras. \(nombre.capitalizedPrimera) te toca a las \(siguiente.hora).",
                                 boton: "Ver mi día", accion: .ir(.hoy))
        }
        if suyas.isEmpty { return RespuestaMiMi(texto: "\(nombre.capitalizedPrimera) no te toca hoy.") }
        return RespuestaMiMi(texto: "Hoy \(nombre) quedó como que se pasó. No tomes doble; sigue con la siguiente a su hora.")
    }

    static func misMedicinas(_ meds: [Medicamento]) -> RespuestaMiMi {
        guard !meds.isEmpty else {
            return RespuestaMiMi(texto: "Todavía no tienes medicinas guardadas.", boton: "Agregar mi receta", accion: .alta(.leerReceta))
        }
        let nombres = meds.map(\.nombreVisible).formatted(.list(type: .and).locale(Locale(identifier: "es_MX")))
        let cuantas = meds.count == 1 ? "una medicina" : "\(meds.count) medicinas"
        return RespuestaMiMi(texto: "Tienes \(cuantas): \(nombres).", boton: "Verlas en Perfil", accion: .ir(.perfil))
    }

    static func queHago(en pestana: Pestana) -> RespuestaMiMi {
        let texto = switch pestana {
        case .hoy: "Aquí ves lo que te toca hoy. Cuando te tomes una medicina, toca «Ya me la tomé»."
        case .calendario: "Aquí ves tu semana. Toca un día para ver qué te toca."
        case .escanear: "Aquí agregas medicinas: con una foto de tu receta, de la caja, o escribiéndola tú."
        case .perfil: "Aquí están tus medicinas, tu rutina y el tamaño de la letra."
        }
        return RespuestaMiMi(texto: texto + " También puedes preguntarme si hoy te toca medicina.")
    }

    static let noEntendi = RespuestaMiMi(texto: "No te entendí. Puedo llevarte a tu calendario, agregar una receta o decirte qué te toca hoy.")
}

// MARK: - Vistas

/// Carita de MiMi. Si el equipo agrega la imagen "mimi-burbuja" a Assets, se usa esa.
struct IconoMiMi: View {
    var tamano: CGFloat = 64

    var body: some View {
        Group {
            if UIImage(named: "mimi-burbuja") != nil {
                Image("mimi-burbuja")
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Circle().fill(Paleta.acento)
                    Image(systemName: "bubble.left.and.text.bubble.right.fill")
                        .font(.system(size: tamano * 0.36, weight: .semibold))
                        .foregroundStyle(Paleta.tinta)
                }
            }
        }
        .frame(width: tamano, height: tamano)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(Color.white, lineWidth: 3))
        .accessibilityHidden(true)
    }
}

/// El globito fijo abajo a la derecha.
struct BurbujaMiMi: View {
    /// Distancia sobre el borde inferior seguro para quedar arriba de la barra de pestañas.
    /// Si en el iPhone queda encimado o muy alto, solo cambia este número.
    static let margenInferior: CGFloat = 84

    let accion: () -> Void

    var body: some View {
        Button(action: accion) {
            IconoMiMi(tamano: 66)
                .shadow(color: Color.black.opacity(0.22), radius: 10, y: 4)
                .contentShape(Circle())
        }
        .buttonStyle(EstiloPresionable())
        .accessibilityLabel("Pregúntale a MiMi")
        .accessibilityHint("Te lleva a donde quieras o te dice qué te toca hoy")
    }
}

/// Panel que se abre al tocar el globito: hablarle, escribirle o tocar una pregunta.
struct PanelMiMi: View {
    @Environment(\.dismiss) private var cerrar
    @Environment(Navegacion.self) private var navegacion
    @Query(filter: #Predicate<Medicamento> { $0.activo }, sort: \Medicamento.nombre) private var medicamentos: [Medicamento]
    @Query private var perfiles: [Perfil]
    @Query private var registros: [RegistroToma]

    @State private var dictado = Dictado()
    @State private var escrito = ""
    @State private var pregunta: String?
    @State private var respuesta: RespuestaMiMi?
    @FocusState private var escribiendo: Bool

    private let sugerencias: [(texto: String, icono: String)] = [
        ("¿Hoy tengo que tomar medicina?", "pills"),
        ("Llévame a mi calendario", "calendar"),
        ("Quiero agregar una receta", "doc.text.viewfinder"),
        ("¿Qué hago aquí?", "questionmark.circle"),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                encabezado
                if let pregunta {
                    Text("«\(pregunta)»")
                        .font(.title3)
                        .foregroundStyle(Paleta.tinta)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let respuesta { tarjetaRespuesta(respuesta) }
                estadoDictado
                BotonGrande(titulo: dictado.escuchando ? "Ya terminé" : "Hablarle a MiMi",
                            icono: dictado.escuchando ? "stop.fill" : "mic.fill") {
                    Voz.callar()
                    Task { await dictado.alternar() }
                }
                .disabled(dictado.transcribiendo)
                .accessibilityHint("Di, por ejemplo: ¿hoy tengo que tomar medicina?")

                VStack(alignment: .leading, spacing: 10) {
                    Text("O toca una pregunta")
                        .font(Tipo.seccion)
                        .foregroundStyle(Paleta.tinta)
                    ForEach(sugerencias, id: \.texto) { s in
                        Button { procesar(s.texto) } label: {
                            Label(s.texto, systemImage: s.icono)
                                .font(Tipo.etiqueta)
                                .foregroundStyle(Paleta.tinta)
                                .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
                                .padding(.horizontal, 18)
                                .background(RoundedRectangle(cornerRadius: Radio.control, style: .continuous).fill(Paleta.tarjeta))
                                .overlay(RoundedRectangle(cornerRadius: Radio.control, style: .continuous).strokeBorder(Paleta.borde, lineWidth: 1))
                        }
                        .buttonStyle(EstiloPresionable())
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("O escríbele")
                        .font(Tipo.seccion)
                        .foregroundStyle(Paleta.tinta)
                    TextField("Por ejemplo: ¿ya me tomé la de la presión?", text: $escrito)
                        .font(.title3)
                        .foregroundStyle(Paleta.tinta)
                        .padding(.horizontal, 18)
                        .frame(minHeight: 60)
                        .background(RoundedRectangle(cornerRadius: Radio.control, style: .continuous).fill(Paleta.tarjeta))
                        .overlay(RoundedRectangle(cornerRadius: Radio.control, style: .continuous).strokeBorder(Paleta.borde, lineWidth: 1))
                        .focused($escribiendo)
                        .submitLabel(.send)
                        .onSubmit {
                            procesar(escrito)
                            escrito = ""
                        }
                }
            }
            .padding(24)
        }
        .background(Paleta.fondo.ignoresSafeArea())
        .presentationDetents([.large])
        .presentationCornerRadius(32)
        .onChange(of: dictado.transcribiendo) { _, ahora in
            // Terminó de transcribir: se procesa lo que dijo.
            if !ahora, !dictado.texto.isEmpty {
                procesar(dictado.texto)
                dictado.texto = ""
            }
        }
        // La voz sigue al cerrar ("Te llevo a…"); la "X" sí la calla.
        .onDisappear { dictado.detener() }
    }

    private var encabezado: some View {
        HStack(alignment: .center, spacing: 14) {
            IconoMiMi(tamano: 60)
            VStack(alignment: .leading, spacing: 2) {
                Text("MiMi")
                    .font(Tipo.titulo)
                    .foregroundStyle(Paleta.tinta)
                Text("Pregúntame o dime a dónde ir")
                    .font(.body)
                    .foregroundStyle(Paleta.tinta)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button {
                Voz.callar()
                cerrar()
            } label: {
                Image(systemName: "xmark")
                    .font(.headline)
                    .foregroundStyle(Paleta.tinta)
                    .frame(width: 52, height: 52)
                    .background(Circle().fill(Paleta.tarjeta))
            }
            .buttonStyle(EstiloPresionable())
            .accessibilityLabel("Cerrar")
        }
    }

    @ViewBuilder private var estadoDictado: some View {
        if dictado.escuchando {
            Label("Te escucho… cuando dejes de hablar, me detengo solo", systemImage: "waveform")
                .font(.headline)
                .foregroundStyle(Paleta.tinta)
                .fixedSize(horizontal: false, vertical: true)
        } else if dictado.transcribiendo {
            Label("Pensando…", systemImage: "ellipsis")
                .font(.headline)
                .foregroundStyle(Paleta.tinta)
        } else if let error = dictado.error {
            Label(error, systemImage: "exclamationmark.circle")
                .font(.headline)
                .foregroundStyle(Paleta.tinta)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func tarjetaRespuesta(_ r: RespuestaMiMi) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(r.texto)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Paleta.tinta)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 10) {
                Button { Voz.decir(r.texto) } label: {
                    Label("Repetir", systemImage: "speaker.wave.2.fill")
                        .font(Tipo.etiqueta)
                        .foregroundStyle(Paleta.tinta)
                        .padding(.horizontal, 16)
                        .frame(minHeight: 52)
                        .background(Capsule().fill(Paleta.fondo))
                }
                .buttonStyle(EstiloPresionable())
            }
            if let boton = r.boton, let accion = r.accion {
                BotonGrande(titulo: boton, icono: "arrow.right") { hacer(accion) }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .tarjeta(relleno: 20, color: Paleta.salvia)
        .accessibilityElement(children: .contain)
    }

    private func procesar(_ texto: String) {
        let limpio = texto.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !limpio.isEmpty else { return }
        escribiendo = false
        dictado.error = nil
        pregunta = limpio
        let perfil = perfiles.first
        let r: RespuestaMiMi
        switch IntencionMiMi.entender(limpio) {
        case .ir(let p):
            r = RespuestaMiMi(texto: "Te llevo a \(p.titulo).")
            responder(r)
            hacer(.ir(p))
            return
        case .agregarReceta:
            r = RespuestaMiMi(texto: "Vamos a tomarle foto a tu receta.")
            responder(r)
            hacer(.alta(.leerReceta))
            return
        case .agregarCaja:
            r = RespuestaMiMi(texto: "Vamos a tomarle foto a la caja.")
            responder(r)
            hacer(.alta(.leerCaja))
            return
        case .hoy:
            r = RespuestasMiMi.hoy(meds: medicamentos, perfil: perfil, registros: registros)
        case .yaTome(let frase):
            r = RespuestasMiMi.yaTome(frase, meds: medicamentos, perfil: perfil, registros: registros)
        case .misMedicinas:
            r = RespuestasMiMi.misMedicinas(medicamentos)
        case .queHago:
            r = RespuestasMiMi.queHago(en: navegacion.pestana)
        case .desconocida:
            r = RespuestasMiMi.noEntendi
        }
        responder(r)
    }

    private func responder(_ r: RespuestaMiMi) {
        withAnimation(MovimientoMiMi.cambio) { respuesta = r }
        Voz.decir(r.texto)
    }

    private func hacer(_ accion: AccionMiMi) {
        switch accion {
        case .ir(let p):
            navegacion.pestana = p
        case .alta(let paso):
            navegacion.pestana = .escanear
            navegacion.abrirAlta = paso
        }
        cerrar()
    }
}

// MARK: - Completar una medicina por voz

/// Lee lo que la persona le dicta a MiMi para completar una medicina:
/// "una tableta con el desayuno y la cena por siete días", "cada 8 horas, empiezo a las 8 de la noche".
/// Reglas simples, sin modelo: lo que entiende se pone en los campos y la persona lo revisa.
enum DictadoReceta {
    struct Resultado: Equatable {
        var dosis: String?
        var cadaHoras: Int?
        var momentos: [Momento] = []
        var hora: DateComponents?
        var dias: Int?
        var siempre = false
    }

    private static let numeros: [String: Double] = [
        "un": 1, "una": 1, "uno": 1, "dos": 2, "tres": 3, "cuatro": 4, "cinco": 5, "seis": 6, "siete": 7,
        "ocho": 8, "nueve": 9, "diez": 10, "once": 11, "doce": 12, "catorce": 14, "quince": 15,
        "veinte": 20, "treinta": 30, "media": 0.5, "medio": 0.5,
    ]

    /// Raíz de la palabra → cómo se escribe en singular y plural.
    private static let unidades: [(raiz: String, singular: String, plural: String)] = [
        ("tableta", "tableta", "tabletas"), ("pastilla", "pastilla", "pastillas"), ("capsula", "cápsula", "cápsulas"),
        ("gota", "gota", "gotas"), ("cucharadita", "cucharadita", "cucharaditas"), ("cucharada", "cucharada", "cucharadas"),
        ("sobre", "sobre", "sobres"), ("ampolleta", "ampolleta", "ampolletas"), ("inhalacion", "inhalación", "inhalaciones"),
        ("disparo", "disparo", "disparos"), ("aplicacion", "aplicación", "aplicaciones"), ("ml", "ml", "ml"), ("mililitro", "ml", "ml"),
    ]

    static func leer(_ texto: String) -> Resultado {
        let w = IntencionMiMi.normalizar(texto).split(separator: " ").map(String.init)
        func palabra(_ i: Int) -> String { w.indices.contains(i) ? w[i] : "" }
        func numero(_ i: Int) -> Double? { Double(palabra(i)) ?? numeros[palabra(i)] }
        var r = Resultado()

        for (i, p) in w.enumerated() {
            // Dosis: número + unidad ("una tableta", "media pastilla", "5 ml").
            if r.dosis == nil, let u = unidades.first(where: { p.hasPrefix($0.raiz) }), let n = numero(i - 1) {
                r.dosis = formato(n, singular: u.singular, plural: u.plural)
            }
            // Cada N horas.
            if p == "cada", let n = numero(i + 1), palabra(i + 2).hasPrefix("hora") {
                r.cadaHoras = Int(n)
            }
            // Duración: N días, semanas o meses; "siempre".
            if palabra(i - 2) != "cada", let n = numero(i - 1) {
                if p.hasPrefix("dia") { r.dias = Int(n) }
                if p.hasPrefix("semana") { r.dias = Int(n * 7) }
                if p == "mes" || p == "meses" { r.dias = Int(n * 30) }
            }
            if ["siempre", "permanente", "indefinido"].contains(p) { r.siempre = true }
            // Momentos de la rutina.
            if p.hasPrefix("desayun") { r.momentos.append(.desayuno) }
            if p == "comida" || p == "comer" || p == "mediodia" { r.momentos.append(.comida) }
            if p == "cena" || p == "cenar" { r.momentos.append(.cena) }
            if p == "dormir" || p.hasPrefix("acostar") { r.momentos.append(.dormir) }
            let enLa = palabra(i - 1) == "la" && ["en", "por"].contains(palabra(i - 2))
            if p == "manana", enLa { r.momentos.append(.desayuno) }
            if p == "noche", enLa { r.momentos.append(.cena) }
            // Hora: "a las 8", "a las 8 y media de la noche".
            if p == "las", palabra(i - 1) == "a", let n = numero(i + 1) {
                var h = Int(n)
                var m = 0
                var j = i + 2
                if palabra(j) == "y", palabra(j + 1) == "media" {
                    m = 30
                    j += 2
                } else if let minutos = Int(palabra(j)), minutos < 60 {
                    m = minutos
                    j += 1
                }
                // "de la tarde", "de la noche" o "p. m."
                let tarde = (palabra(j) == "de" && palabra(j + 1) == "la" && ["tarde", "noche"].contains(palabra(j + 2)))
                    || (palabra(j) == "p" && palabra(j + 1) == "m") || palabra(j) == "pm"
                if tarde, h < 12 { h += 12 }
                r.hora = DateComponents(hour: h % 24, minute: m)
            }
        }
        var vistos: [Momento] = []
        for m in r.momentos where !vistos.contains(m) { vistos.append(m) }
        r.momentos = vistos
        return r
    }

    /// "1 tableta", "½ tableta", "2 tabletas"
    private static func formato(_ n: Double, singular: String, plural: String) -> String {
        if n == 0.5 { return "½ \(singular)" }
        if n == 1 { return "1 \(singular)" }
        if n == n.rounded() { return "\(Int(n)) \(plural)" }
        return "\(n.formatted()) \(plural)"
    }

    /// La siguiente vez que llegue esa hora: hoy si todavía no pasa, si no, mañana.
    static func proxima(_ hora: DateComponents, desde ahora: Date = .now) -> Date {
        let cal = Calendar.current
        let hoy = cal.date(bySettingHour: hora.hour ?? 8, minute: hora.minute ?? 0, second: 0, of: ahora) ?? ahora
        return hoy > ahora ? hoy : (cal.date(byAdding: .day, value: 1, to: hoy) ?? hoy)
    }
}
