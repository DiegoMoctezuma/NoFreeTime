import Foundation
import CoreGraphics
import FoundationModels
import SwiftData
import Observation

/// ¿Se puede leer con Foundation Models en este iPhone? (RF-02 "Sin Apple Intelligence").
enum DisponibilidadIA: Equatable {
    case disponible
    /// Motivo legible en español; la pantalla ofrece el camino "sin receta".
    case noDisponible(String)
}

/// Caja leída y revisada por el código.
struct CajaRevisada: Equatable {
    var caja: CajaLeida
    /// Campos que no se encontraron en el texto de la foto.
    var dudosos: Set<String>
    /// Renglón de la foto donde aparece el nombre.
    var fuente: String?
}

/// Lector de receta y caja (WP-01, CONTRATOS §6). Todo en el dispositivo:
/// 1. Vision reconoce el texto de la foto.
/// 2. Foundation Models ordena ese texto (y ve la imagen si el modelo puede).
/// 3. El código verifica cada dato contra el texto y marca en amarillo lo que no encuentra.
/// Devuelve propuestas; nunca escribe en SwiftData.
@MainActor @Observable
final class LectorIA {
    enum Fallo: LocalizedError {
        case noDisponible(String)
        case noPudoLeer

        var errorDescription: String? {
            switch self {
            case .noDisponible(let motivo): motivo
            case .noPudoLeer: "No pude leerla. ¿Otra foto o lo hacemos sin receta?"
            }
        }
    }

    /// Etapa visible mientras lee (la persona entiende qué está pasando).
    enum Etapa: Equatable { case inactivo, buscandoTexto, ordenando, revisando }

    /// Tiempo de la última lectura, de la foto a la propuesta (criterio ≤ 15 s).
    private(set) var ultimaDuracion: Duration?
    private(set) var leyendo = false
    private(set) var etapa: Etapa = .inactivo

    /// Sesión creada antes de que la persona tome la foto, para ahorrar la carga del modelo.
    private var sesionLista: LanguageModelSession?
    private var usoListo = UsoHerramientas()

    /// Qué consultó el modelo antes de proponer ("Revisé tus 3 medicinas y tu rutina"). Nil si no consultó nada.
    private(set) var ultimaConsulta: String?
    /// Notas generales de la última receta, solo las que sí están escritas en la foto.
    private(set) var ultimasNotas: [String] = []

    /// Límite del texto reconocido que se manda al modelo (la ventana es de ~8 mil tokens con la imagen).
    private static let maximoTexto = 1_800

    /// Quién lee: DeepSeek por internet (principal, solo texto; decisión de Carlos, 9 nov) o,
    /// si no hay clave o la persona lo apaga, Apple Intelligence en el iPhone.
    enum Motor: Equatable { case apple, deepseek, ninguno }

    static var motor: Motor {
        let usar = UserDefaults.standard.object(forKey: ClavesApp.usarIA) as? Bool ?? true
        guard usar else { return .ninguno }
        // DeepSeek es el lector principal (decisión del equipo, 9 nov): si nunca se tocó el interruptor, está permitido.
        let nube = UserDefaults.standard.object(forKey: ClavesApp.permitirNube) as? Bool ?? true
        if nube && ServicioDeepSeek.configurado { return .deepseek }
        if appleLista { return .apple }
        return .ninguno
    }

    /// Disponible si alguno de los dos motores puede leer.
    static var disponibilidad: DisponibilidadIA {
        guard UserDefaults.standard.object(forKey: ClavesApp.usarIA) as? Bool != false else {
            return .noDisponible("La lectura automática está apagada.")
        }
        if motor != .ninguno { return .disponible }
        return disponibilidadApple
    }

    static var appleLista: Bool {
        if case .available = SystemLanguageModel.default.availability { return true }
        return false
    }

