import Foundation
import Testing
@testable import IOSLAB_9Nov

@MainActor
struct PlanTests {
    private func fecha(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0, _ min: Int = 0) -> Date {
        Calendar.current.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }

    @Test func idDeTomaEsEstableYSeParte() throws {
        let medID = UUID()
        let f = fecha(2026, 11, 10, 8, 0)
        let id = TomaProgramada.id(medicamentoID: medID, fecha: f)
        #expect(id == "\(medID.uuidString)-20261110-0800")
        #expect(id == TomaProgramada.id(medicamentoID: medID, fecha: f))
        let partes = try #require(TomaProgramada.partes(de: id))
        #expect(partes.medicamentoID == medID)
        #expect(partes.fecha == f)
    }

    @Test func tomasRespetanRutinaYDuracion() {
        let perfil = Perfil(nombre: "Ernesto")
        let med = Medicamento(nombre: "Metformina", dosis: "1 tableta", momentos: [.desayuno, .cena],
                              duracionDias: 2, inicio: fecha(2026, 11, 9))
        let tomas = Plan.tomas(de: med, perfil: perfil, desde: fecha(2026, 11, 9), dias: 5)
        #expect(tomas.count == 4)   // 2 días × 2 momentos
        #expect(tomas.first?.fecha == fecha(2026, 11, 9, 8, 0))
        #expect(tomas.last?.fecha == fecha(2026, 11, 10, 20, 0))
    }

    @Test func momentoSeCodificaComoTexto() {
        let m = Momento.horaFija(DateComponents(hour: 7, minute: 30))
        #expect(m.codigo == "hora:07:30")
        #expect(Momento(codigo: "hora:07:30") == m)
        #expect(Momento(codigo: "cena") == .cena)
    }
}
