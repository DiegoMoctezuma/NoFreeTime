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

@Generable(description: "Indicación de la receta para un solo medicamento")
nonisolated struct IndicacionPropuesta: Equatable, Sendable {
    @Guide(description: "Nombre del medicamento tal como aparece, sin la concentración. Ejemplo: Losartán")
    var nombre: String

    @Guide(description: "Concentración, por ejemplo \"50 mg\". Vacío si no aparece")
    var concentracion: String?

    @Guide(description: "Cuánto se toma cada vez, por ejemplo \"1 tableta\". Vacío si no aparece")
    var dosis: String?

    @Guide(description: "Cuántas veces al día, si la receta lo dice")
    var vecesAlDia: Int?

    @Guide(description: "Cada cuántas horas (8, 12 o 24), si la receta lo dice")
    var cadaHoras: Int?

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

    init(nombre: String, concentracion: String? = nil, dosis: String? = nil, vecesAlDia: Int? = nil,
         cadaHoras: Int? = nil, momentos: [MomentoPropuesto] = [], horaTexto: String? = nil,
         duracionDias: Int? = nil, indicaciones: String? = nil, camposDudosos: [String] = []) {
        self.nombre = nombre
        self.concentracion = concentracion
        self.dosis = dosis
        self.vecesAlDia = vecesAlDia
        self.cadaHoras = cadaHoras
        self.momentos = momentos
        self.horaTexto = horaTexto
        self.duracionDias = duracionDias
        self.indicaciones = indicaciones
        self.camposDudosos = camposDudosos
    }
}

@Generable(description: "Lo que se leyó de una receta médica")
nonisolated struct RecetaPropuesta: Sendable {
    @Guide(description: "true si la imagen es una receta con texto legible; false si está borrosa, no tiene texto o no es una receta")
    var legible: Bool

    @Guide(description: "Un elemento por cada medicamento recetado. Vacío si no es legible")
    var medicamentos: [IndicacionPropuesta]
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
    /// Campos a mostrar en amarillo: los que marcó el modelo más los que el código detecta vacíos.
    var dudosos: Set<String>

    init(id: UUID = UUID(), propuesta: IndicacionPropuesta, yaRegistrado: Bool = false, dudosos: Set<String>? = nil) {
        self.id = id
        self.propuesta = propuesta
        self.yaRegistrado = yaRegistrado
        self.dudosos = dudosos ?? MapeoIndicacion.dudosos(de: propuesta)
    }
}