    /// Estado de Apple Intelligence en este iPhone.
    static var disponibilidadApple: DisponibilidadIA {
        switch SystemLanguageModel.default.availability {
        case .available:
            return .disponible
        case .unavailable(.deviceNotEligible):
            return .noDisponible("Este iPhone no tiene Apple Intelligence.")
        case .unavailable(.appleIntelligenceNotEnabled):
            return .noDisponible("Apple Intelligence está apagado. Puedes activarlo en Ajustes del iPhone.")
        case .unavailable(.modelNotReady):
            return .noDisponible("Apple Intelligence se está preparando. Intenta en unos minutos.")
        case .unavailable:
            return .noDisponible("Apple Intelligence no está disponible.")
        }
    }

    /// El modelo puede ver la imagen además del texto reconocido.
    static var puedeVerImagenes: Bool {
        SystemLanguageModel.default.capabilities.contains(.vision)
    }

    private static let instruccionesReceta = """
        Lees recetas médicas impresas en español de México y extraes, para cada medicamento, \
        lo que está escrito: nombre, concentración, dosis, frecuencia, momentos del día, duración e indicaciones.
        Reglas:
        - Copia solo lo que aparece en la receta. No inventes ni completes datos.
        - Si un dato no aparece o no se lee bien, déjalo vacío y agrega el nombre del campo a camposDudosos.
        - Abreviaturas comunes: "tab" o "tab." es tableta, "c/8h" es cada 8 horas, "VO" es vía oral, "x 7 días" es durante 7 días.
        - Llena cadaHoras solo si la receta da un intervalo explícito. En ese caso deja momentos y motivoHorario vacíos; \
        copia cualquier condición adicional de la pauta en indicaciones.
        - Ignora datos del médico, del paciente, firmas, cédulas y direcciones.
        - Si la imagen está borrosa, no tiene texto o no es una receta, responde legible = false y sin medicamentos.
        - Antes de proponer, consulta leerTratamientoActivo y leerRutina.
        - Si la receta dice en ayunas, antes de dormir o con alimentos, sin un intervalo, elige los \
        momentos del día que encajan con la rutina de la persona y explica por qué en motivoHorario con una frase corta.
        - Nunca cambies la dosis, la frecuencia ni la duración escritas.
        - No des consejos médicos.
        \(ServicioDeepSeek.reglasCuidados)
        """

    private static let instruccionesCaja = """
        Lees la caja de un medicamento en español. Extrae el nombre de la sustancia activa (no la marca si \
        aparecen las dos), la concentración y cuántas tabletas o cápsulas trae. Copia solo lo que se ve; \
        si no se lee el nombre, responde legible = false.
        """

    /// Crea la sesión antes de la foto (prewarm por creación temprana).
    func preparar(tratamiento: [Medicamento]) {
        guard sesionLista == nil, Self.appleLista else { return }
        usoListo = UsoHerramientas()
        sesionLista = sesionReceta(tratamiento: tratamiento, uso: usoListo)
    }

    /// Sesión con las dos herramientas de solo lectura: tratamiento y rutina.
    private func sesionReceta(tratamiento: [Medicamento], uso: UsoHerramientas) -> LanguageModelSession {
        LanguageModelSession(
            tools: [LeerTratamientoActivo(tratamiento: tratamiento, uso: uso),
                    LeerRutina(perfil: Almacen.perfil(en: Almacen.contenedor.mainContext), uso: uso)],
            instructions: Self.instruccionesReceta
        )
    }

    /// Solo se conservan las notas que están escritas en la foto (el código verifica, no el modelo).
    private static func notasVerificadas(_ notas: [String], texto: String) -> [String] {
        func clave(_ texto: String) -> String {
            MapeoIndicacion.normalizar(texto)
                .replacingOccurrences(of: #"^(?:[•·–—-]|\d+[.)])\s+"#, with: "", options: .regularExpression)
        }
        let renglones = texto.split(whereSeparator: \.isNewline).map { clave(String($0)) }
        let fragmentos = Set(renglones + zip(renglones, renglones.dropFirst()).map { $0 + " " + $1 })
        var vistas = Set<String>()
        return notas
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count >= 4 }
            .filter { fragmentos.contains(clave($0)) }
            .filter { vistas.insert(clave($0)).inserted }
    }

