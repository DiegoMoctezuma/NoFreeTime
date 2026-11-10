import Foundation

/// Convierte lo que propone el modelo en valores de `Medicamento` (PRD A5, mapeo de momentos).
/// Funciones puras: se prueban sin modelo (IOSLAB-9NovTests/MapeoTests.swift).
enum MapeoIndicacion {
    static func tipoAccion(de propuesta: IndicacionPropuesta) -> TipoAccionPlan {
        if propuesta.cuidado == true { return .cuidado }
        return propuesta.aplicacion == true ? .aplicacion : .toma
    }

    static func rangoHoras(de propuesta: IndicacionPropuesta) -> ClosedRange<Int>? {
        guard let min = propuesta.intervaloMinHoras, let max = propuesta.intervaloMaxHoras,
              min > 0, min < max else { return nil }
        return min...max
    }

    private static let patronRangoHoras = try! NSRegularExpression(
        pattern: #"\b(?:cada\s+|c\s*/\s*)([0-9]+)\s*(?:[-–—−]|a|o)\s*([0-9]+)\s*(?:horas?|h(?:rs?)?)\b"#,
        options: .caseInsensitive
    )

    static func rangoHoras(en texto: String) -> ClosedRange<Int>? {
        let fuente = texto as NSString
        let coincidencias = patronRangoHoras.matches(in: texto, range: NSRange(location: 0, length: fuente.length))
        guard coincidencias.count == 1, let pauta = coincidencias.first,
              let min = Int(fuente.substring(with: pauta.range(at: 1))),
              let max = Int(fuente.substring(with: pauta.range(at: 2))),
              min > 0, min < max else { return nil }
        return min...max
    }

