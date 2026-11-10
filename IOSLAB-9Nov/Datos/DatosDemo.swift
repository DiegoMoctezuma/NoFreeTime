import Foundation
import SwiftData

/// Datos de ejemplo (ficticios) del demo: don Ernesto y sus 3 medicamentos (CONTRATOS §9).
enum DatosDemo {
    static func cargar(en contexto: ModelContext) {
        borrarTodo(en: contexto)
        contexto.insert(Perfil(nombre: "Ernesto", esDemo: true))
        let hoy = Calendar.current.startOfDay(for: .now)
        contexto.insert(Medicamento(nombre: "Losartán", concentracion: "50 mg", apodo: "la de la presión",
                                    colorHex: Paleta.medicamentos[0], pastillasPorCaja: 30, dosis: "1 tableta",
                                    momentos: [.desayuno], cadaHoras: 24, inicio: hoy,
                                    indicaciones: "con alimentos", aviso: .alarma))
        contexto.insert(Medicamento(nombre: "Metformina", concentracion: "850 mg", apodo: "la del azúcar",
                                    colorHex: Paleta.medicamentos[2], pastillasPorCaja: 60, dosis: "1 tableta",
                                    momentos: [.desayuno, .cena], cadaHoras: 12, inicio: hoy,
                                    indicaciones: "con alimentos", aviso: .alarma))
        contexto.insert(Medicamento(nombre: "Atorvastatina", concentracion: "20 mg", apodo: "la del colesterol",
                                    colorHex: Paleta.medicamentos[3], pastillasPorCaja: 30, dosis: "1 tableta",
                                    momentos: [.dormir], cadaHoras: 24, inicio: hoy,
                                    aviso: .recordatorio))
        try? contexto.save()
    }

    static func borrarTodo(en contexto: ModelContext) {
        try? contexto.delete(model: RegistroToma.self)
        try? contexto.delete(model: NotaReceta.self)
        try? contexto.delete(model: Medicamento.self)
        try? contexto.delete(model: Perfil.self)
        try? contexto.save()
    }
}