    /// Frase para la persona con lo que se consultó.
    private func describirConsulta(_ usadas: Set<String>, medicinas: Int) -> String? {
        let tratamiento = usadas.contains("leerTratamientoActivo") || usadas.contains("consultar_tratamiento_y_rutina")
        let rutina = usadas.contains("leerRutina") || usadas.contains("consultar_tratamiento_y_rutina")
        let meds = medicinas == 0 ? "tu tratamiento (aún vacío)" : (medicinas == 1 ? "tu medicina" : "tus \(medicinas) medicinas")
        switch (tratamiento, rutina) {
        case (true, true): return "Revisé \(meds) y tu rutina para acomodar los horarios."
        case (true, false): return "Revisé \(meds) para no duplicar nada."
        case (false, true): return "Revisé tu rutina para acomodar los horarios."
        default: return nil
        }
    }

    // MARK: Receta

    /// Lee la receta de la foto. `legible = false` si no hay texto útil.
    /// `yaRegistrado` y los campos dudosos los calcula el código, no el modelo.
    func leerReceta(_ imagen: CGImage, tratamiento: [Medicamento]) async throws -> (legible: Bool, indicaciones: [IndicacionRevisada]) {
        try verificarDisponible()
        ultimaConsulta = nil
        ultimasNotas = []
        leyendo = true
        defer {
            leyendo = false
            etapa = .inactivo
        }
        let reloj = ContinuousClock()
        let inicio = reloj.now

        etapa = .buscandoTexto
        let texto = await LectorTexto.leer(imagen)
        let enNube = Self.motor == .deepseek && texto.count >= 12
        let conApple = Self.appleLista
        guard enNube || (conApple && (Self.puedeVerImagenes || texto.count >= 12)) else {
            ultimaDuracion = reloj.now - inicio
            return (false, [])
        }

        etapa = .ordenando
        if enNube {
            // Principal: solo el texto reconocido viaja a DeepSeek; la foto se queda en el iPhone.
            do {
                let r = try await ServicioDeepSeek.leerReceta(
                    texto: texto,
                    tratamiento: LeerTratamientoActivo.lineas(de: tratamiento),
                    rutina: LeerRutina.lineas(de: Almacen.perfil(en: Almacen.contenedor.mainContext)))
                ultimaConsulta = describirConsulta(["consultar_tratamiento_y_rutina"], medicinas: tratamiento.count)
                ultimaDuracion = reloj.now - inicio
                etapa = .revisando
                return resultadoReceta(r.legible ? r.medicamentos.map(\.propuesta) : [], notas: r.legible ? r.notas ?? [] : [],
                                       texto: texto, tratamiento: tratamiento)
            } catch {
                // Sin internet o error del servicio: si Apple Intelligence está listo, lee en el iPhone.
                guard conApple else {
                    ultimaDuracion = reloj.now - inicio
                    let recuperada = resultadoReceta([], notas: [], texto: texto, tratamiento: tratamiento)
                    if recuperada.legible { return recuperada }
                    throw Fallo.noPudoLeer
                }
            }
        }
        let uso = sesionLista == nil ? UsoHerramientas() : usoListo
        let sesion = sesionLista ?? sesionReceta(tratamiento: tratamiento, uso: uso)
        sesionLista = nil

        let receta: RecetaPropuesta
        do {
            receta = try await pedirReceta(sesion: sesion, imagen: imagen, texto: Self.recortar(texto))
        } catch LanguageModelError.contextSizeExceeded {
            // Con la imagen y todo el texto no cupo: se intenta con menos texto en una sesión nueva.
            let nueva = sesionReceta(tratamiento: tratamiento, uso: uso)
            do {
                receta = try await pedirReceta(sesion: nueva, imagen: imagen, texto: String(texto.prefix(600)))
            } catch {
                ultimaDuracion = reloj.now - inicio
                let recuperada = resultadoReceta([], notas: [], texto: texto, tratamiento: tratamiento)
                if recuperada.legible { return recuperada }
                throw traducir(error)
            }
        } catch {
            ultimaDuracion = reloj.now - inicio
            let recuperada = resultadoReceta([], notas: [], texto: texto, tratamiento: tratamiento)
            if recuperada.legible { return recuperada }
            throw traducir(error)
        }

        etapa = .revisando
        ultimaDuracion = reloj.now - inicio
        ultimaConsulta = describirConsulta(uso.nombres, medicinas: tratamiento.count)
        return resultadoReceta(receta.legible ? receta.medicamentos : [], notas: receta.legible ? receta.notas : [],
                               texto: texto, tratamiento: tratamiento)
    }

