import Foundation
import FoundationModels

// Tipos que genera Foundation Models (CONTRATOS §6, PRD A5).
// Son propuestas: nada de esto se guarda sin "Está bien" de la persona.

@Generable(description: "Momento del día en que se toma el medicamento")
nonisolated enum MomentoPropuesto: Equatable, Sendable {
    case desayuno, comida, cena, dormir
    /// La receta da una hora exacta (va en `horaTexto`).
    case horaExacta
}

@Generable(description: "Medicamento o cuidado con pauta en la receta")
nonisolated struct IndicacionPropuesta: Equatable, Sendable {
    @Guide(description: "Nombre del medicamento sin concentración o frase corta del cuidado, copiados de la receta")
    var nombre: String

    @Guide(description: "Concentración, por ejemplo \"50 mg\". Vacío si no aparece")
    var concentracion: String?

    @Guide(description: "Cantidad o duración de cada vez, si está escrita. No confundir con los días del tratamiento")
    var dosis: String?

    @Guide(description: "Verdadero si la receta indica aplicar el producto, por ejemplo una pomada o crema. Vacío si no se puede determinar")
    var aplicacion: Bool?

    @Guide(description: "Verdadero si es una acción como lavados, curaciones o ejercicios. Falso para tomar o aplicar un medicamento")
    var cuidado: Bool?

    @Guide(description: "Verdadero si depende de una condición, por ejemplo si hay síntomas o según necesidad")
    var condicional: Bool?

    @Guide(description: "Cuántas veces al día, si la receta lo dice")
    var vecesAlDia: Int?

    @Guide(description: "Intervalo fijo en horas enteras, por ejemplo 2 u 8. Vacío si la receta da un rango")
    var cadaHoras: Int?

    @Guide(description: "Límite inferior de un rango como cada 2–3 horas: 2. Vacío si no hay rango")
    var intervaloMinHoras: Int?

    @Guide(description: "Límite superior de un rango como cada 2–3 horas: 3. Vacío si no hay rango")
    var intervaloMaxHoras: Int?

    @Guide(description: "Momentos del día que dice la receta: desayuno, comida, cena, dormir u horaExacta. Vacío si solo dice cada cuántas horas")
    var momentos: [MomentoPropuesto]

    @Guide(description: "Si la receta da una hora exacta, en formato HH:mm, por ejemplo \"07:00\"")
    var horaTexto: String?

    @Guide(description: "Durante cuántos días, si la receta lo dice")
    var duracionDias: Int?

    @Guide(description: "Indicaciones breves de la receta, por ejemplo \"con alimentos\"")
    var indicaciones: String?

    @Guide(description: "Nombres de los campos de esta indicación que no se leen bien o que no aparecen: nombre, concentracion, dosis, cadaHoras, momentos, duracionDias")
    var camposDudosos: [String]

    @Guide(description: "Si elegiste un momento con la rutina de la persona, explica por qué en una frase corta. Vacío si hay un intervalo en horas o la receta ya decía el momento")
    var motivoHorario: String?

    init(nombre: String, concentracion: String? = nil, dosis: String? = nil, vecesAlDia: Int? = nil,
         cadaHoras: Int? = nil, momentos: [MomentoPropuesto] = [], horaTexto: String? = nil,
         duracionDias: Int? = nil, indicaciones: String? = nil, camposDudosos: [String] = [],
         motivoHorario: String? = nil, aplicacion: Bool? = nil, cuidado: Bool? = nil, condicional: Bool? = nil,
         intervaloMinHoras: Int? = nil, intervaloMaxHoras: Int? = nil) {
        self.nombre = nombre
        self.concentracion = concentracion
        self.dosis = dosis
        self.aplicacion = aplicacion
        self.cuidado = cuidado
        self.condicional = condicional
        self.vecesAlDia = vecesAlDia
        self.cadaHoras = cadaHoras
        self.intervaloMinHoras = intervaloMinHoras
        self.intervaloMaxHoras = intervaloMaxHoras
        self.momentos = momentos
        self.horaTexto = horaTexto
        self.duracionDias = duracionDias
        self.indicaciones = indicaciones
        self.camposDudosos = camposDudosos
        self.motivoHorario = motivoHorario
    }
}

@Generable(description: "Lo que se leyó de una receta médica")
nonisolated struct RecetaPropuesta: Sendable {
    @Guide(description: "true si la imagen es una receta con texto legible; false si está borrosa, no tiene texto o no es una receta")
    var legible: Bool

    @Guide(description: "Un elemento por medicamento o cuidado con pauta, como lavados nasales. Vacío si no hay acciones programables")
    var medicamentos: [IndicacionPropuesta]

    @Guide(description: "Indicaciones generales, restricciones, cuidados sin pauta, acciones condicionales, estudios o próxima cita. Copia cada instrucción completa y conserva sus condiciones y negaciones. Sin datos personales")
    var notas: [String]
}

@Generable(description: "Lo que se leyó de la caja de un medicamento")
nonisolated struct CajaLeida: Equatable, Sendable {
    @Guide(description: "true si se lee el nombre del medicamento en la caja")
    var legible: Bool

    @Guide(description: "Nombre del medicamento (sustancia activa), sin la concentración. Ejemplo: Losartán")
    var nombre: String?

    @Guide(description: "Concentración, por ejemplo \"50 mg\"")
    var concentracion: String?

    @Guide(description: "Cuántas tabletas o cápsulas trae la caja")
    var pastillas: Int?

    init(legible: Bool, nombre: String? = nil, concentracion: String? = nil, pastillas: Int? = nil) {
        self.legible = legible
        self.nombre = nombre
        self.concentracion = concentracion
        self.pastillas = pastillas
    }
}

/// Indicación lista para la pantalla de propuesta (WP-03).
/// `yaRegistrado` lo calcula el código (`MapeoIndicacion.coincide`), no el modelo.
struct IndicacionRevisada: Identifiable, Equatable {
    let id: UUID
    var propuesta: IndicacionPropuesta
    var yaRegistrado: Bool
    /// Campos a mostrar en amarillo: los que marcó el modelo más los que el código detecta vacíos
    /// o no encuentra en el texto de la foto.
    var dudosos: Set<String>
    /// Renglón de la foto (texto de Vision) donde aparece el medicamento: "Esto dice tu receta".
    var fuente: String?
    /// Medicamento del tratamiento con el mismo nombre y otra concentración: posible cambio de receta.
    var cambioDe: UUID?
    /// "Losartán 50 mg": cómo está registrado hoy (para preguntar si es un cambio).
    var nombreAnterior: String?

    init(id: UUID = UUID(), propuesta: IndicacionPropuesta, yaRegistrado: Bool = false, dudosos: Set<String>? = nil,
         fuente: String? = nil, cambioDe: UUID? = nil, nombreAnterior: String? = nil) {
        self.id = id
        self.propuesta = propuesta
        self.yaRegistrado = yaRegistrado
        self.dudosos = dudosos ?? MapeoIndicacion.dudosos(de: propuesta)
        self.fuente = fuente
        self.cambioDe = cambioDe
        self.nombreAnterior = nombreAnterior
    }
}
