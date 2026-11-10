import Foundation
import Testing
@testable import IOSLAB_9Nov

@MainActor
struct MapeoTests {
    @Test func momentosExplicitosSeMapean() {
        let p = IndicacionPropuesta(nombre: "Metformina", concentracion: "850 mg", dosis: "1 tableta",
                                    vecesAlDia: 2, momentos: [.desayuno, .cena])
        let r = MapeoIndicacion.momentos(de: p)
        #expect(r.momentos == [.desayuno, .cena])
        #expect(r.dudosos.isEmpty)
    }

    @Test(arguments: [24, 12, 8])
    func soloCadaHorasNoSeConvierteEnMomentos(cadaHoras: Int) {
        let p = IndicacionPropuesta(nombre: "Losartán", dosis: "1 tableta", cadaHoras: cadaHoras)
        let r = MapeoIndicacion.momentos(de: p)
        #expect(r.momentos.isEmpty)
        #expect(r.dudosos.isEmpty)
    }

    @Test func horaExactaUsaHoraTexto() {
        let p = IndicacionPropuesta(nombre: "Levotiroxina", dosis: "1 tableta", momentos: [.horaExacta], horaTexto: "07:00")
        #expect(MapeoIndicacion.momentos(de: p).momentos == [.horaFija(DateComponents(hour: 7, minute: 0))])
        let sinHora = IndicacionPropuesta(nombre: "Levotiroxina", dosis: "1 tableta", momentos: [.horaExacta])
        #expect(MapeoIndicacion.momentos(de: sinHora).dudosos.contains("momentos"))
    }

    @Test func camposVaciosQuedanDudosos() {
        let p = IndicacionPropuesta(nombre: "Atorvastatina", momentos: [.dormir], camposDudosos: ["concentracion", "inventado"])
        let d = MapeoIndicacion.dudosos(de: p)
        #expect(d == ["concentracion", "dosis"])
    }

    @Test func indicacionAMedicamento() {
        let hoy = Date.now
        let p = IndicacionPropuesta(nombre: " Losartán ", concentracion: "50 mg", dosis: "1 tableta",
                                    momentos: [.desayuno], duracionDias: 30, indicaciones: "con alimentos")
        let m = MapeoIndicacion.medicamento(de: p, inicio: hoy)
        #expect(m.nombre == "Losartán")
        #expect(m.concentracion == "50 mg")
        #expect(m.dosis == "1 tableta")
        #expect(m.momentos == [.desayuno])
        #expect(m.cadaHoras == nil)
        #expect(m.duracionDias == 30)
        #expect(m.inicio == hoy)
        #expect(m.aviso == .alarma)
    }

    @Test func yaRegistradoComparaNombreNormalizadoYConcentracion() {
        let m = Medicamento(nombre: "Losartán", concentracion: "50 mg", dosis: "1 tableta", momentos: [.desayuno])
        #expect(MapeoIndicacion.coincide(IndicacionPropuesta(nombre: "LOSARTAN", concentracion: "50mg"), con: m))
        #expect(!MapeoIndicacion.coincide(IndicacionPropuesta(nombre: "Losartán", concentracion: "100 mg"), con: m))
        #expect(MapeoIndicacion.mismoNombre(IndicacionPropuesta(nombre: "Losartán", concentracion: "100 mg"), con: m))
        #expect(!MapeoIndicacion.coincide(IndicacionPropuesta(nombre: "Metformina", concentracion: "50 mg"), con: m))
    }

    @Test func cajaSeVinculaConSuMedicamento() {
        let a = Medicamento(nombre: "Losartán", concentracion: "50 mg", dosis: "1", momentos: [.desayuno])
        let b = Medicamento(nombre: "Metformina", concentracion: "850 mg", dosis: "1", momentos: [.cena])
        let caja = CajaLeida(legible: true, nombre: "losartán", concentracion: "50 mg", pastillas: 30)
        #expect(MapeoIndicacion.medicamento(paraCaja: caja, en: [a, b])?.id == a.id)
        #expect(MapeoIndicacion.medicamento(paraCaja: CajaLeida(legible: true, nombre: "Omeprazol"), en: [a, b]) == nil)
    }
}