    private func resultadoReceta(_ propuestas: [IndicacionPropuesta], notas: [String], texto: String,
                                 tratamiento: [Medicamento]) -> (legible: Bool, indicaciones: [IndicacionRevisada]) {
        let resultado = Self.separarCuidados(propuestas, notas: notas, texto: texto)
        ultimasNotas = resultado.notas
        let indicaciones = revisar(resultado.programables, texto: texto, tratamiento: tratamiento)
        return (!indicaciones.isEmpty || !ultimasNotas.isEmpty, indicaciones)
    }

    static func separarCuidados(_ propuestas: [IndicacionPropuesta], notas: [String], texto: String)
        -> (programables: [IndicacionPropuesta], notas: [String]) {
        var propuestas = propuestas
        var notas = notasVerificadas(notas, texto: texto)
        let lineas = texto.split(whereSeparator: \.isNewline).map(String.init)
        for (i, linea) in lineas.enumerated() {
            var linea = linea
            if MapeoIndicacion.rangoHoras(en: linea) == nil, i + 1 < lineas.count {
                let siguiente = lineas[i + 1]
                if MapeoIndicacion.normalizar(siguiente).range(of: #"^(?:cada\s+|c\s*/)"#, options: .regularExpression) != nil {
                    linea += " " + siguiente
                }
            }
            guard let aplicacion = MapeoIndicacion.aplicacionConRango(en: linea) else { continue }
            if let i = propuestas.firstIndex(where: {
                !MapeoIndicacion.normalizar($0.nombre).isEmpty && MapeoIndicacion.aparece($0.nombre, en: aplicacion.nombre)
            }) {
                propuestas[i].aplicacion = true
                propuestas[i].cuidado = false
                if let dias = aplicacion.duracionDias {
                    propuestas[i].duracionDias = dias
                    propuestas[i].camposDudosos.removeAll { $0 == "duracionDias" }
                }
            } else {
                propuestas.append(aplicacion)
            }
            notas.removeAll { MapeoIndicacion.normalizar($0) == MapeoIndicacion.normalizar(linea) }
        }
        var programables: [IndicacionPropuesta] = []
        for var propuesta in propuestas where !propuesta.nombre.trimmingCharacters(in: .whitespaces).isEmpty {
            let renglon = MapeoIndicacion.renglon(de: propuesta.nombre, en: texto, limite: nil, incluirSiguiente: false)
            let fuente = MapeoIndicacion.renglon(de: propuesta.nombre, en: texto, limite: nil)
            let textoRango = MapeoIndicacion.textoDelRango(de: propuesta.nombre, en: texto)
            if let textoRango, let rango = MapeoIndicacion.rangoHoras(en: textoRango) {
                propuesta.intervaloMinHoras = rango.lowerBound
                propuesta.intervaloMaxHoras = rango.upperBound
                propuesta.camposDudosos.removeAll { ["cadaHoras", "momentos", "horario"].contains($0) }
            }
            let tieneRango = MapeoIndicacion.rangoHoras(de: propuesta) != nil
            if tieneRango {
                propuesta.cadaHoras = nil
                propuesta.momentos = []
                propuesta.motivoHorario = nil
            }
            let indicaciones = propuesta.indicaciones ?? ""
            let sinPauta = MapeoIndicacion.tipoAccion(de: propuesta) == .cuidado
                && propuesta.momentos.isEmpty && propuesta.cadaHoras == nil && propuesta.vecesAlDia == nil && !tieneRango
            let renglonSinAgenda = MapeoIndicacion.pautaFueraDeAgenda(textoRango ?? renglon ?? "")
            let sinAgenda = propuesta.condicional == true || renglonSinAgenda || MapeoIndicacion.pautaFueraDeAgenda(indicaciones)
            guard sinPauta || sinAgenda else {
                programables.append(propuesta)
                continue
            }
            let fuenteNota = renglonSinAgenda ? (textoRango ?? renglon) : fuente
            if let fuenteNota {
                if !notas.contains(where: { MapeoIndicacion.normalizar($0) == MapeoIndicacion.normalizar(fuenteNota) }) { notas.append(fuenteNota) }
            } else {
                propuesta.condicional = sinAgenda
                programables.append(propuesta)
            }
        }
        return (programables, notas)
    }

