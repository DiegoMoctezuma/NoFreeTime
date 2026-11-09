import Foundation

/// Convierte lo que propone el modelo en valores de `Medicamento` (PRD A5, mapeo de momentos).
/// Funciones puras: se prueban sin modelo (IOSLAB-9NovTests/MapeoTests.swift).
enum MapeoIndicacion {
    /// Campos que se pueden marcar como dudosos (nombres de `IndicacionPropuesta`).
    static let camposRevisables: [String] = ["nombre", "concentracion", "dosis", "cadaHoras", "momentos", "duracionDias"]

    /// Momentos de la toma y campos que quedan dudosos por el mapeo.
    /// - `.horaExacta` usa `horaTexto`; si no hay hora válida, se descarta y `momentos` queda dudoso.
    /// - Sin momentos y con `cadaHoras`: 24 → desayuno; 12 → desayuno y cena; 8 → desayuno, comida y cena,
    ///   y `cadaHoras` queda dudoso para que la persona confirme las horas.
    /// - Sin momentos ni `cadaHoras`: usa `vecesAlDia` (1, 2 o 3) igual que arriba y lo marca dudoso.
    static func momentos(de p: IndicacionPropuesta) -> (momentos: [Momento], dudosos: Set<String>) {
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
            let veces: Int? = p.cadaHoras.map { 24 / max($0, 1) } ?? p.vecesAlDia
            switch veces {
            case 1: resultado = [.desayuno]
            case 2: resultado = [.desayuno, .cena]
            case 3: resultado = [.desayuno, .comida, .cena]
            default: break
            }
            if !resultado.isEmpty {
                // Las horas las dedujo el código, no la receta: la persona las confirma (A5).
                dudosos.insert(p.cadaHoras != nil ? "cadaHoras" : "momentos")
            } else {
                dudosos.insert("momentos")
            }
        }
        return (resultado, dudosos)
    }

    /// Campos en amarillo: los que marcó el modelo, los vacíos obligatorios y los del mapeo.
    static func dudosos(de p: IndicacionPropuesta) -> Set<String> {
        var d = Set(p.camposDudosos.filter { camposRevisables.contains($0) })
        if p.nombre.trimmingCharacters(in: .whitespaces).isEmpty { d.insert("nombre") }
        if (p.dosis ?? "").trimmingCharacters(in: .whitespaces).isEmpty { d.insert("dosis") }
        d.formUnion(momentos(de: p).dudosos)
        return d
    }

    /// Medicamento (sin guardar) a partir de una indicación confirmada.
    static func medicamento(de p: IndicacionPropuesta, inicio: Date, colorHex: String = Paleta.medicamentos[0]) -> Medicamento {
        let cadaHoras = p.cadaHoras ?? p.vecesAlDia.map { 24 / max($0, 1) }
        return Medicamento(nombre: p.nombre.trimmingCharacters(in: .whitespaces),
                           concentracion: limpio(p.concentracion),
                           colorHex: colorHex,
                           dosis: limpio(p.dosis) ?? "1 tableta",
                           momentos: momentos(de: p).momentos,
                           cadaHoras: cadaHoras,
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
        normalizar(p.nombre) == normalizar(m.nombre)
            && normalizarConcentracion(p.concentracion) == normalizarConcentracion(m.concentracion)
    }

    /// Mismo nombre pero otra concentración: se trata como cambio y se pregunta (B9).
    static func mismoNombre(_ p: IndicacionPropuesta, con m: Medicamento) -> Bool {
        normalizar(p.nombre) == normalizar(m.nombre)
    }

    /// Medicamento del tratamiento que corresponde a una caja leída (WP-04).
    static func medicamento(paraCaja caja: CajaLeida, en tratamiento: [Medicamento]) -> Medicamento? {
        guard let nombre = caja.nombre else { return nil }
        let n = normalizar(nombre)
        let candidatos = tratamiento.filter { normalizar($0.nombre) == n }
        if candidatos.count <= 1 { return candidatos.first }
        let c = normalizarConcentracion(caja.concentracion)
        return candidatos.first { normalizarConcentracion($0.concentracion) == c } ?? candidatos.first
    }

    private static func limpio(_ s: String?) -> String? {
        guard let t = s?.trimmingCharacters(in: .whitespaces), !t.isEmpty else { return nil }
        return t
    }
}
