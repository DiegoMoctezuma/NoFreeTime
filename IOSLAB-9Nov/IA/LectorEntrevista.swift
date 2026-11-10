import Foundation
import FoundationModels

// Entrevista con lenguaje natural: la persona contesta como habla
// ("desayuno como a las 8 y me duermo a las 11") y el modelo propone los valores.
// La persona los ve ya puestos en los selectores y los confirma o cambia (HCAI: la IA sugiere, la persona decide).

@Generable(description: "Horas de la rutina que la persona dijo con sus palabras")
nonisolated struct RutinaDicha: Equatable, Sendable {
    @Guide(description: "Hora del desayuno en formato HH:mm de 24 horas, solo si la dijo. Ejemplo: 08:00")
    var desayuno: String?
    @Guide(description: "Hora de la comida (la del mediodía o la tarde) en formato HH:mm de 24 horas, solo si la dijo. Ejemplo: 14:30")
    var comida: String?
    @Guide(description: "Hora de la cena en formato HH:mm de 24 horas, solo si la dijo. Ejemplo: 20:00")
    var cena: String?
    @Guide(description: "Hora de dormir en formato HH:mm de 24 horas, solo si la dijo. Ejemplo: 22:30")
    var dormir: String?

    init(desayuno: String? = nil, comida: String? = nil, cena: String? = nil, dormir: String? = nil) {
        self.desayuno = desayuno
        self.comida = comida
        self.cena = cena
        self.dormir = dormir
    }
}

@Generable(description: "Cómo quiere la persona que la llamen")
nonisolated struct NombreDicho: Equatable, Sendable {
    @Guide(description: "Nombre o apodo con el que quiere que le hablen, tal como lo dijo, sin frases como 'me llamo'. Vacío si no dijo ninguno")
    var nombre: String?
}

@MainActor
enum LectorEntrevista {
    private static let instruccionesRutina = """
        Extrae la rutina habitual de una transcripción de voz espontánea en español de México.
        Ignora muletillas, repeticiones y puntuación poco fiable. Procesa cada actividad por separado.
        Si la persona se corrige con "ah no", "perdón", "digo", "mejor" o "más bien", conserva la última hora afirmada.
        La corrección corresponde a la actividad que estaba describiendo, aunque no repita su nombre.
        Si menciona dos horas como alternativas, un rango o una hora que rechaza, no elijas por ella.
        Devuelve desayuno, comida del mediodía, cena y dormir en formato HH:mm de 24 horas.
        Deja vacío únicamente el campo que no mencionó o que quedó sin aclarar. Conserva los demás.
        Respeta la mañana, tarde, noche o madrugada cuando se diga. Si es implícita y clara por el contexto,
        desayuno a las 8 es 08:00, como a las 3 es 15:00, ceno a las 8 es 20:00 y me duermo a las 9 es 21:00.
        "Y media" son 30 minutos, "y cuarto" son 15 y "medianoche" es 00:00. No inventes horarios.
        Ejemplo: "Pues desayuno como a las ocho, eh, como a las tres y me duermo a las siete ah no a las nueve".
        Resultado: desayuno 08:00, comida 15:00, cena vacío, dormir 21:00.
        """

    private static var modeloListo: Bool {
        if case .available = SystemLanguageModel.default.availability { return true }
        return false
    }