    /// El código compara con el tratamiento y con el texto de la foto (no el modelo).
    private func revisar(_ propuestas: [IndicacionPropuesta], texto: String, tratamiento: [Medicamento]) -> [IndicacionRevisada] {
        propuestas.map { p in
            var dudosos = MapeoIndicacion.dudosos(de: p).union(MapeoIndicacion.noEncontrados(p, en: texto))
            if p.condicional == true { dudosos.insert("condicion") }
            // Solo se propone un horario de rutina cuando no hay un intervalo explícito.
            let tieneMotivo = !(p.motivoHorario ?? "").trimmingCharacters(in: .whitespaces).isEmpty
            if p.cadaHoras == nil, MapeoIndicacion.rangoHoras(de: p) == nil, tieneMotivo {
                dudosos.insert("horario")
            }
            let igual = tratamiento.first { MapeoIndicacion.coincide(p, con: $0) }
            var anterior = tratamiento.first { MapeoIndicacion.mismoNombre(p, con: $0) && !MapeoIndicacion.coincide(p, con: $0) }
            if let igual {
                anterior = nil
                if let rango = MapeoIndicacion.rangoHoras(de: p),
                   igual.inicioIntervalo == nil || igual.cadaHoras.map({ rango.contains($0) }) != true {
                    anterior = igual
                }
            }
            return IndicacionRevisada(
                propuesta: p,
                yaRegistrado: igual != nil && anterior == nil,
                dudosos: dudosos,
                fuente: MapeoIndicacion.textoDelRango(de: p.nombre, en: texto) ?? MapeoIndicacion.renglon(de: p.nombre, en: texto),
                cambioDe: anterior?.id,
                nombreAnterior: anterior?.nombreTecnico
            )
        }
    }

    private func pedirReceta(sesion: LanguageModelSession, imagen: CGImage, texto: String) async throws -> RecetaPropuesta {
        let opciones = GenerationOptions(samplingMode: .greedy)
        let guia = texto.isEmpty
            ? "No se pudo reconocer texto; léelo de la imagen."
            : "Texto que reconoció la cámara, renglón por renglón (puede tener errores de lectura):\n\(texto)"
        if Self.puedeVerImagenes {
            return try await sesion.respond(generating: RecetaPropuesta.self, options: opciones) {
                "Lee esta receta. Puedes consultar leerTratamientoActivo para ver lo que la persona ya toma."
                Attachment(imagen).label("receta")
                guia
            }.content
        } else {
            let prompt = "Lee esta receta a partir de su texto. Puedes consultar leerTratamientoActivo.\n\n\(guia)"
            return try await sesion.respond(to: prompt, generating: RecetaPropuesta.self, options: opciones).content
        }
    }

    // MARK: Caja

    /// Lee la caja de un medicamento (RF-03).
    func leerCaja(_ imagen: CGImage) async throws -> CajaLeida {
        try await leerCajaRevisada(imagen).caja
    }