    static func textoDelRango(de nombre: String, en fuente: String) -> String? {
        guard let linea = renglon(de: nombre, en: fuente, limite: nil, incluirSiguiente: false) else { return nil }
        if rangoHoras(en: linea) != nil { return linea }
        guard let par = renglon(de: nombre, en: fuente, limite: nil) else { return nil }
        let siguiente = String(par.dropFirst(linea.count)).trimmingCharacters(in: .whitespaces)
        guard normalizar(siguiente).range(of: #"^(?:cada\s+|c\s*/)"#, options: .regularExpression) != nil,
              rangoHoras(en: siguiente) != nil else { return nil }
        return par
    }

    /// Rescata una aplicación escrita literalmente cuando el lector la dejó fuera del plan.
    static func aplicacionConRango(en linea: String) -> IndicacionPropuesta? {
        let linea = linea.trimmingCharacters(in: .whitespaces)
        guard let rango = rangoHoras(en: linea), !pautaFueraDeAgenda(linea) else { return nil }
        let fuente = linea as NSString
        guard let pauta = patronRangoHoras.firstMatch(in: linea, range: NSRange(location: 0, length: fuente.length)) else { return nil }
        let nombre = fuente.substring(to: pauta.range.location)
            .replacingOccurrences(of: #"^(?:[-•]\s*)?aplicar\s+"#, with: "", options: [.regularExpression, .caseInsensitive])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let instruccion = normalizar(linea)
        guard !nombre.isEmpty,
              instruccion.range(of: #"^(?:[-•]\s*)?(?:aplicar|crema|pomada|unguento|humectantes?)\b"#, options: .regularExpression) != nil,
              instruccion.range(of: #"\b(?:no|evitar|suspender)\b"#, options: .regularExpression) == nil else { return nil }
        let despues = normalizar(fuente.substring(from: NSMaxRange(pauta.range)))
        let duracion = despues.range(of: #"\b(?:por|durante|x)\s+[0-9]+\s+dias?\b"#, options: .regularExpression)
        let dias = duracion.flatMap { despues[$0].split(whereSeparator: { !$0.isNumber }).first.flatMap { Int($0) } }
        let faltaDuracion = dias == nil && despues.range(of: #"\b(?:por|durante|hasta|x)\b"#, options: .regularExpression) != nil
        return IndicacionPropuesta(nombre: nombre, duracionDias: dias, indicaciones: linea,
                                   camposDudosos: faltaDuracion ? ["duracionDias"] : [], aplicacion: true,
                                   intervaloMinHoras: rango.lowerBound, intervaloMaxHoras: rango.upperBound)
    }

    static func pautaFueraDeAgenda(_ texto: String) -> Bool {
        let condiciones = #"\b(?:si\s+(?:es\s+necesari[oa]|hay|presenta|tiene|aparece|persiste|se|lo\s+requiere)|en\s+caso\s+de|segun\s+necesidad|segun\s+sea\s+necesari[oa]|a\s+demanda|prn|mientras\s+(?:este|estes)\s+despiert[oa]|(?:solo|durante)\s+(?:de\s+|el\s+)?dia|hasta\s+las)\b"#
        let otrosHorarios = #"\b(?:semanal(?:mente)?|mensual(?:mente)?|dias\s+alternos|una\s+sola\s+vez|(?:cada|los|el|este)\s+(?:lunes|martes|miercoles|jueves|viernes|sabados?|domingos?)|cada\s+(?:\d+\s+)?(?:semanas?|mes(?:es)?|dias?))\b"#
        let normalizado = normalizar(texto)
        return normalizado.range(of: condiciones, options: .regularExpression) != nil
            || normalizado.range(of: otrosHorarios, options: .regularExpression) != nil
    }

    /// Campos que se pueden marcar como dudosos (nombres de `IndicacionPropuesta`).
    static let camposRevisables: [String] = ["nombre", "concentracion", "dosis", "cadaHoras", "momentos", "duracionDias"]

    /// Momentos de la toma y campos que quedan dudosos por el mapeo.
    /// - `.horaExacta` usa `horaTexto`; si no hay hora válida, se descarta y `momentos` queda dudoso.
    /// - Una pauta por intervalo se programa desde una primera toma, aparte de los momentos.
    /// - Sin momentos ni intervalo, sugiere momentos a partir de `vecesAlDia` y los marca dudosos.
    static func momentos(de p: IndicacionPropuesta) -> (momentos: [Momento], dudosos: Set<String>) {
        if rangoHoras(de: p) != nil || (p.cadaHoras ?? 0) > 0 { return ([], []) }
        var dudosos = Set<String>()
        var resultado: [Momento] = []
        for m in p.momentos {
            let momento: Momento?
            switch m {
            case .desayuno: momento = .desayuno
            case .comida: momento = .comida
            case .cena: momento = .cena
            case .dormir: momento = .dormir
            case .horaExacta:
                if let texto = p.horaTexto, let c = Momento.componentes(deHora: texto) {
                    momento = .horaFija(c)
                } else {
                    momento = nil
                    dudosos.insert("momentos")
                }
            }
            if let momento, !resultado.contains(momento) { resultado.append(momento) }
        }
        if resultado.isEmpty {
            switch p.vecesAlDia {
            case 1: resultado = [.desayuno]
            case 2: resultado = [.desayuno, .cena]
            case 3: resultado = [.desayuno, .comida, .cena]
            default: break
            }
            dudosos.insert("momentos")
        }
        return (resultado, dudosos)
    }

    /// Campos en amarillo: los que marcó el modelo, los vacíos obligatorios y los del mapeo.
    static func dudosos(de p: IndicacionPropuesta) -> Set<String> {
        var d = Set(p.camposDudosos.filter { camposRevisables.contains($0) })
        if p.nombre.trimmingCharacters(in: .whitespaces).isEmpty { d.insert("nombre") }
        if tipoAccion(de: p) == .cuidado {
            d.subtract(["dosis", "concentracion"])
        } else if tipoAccion(de: p) == .toma && (p.dosis ?? "").trimmingCharacters(in: .whitespaces).isEmpty {
            d.insert("dosis")
        }
        d.formUnion(momentos(de: p).dudosos)
        return d
    }

    /// Medicamento (sin guardar) a partir de una indicación confirmada.
    static func medicamento(de p: IndicacionPropuesta, inicio: Date, colorHex: String = Paleta.medicamentos[0]) -> Medicamento {
        return Medicamento(nombre: p.nombre.trimmingCharacters(in: .whitespaces),
                           concentracion: limpio(p.concentracion),
                           colorHex: colorHex,
                           dosis: limpio(p.dosis) ?? "",
                           tipoAccion: tipoAccion(de: p),
                           momentos: momentos(de: p).momentos,
                           cadaHoras: p.cadaHoras,
                           inicioIntervalo: p.cadaHoras.flatMap { $0 > 0 ? inicio : nil },
                           duracionDias: p.duracionDias,
                           inicio: inicio,
                           indicaciones: limpio(p.indicaciones))
    }

    /// Minúsculas, sin acentos y sin espacios extra: "Losartán " → "losartan".
    static func normalizar(_ s: String) -> String {
        s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "es_MX"))
            .lowercased()
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }

    /// "50 mg", "50mg", "50 MG" → "50mg"
    static func normalizarConcentracion(_ s: String?) -> String {
        normalizar(s ?? "").replacingOccurrences(of: " ", with: "")
    }

    /// Ya registrado = mismo nombre normalizado y misma concentración (PRD A5; B9 [SUPUESTO]).
    static func coincide(_ p: IndicacionPropuesta, con m: Medicamento) -> Bool {
        mismoNombre(p, con: m)
            && normalizarConcentracion(p.concentracion) == normalizarConcentracion(m.concentracion)
    }

    /// Mismo nombre pero otra concentración: se trata como cambio y se pregunta (B9).
    static func mismoNombre(_ p: IndicacionPropuesta, con m: Medicamento) -> Bool {
        (tipoAccion(de: p) == .cuidado) == (m.tipoAccion == .cuidado)
            && normalizar(p.nombre) == normalizar(m.nombre)
    }

    /// Medicamento del tratamiento que corresponde a una caja leída (WP-04).
    static func medicamento(paraCaja caja: CajaLeida, en tratamiento: [Medicamento]) -> Medicamento? {
        guard let nombre = caja.nombre else { return nil }
        let n = normalizar(nombre)
        let candidatos = tratamiento.filter { $0.tipoAccion != .cuidado && normalizar($0.nombre) == n }
        if candidatos.count <= 1 { return candidatos.first }
        let c = normalizarConcentracion(caja.concentracion)
        return candidatos.first { normalizarConcentracion($0.concentracion) == c } ?? candidatos.first
    }

    // MARK: Verificación contra el texto de la foto (HCAI: el código comprueba, no el modelo)

    /// ¿El fragmento está escrito en el texto reconocido? Tolera errores de lectura:
    /// basta con que el 70 % de sus palabras aparezcan (con una letra de diferencia en palabras largas).
    static func aparece(_ fragmento: String, en fuente: String) -> Bool {
        let f = normalizar(fragmento)
        let t = normalizar(fuente)
        guard !f.isEmpty else { return true }
        if t.contains(f) { return true }
        let palabras = f.split(separator: " ").map(String.init).filter { $0.count >= 3 }
        guard !palabras.isEmpty else { return false }
        let disponibles = Set(t.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init))
        let halladas = palabras.filter { p in
            disponibles.contains(p) || (p.count >= 5 && disponibles.contains { abs($0.count - p.count) <= 1 && distancia($0, p) <= 1 })
        }
        return Double(halladas.count) / Double(palabras.count) >= 0.7
    }

    /// "50 mg" aparece como "50mg", "50 MG" o "50 mg." en el texto.
    static func apareceConcentracion(_ c: String, en fuente: String) -> Bool {
        let cc = normalizarConcentracion(c)
        guard !cc.isEmpty else { return true }
        return normalizarConcentracion(fuente).contains(cc)
    }

    /// Campos cuyo valor no se encuentra en el texto de la foto. Sin texto no se puede comprobar: vacío.
    static func noEncontrados(_ p: IndicacionPropuesta, en fuente: String) -> Set<String> {
        guard !fuente.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }
        var d = Set<String>()
        if !aparece(p.nombre, en: fuente) { d.insert("nombre") }
        if tipoAccion(de: p) != .cuidado, let c = p.concentracion, !c.isEmpty, !apareceConcentracion(c, en: fuente) {
            d.insert("concentracion")
        }
        let numeros = Set(normalizar(fuente).split(whereSeparator: { !$0.isNumber }).compactMap { Int($0) })
        if let rango = rangoHoras(de: p) {
            let texto = textoDelRango(de: p.nombre, en: fuente) ?? ""
            if rangoHoras(en: texto) != rango { d.insert("cadaHoras") }
        } else if let h = p.cadaHoras {
            let renglon = normalizar(renglon(de: p.nombre, en: fuente) ?? "")
            let pauta = #"\b(?:cada\s+|c\s*/\s*)"# + String(h) + #"\s*(?:horas?|h(?:rs?)?)\b"#
            let cadaHora = h == 1 && renglon.range(of: #"\bcada\s+hora\b"#, options: .regularExpression) != nil
            if h <= 0 || (!cadaHora && renglon.range(of: pauta, options: .regularExpression) == nil) {
                d.insert("cadaHoras")
            }
        }
        if let dias = p.duracionDias, !numeros.contains(dias) { d.insert("duracionDias") }
        return d
    }

    /// Renglón (y el siguiente, que suele traer la indicación) donde aparece el nombre.
    static func renglon(de nombre: String, en fuente: String, limite: Int? = 140, incluirSiguiente: Bool = true) -> String? {
        let renglones = fuente.split(separator: "\n").map(String.init)
        guard let i = renglones.firstIndex(where: { aparece(nombre, en: $0) }) else { return nil }
        let siguiente = incluirSiguiente && i + 1 < renglones.count ? " " + renglones[i + 1] : ""
        let texto = (renglones[i] + siguiente).trimmingCharacters(in: .whitespaces)
        guard let limite, texto.count > limite else { return texto }
        return String(texto.prefix(limite)) + "…"
    }

    /// Distancia de edición (Levenshtein) para tolerar una letra mal leída.
    static func distancia(_ a: String, _ b: String) -> Int {
        let x = Array(a), y = Array(b)
        if x.isEmpty { return y.count }
        if y.isEmpty { return x.count }
        var previa = Array(0...y.count)
        for i in 1...x.count {
            var actual = [i] + Array(repeating: 0, count: y.count)
            for j in 1...y.count {
                actual[j] = min(previa[j] + 1, actual[j - 1] + 1, previa[j - 1] + (x[i - 1] == y[j - 1] ? 0 : 1))
            }
            previa = actual
        }
        return previa[y.count]
    }

    private static func limpio(_ s: String?) -> String? {
        guard let t = s?.trimmingCharacters(in: .whitespaces), !t.isEmpty else { return nil }
        return t
    }
}