    /// Nombre a partir de lo que dijo o escribió. Sin modelo, limpia frases comunes.
    static func nombre(de texto: String) async -> String {
        let limpio = texto.trimmingCharacters(in: .whitespacesAndNewlines)
        guard limpio.split(separator: " ").count > 2, LectorIA.motor != .ninguno, modeloListo else { return heuristica(limpio) }
        let pregunta = "La persona respondió a \"¿Cómo te gusta que te llame?\": \(limpio)"
        do {
            let sesion = LanguageModelSession(instructions: "Extrae solo el nombre o apodo que la persona dijo. No lo inventes.")
            let dicho = try await sesion.respond(to: pregunta, generating: NombreDicho.self,
                                                 options: GenerationOptions(samplingMode: .greedy)).content.nombre
            let n = (dicho ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            // Solo se acepta si lo que propone el modelo está en lo que dijo la persona.
            return !n.isEmpty && MapeoIndicacion.aparece(n, en: limpio) ? capitalizar(n) : heuristica(limpio)
        } catch {
            return heuristica(limpio)
        }
    }

    /// Horas en minutos desde medianoche. Las horas claras también se recuperan sin conexión.
    static func rutina(de texto: String) async -> [Momento: Int] {
        let limpio = texto.trimmingCharacters(in: .whitespacesAndNewlines)
        let locales = horasClaras(de: limpio)
        let motor = LectorIA.motor
        guard !limpio.isEmpty, motor != .ninguno, locales.count < Momento.rutina.count else { return locales }
        let pregunta = "La persona describió su día: \(limpio)"
        do {
            let r: RutinaDicha
            if motor == .apple {
                let sesion = LanguageModelSession(instructions: instruccionesRutina)
                r = try await sesion.respond(to: pregunta, generating: RutinaDicha.self,
                                             options: GenerationOptions(samplingMode: .greedy)).content
            } else {
                nonisolated struct Nube: Decodable {
                    var desayuno: String?
                    var comida: String?
                    var cena: String?
                    var dormir: String?
                }
                let h = "en formato HH:mm de 24 horas; vacío si no la dijo"
                let n = try await ServicioDeepSeek.extraer(
                    Nube.self, funcion: "rutina", descripcion: "Horas de la rutina que dijo la persona",
                    esquema: ServicioDeepSeek.objeto([
                        "desayuno": ServicioDeepSeek.campoTexto("Hora del desayuno " + h),
                        "comida": ServicioDeepSeek.campoTexto("Hora de la comida " + h),
                        "cena": ServicioDeepSeek.campoTexto("Hora de la cena " + h),
                        "dormir": ServicioDeepSeek.campoTexto("Hora de dormir " + h)
                    ], requeridas: ["desayuno", "comida", "cena", "dormir"]),
                    sistema: instruccionesRutina, usuario: pregunta)
                r = RutinaDicha(desayuno: n.desayuno, comida: n.comida, cena: n.cena, dormir: n.dormir)
            }
            return horas(de: r).merging(locales) { _, clara in clara }
        } catch {
            return locales
        }
    }

    static func horas(de rutina: RutinaDicha) -> [Momento: Int] {
        let campos: [(Momento, String?)] = [
            (.desayuno, rutina.desayuno), (.comida, rutina.comida), (.cena, rutina.cena), (.dormir, rutina.dormir)
        ]
        var resultado: [Momento: Int] = [:]
        for (momento, valor) in campos {
            guard let valor, let hora = Momento.componentes(deHora: valor) else { continue }
            resultado[momento] = Perfil.minutos(hora)
        }
        return resultado
    }

    private static let actividades = try! NSRegularExpression(
        pattern: #"\b(desayuno|almuerzo|como|ceno|me duermo|me acuesto|me voy a dormir|voy a dormir|me meto a la cama)\b"#
    )
    private static let numeros = ["cero", "una", "dos", "tres", "cuatro", "cinco", "seis", "siete", "ocho", "nueve", "diez", "once", "doce"]
    private static let numero = "(?:[0-9]{1,2}|uno|" + numeros.joined(separator: "|") + ")"
    private static let horasHabladas = try! NSRegularExpression(
        pattern: #"\b(?:a\s+(?:eso\s+de\s+)?las?\s+("# + numero
            + #")(?::([0-9]{2})|\s+y\s+(media|cuarto))?(?:\s+(?:de|por|en)\s+la\s+(manana|madrugada|tarde|noche)|\s*([ap])\.?\s*m\.?)?|(medianoche|mediodia))\b"#
    )
    private static let correccion = #"\b(?:no|perdon|digo|mejor|mas bien|en realidad|corrijo|sino)\b"#
    private static let rectificacion = #"\b(?:(?:ah+|eh+)\s*,?\s+no|no\s*,?\s+no|perdon|digo|mejor|mas bien|en realidad|corrijo|sino)\b"#

    /// Respaldo para frases con actividad y hora explícitas. El modelo interpreta el resto.
    static func horasClaras(de texto: String) -> [Momento: Int] {
        let texto = MapeoIndicacion.normalizar(texto) as NSString
        var tramos: [(Momento, NSRange)] = []
        for marca in actividades.matches(in: texto as String, range: NSRange(location: 0, length: texto.length)) {
            let palabra = texto.substring(with: marca.range)
            let momento: Momento
            switch palabra {
            case "desayuno": momento = .desayuno
            case "como", "almuerzo": momento = .comida
            case "ceno": momento = .cena
            default: momento = .dormir
            }
            if palabra == "como", let anterior = tramos.last {
                let entre = texto.substring(with: NSRange(location: NSMaxRange(anterior.1),
                                                           length: marca.range.location - NSMaxRange(anterior.1)))
                // En "desayuno como a las ocho", "como" aproxima la hora.
                if entre.range(of: #"^[\s,.!?]*(?:(?:pues|este|eh|normalmente)\b[\s,.!?]*)*$"#, options: .regularExpression) != nil
                    || entre.range(of: correccion + #"[\s,.!?]*$"#, options: .regularExpression) != nil { continue }
            }
            tramos.append((momento, marca.range))
        }
        var resultado: [Momento: Int] = [:]
        for (i, tramo) in tramos.enumerated() {
            let (momento, actividad) = tramo
            guard tramos.filter({ $0.0 == momento }).count == 1 else { continue }
            let prefijo = texto.substring(to: actividad.location)
            guard prefijo.range(of: #"\bno\s+$"#, options: .regularExpression) == nil else { continue }
            let inicio = NSMaxRange(actividad)
            let fin = i + 1 < tramos.count ? tramos[i + 1].1.location : texto.length
            let frase = texto.substring(with: NSRange(location: inicio, length: fin - inicio))
            resultado[momento] = horaClara(en: frase, para: momento)
        }
        return resultado
    }

    private static func horaClara(en frase: String, para momento: Momento) -> Int? {
        // Una rectificación puede omitir "a las": "a las siete… ah no, nueve".
        let frase = frase.replacingOccurrences(
            of: "(" + rectificacion + #")([\s,]+)(?="# + numero + #"\b)"#,
            with: "$1$2a las ", options: .regularExpression
        )
        let texto = frase as NSString
        let coincidencias = horasHabladas.matches(in: frase, range: NSRange(location: 0, length: texto.length))
        guard let ultima = coincidencias.last,
              frase.range(of: #"\b(?:entre|a veces|depende)\b"#, options: .regularExpression) == nil else { return nil }
        let despues = texto.substring(from: NSMaxRange(ultima.range))
        guard despues.range(of: #"^\s*[,;]?\s*(?:o|u|y)\s+"# + numero + #"\b"#, options: .regularExpression) == nil,
              despues.range(of: correccion, options: .regularExpression) == nil else { return nil }
        if coincidencias.count > 1 {
            let anterior = NSMaxRange(coincidencias[coincidencias.count - 2].range)
            let entre = texto.substring(with: NSRange(location: anterior, length: ultima.range.location - anterior))
            guard entre.range(of: rectificacion, options: .regularExpression) != nil else { return nil }
        } else if texto.substring(to: ultima.range.location).range(of: #"\bno\b"#, options: .regularExpression) != nil {
            return nil
        }
        func captura(_ i: Int) -> String {
            let rango = ultima.range(at: i)
            return rango.location == NSNotFound ? "" : texto.substring(with: rango)
        }
        if captura(6) == "medianoche" { return 0 }
        if captura(6) == "mediodia" { return 12 * 60 }
        let numero = captura(1)
        guard let hora = Int(numero) ?? numeros.firstIndex(of: numero == "uno" ? "una" : numero),
              (0..<24).contains(hora) else { return nil }
        let minutos = Int(captura(2)) ?? (captura(3) == "media" ? 30 : captura(3) == "cuarto" ? 15 : 0)
        guard (0..<60).contains(minutos) else { return nil }
        let franja = captura(4)
        let meridiano = captura(5)
        if !franja.isEmpty || !meridiano.isEmpty {
            guard (1...12).contains(hora) else { return nil }
            let tarde = meridiano == "p" || franja == "tarde" || (franja == "noche" && hora != 12)
            return (hora % 12 + (tarde ? 12 : 0)) * 60 + minutos
        }
        if numero.hasPrefix("0") && !captura(2).isEmpty { return hora * 60 + minutos }
        switch momento {
        case .desayuno where (1...4).contains(hora),
             .comida where (8...10).contains(hora),
             .cena where (1...5).contains(hora) || hora == 12,
             .dormir where hora == 12:
            return nil
        case .comida where (1...7).contains(hora),
             .cena where (6...11).contains(hora),
             .dormir where (7...11).contains(hora):
            return (hora + 12) * 60 + minutos
        default:
            return hora * 60 + minutos
        }
    }

    /// "me llamo ernesto" → "Ernesto"; "soy doña Lupe" → "Doña Lupe".
    static func heuristica(_ texto: String) -> String {
        var t = texto.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
        let prefijos = ["me llamo ", "mi nombre es ", "soy ", "dime ", "llámame ", "llamame ", "me dicen "]
        for p in prefijos where t.lowercased().hasPrefix(p) {
            t = String(t.dropFirst(p.count))
        }
        let palabras = t.split(separator: " ").prefix(3).joined(separator: " ")
        return capitalizar(palabras)
    }

    private static func capitalizar(_ s: String) -> String {
        s.split(separator: " ").map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined(separator: " ")
    }
}