    /// Lee la caja y verifica el nombre contra el texto de la foto.
    func leerCajaRevisada(_ imagen: CGImage) async throws -> CajaRevisada {
        try verificarDisponible()
        leyendo = true
        defer {
            leyendo = false
            etapa = .inactivo
        }
        let reloj = ContinuousClock()
        let inicio = reloj.now

        etapa = .buscandoTexto
        let texto = await LectorTexto.leer(imagen)
        let enNube = Self.motor == .deepseek && texto.count >= 4
        let conApple = Self.appleLista
        guard enNube || (conApple && (Self.puedeVerImagenes || texto.count >= 4)) else {
            ultimaDuracion = reloj.now - inicio
            return CajaRevisada(caja: CajaLeida(legible: false), dudosos: [], fuente: nil)
        }

        etapa = .ordenando
        if enNube {
            do {
                let r = try await ServicioDeepSeek.leerCaja(texto: texto)
                ultimaDuracion = reloj.now - inicio
                let nombre = (r.nombre ?? "").trimmingCharacters(in: .whitespaces)
                guard r.legible, !nombre.isEmpty else {
                    return CajaRevisada(caja: CajaLeida(legible: false), dudosos: ["nombre"], fuente: nil)
                }
                let caja = CajaLeida(legible: true, nombre: nombre,
                                     concentracion: (r.concentracion ?? "").isEmpty ? nil : r.concentracion,
                                     pastillas: (r.pastillas ?? 0) > 0 ? r.pastillas : nil)
                return revisarCaja(caja, texto: texto)
            } catch {
                guard conApple else {
                    ultimaDuracion = reloj.now - inicio
                    throw Fallo.noPudoLeer
                }
            }
        }
        let sesion = LanguageModelSession(instructions: Self.instruccionesCaja)
        let opciones = GenerationOptions(samplingMode: .greedy)
        let guia = texto.isEmpty ? "" : "Texto que reconoció la cámara (puede tener errores):\n\(Self.recortar(texto))"
        do {
            var caja: CajaLeida
            if Self.puedeVerImagenes {
                caja = try await sesion.respond(generating: CajaLeida.self, options: opciones) {
                    "Lee esta caja de medicamento."
                    Attachment(imagen).label("caja")
                    guia
                }.content
            } else {
                caja = try await sesion.respond(to: "Lee esta caja de medicamento a partir de su texto.\n\n\(guia)",
                                                generating: CajaLeida.self, options: opciones).content
            }
            ultimaDuracion = reloj.now - inicio
            etapa = .revisando
            if caja.nombre?.trimmingCharacters(in: .whitespaces).isEmpty ?? true {
                caja = CajaLeida(legible: false, concentracion: caja.concentracion, pastillas: caja.pastillas)
                return CajaRevisada(caja: caja, dudosos: ["nombre"], fuente: nil)
            }
            return revisarCaja(caja, texto: texto)
        } catch {
            ultimaDuracion = reloj.now - inicio
            throw traducir(error)
        }
    }

    private func revisarCaja(_ caja: CajaLeida, texto: String) -> CajaRevisada {
        var dudosos = Set<String>()
        if !texto.isEmpty {
            if let n = caja.nombre, !MapeoIndicacion.aparece(n, en: texto) { dudosos.insert("nombre") }
            if let c = caja.concentracion, !MapeoIndicacion.apareceConcentracion(c, en: texto) { dudosos.insert("concentracion") }
        }
        return CajaRevisada(caja: caja, dudosos: dudosos, fuente: caja.nombre.flatMap { MapeoIndicacion.renglon(de: $0, en: texto) })
    }

    // MARK: Apoyo

    private func verificarDisponible() throws {
        if case .noDisponible(let motivo) = Self.disponibilidad { throw Fallo.noDisponible(motivo) }
    }

    private static func recortar(_ texto: String) -> String {
        texto.count > maximoTexto ? String(texto.prefix(maximoTexto)) : texto
    }

    /// Errores del modelo → mensaje para la persona (camino "otra foto o sin receta").
    private func traducir(_ error: Error) -> Error {
        if let e = error as? LanguageModelError {
            switch e {
            case .unsupportedCapability, .unsupportedLanguageOrLocale:
                return Fallo.noDisponible("Apple Intelligence no puede leer esta foto en este iPhone.")
            default:
                return Fallo.noPudoLeer
            }
        }
        if error is SystemLanguageModel.Error {
            return Fallo.noDisponible("Apple Intelligence se está preparando. Intenta en unos minutos.")
        }
        return Fallo.noPudoLeer
    }
}
