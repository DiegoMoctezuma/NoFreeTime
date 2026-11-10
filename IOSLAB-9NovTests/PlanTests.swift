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
                              cadaHoras: 12, duracionDias: 2, inicio: fecha(2026, 11, 9))
        let tomas = Plan.tomas(de: med, perfil: perfil, desde: fecha(2026, 11, 9), dias: 5)
        #expect(tomas.count == 4)   // 2 días × 2 momentos
        #expect(tomas.first?.fecha == fecha(2026, 11, 9, 8, 0))
        #expect(tomas.last?.fecha == fecha(2026, 11, 10, 20, 0))
    }

    @Test func intervaloEmpiezaEnLaHoraConfirmadaYRespetaLaDuracion() throws {
        let inicio = fecha(2026, 11, 9, 14, 30)
        let med = Medicamento(nombre: "Ejemplo", dosis: "1 tableta", momentos: [],
                              cadaHoras: 8, inicioIntervalo: inicio, duracionDias: 1, inicio: inicio)
        let perfil = Perfil(nombre: "Ernesto")
        let tomas = Plan.tomas(de: med, perfil: perfil, desde: inicio, dias: 3)
        #expect(tomas.map(\.fecha) == [inicio, fecha(2026, 11, 9, 22, 30), fecha(2026, 11, 10, 6, 30)])
        let ultima = try #require(tomas.last)
        #expect(TomaProgramada.partes(de: ultima.id)?.fecha == ultima.fecha)
        #expect(TomaProgramada.partes(de: ultima.id)?.medicamentoID == med.id)
        #expect(Plan.tomas(de: med, perfil: perfil, desde: fecha(2026, 11, 10), dias: 1) == [ultima])
    }

    @Test func momentoSeCodificaComoTexto() {
        let m = Momento.horaFija(DateComponents(hour: 7, minute: 30))
        #expect(m.codigo == "hora:07:30")
        #expect(Momento(codigo: "hora:07:30") == m)
        #expect(Momento(codigo: "cena") == .cena)
    }

    // MARK: Límite de avisos de iOS (64)

    @Test func seleccionNuncaPasaDelTopeYGuardaLasMasProximas() {
        let base = fecha(2026, 11, 9, 8, 0)
        let candidatos: [(toma: TomaProgramada, costo: Int)] = (0..<48).map { h in
            (toma: TomaProgramada(medicamentoID: UUID(), fecha: base.addingTimeInterval(Double(h) * 3600), momento: .desayuno),
             costo: 3)
        }
        let elegidas = Reprogramador.seleccionar(candidatos.shuffled(), tope: 60)
        #expect(elegidas.count == 20)   // 20 recordatorios × 3 avisos = 60
        #expect(elegidas.map(\.fecha) == (0..<20).map { base.addingTimeInterval(Double($0) * 3600) })
    }

    @Test func seleccionNoSeSaltaUnaTomaCercanaPorUnaLejana() {
        let base = fecha(2026, 11, 9, 8, 0)
        let cercana = TomaProgramada(medicamentoID: UUID(), fecha: base, momento: .desayuno)
        let lejana = TomaProgramada(medicamentoID: UUID(), fecha: base.addingTimeInterval(3600), momento: .desayuno)
        let elegidas = Reprogramador.seleccionar([(toma: lejana, costo: 1), (toma: cercana, costo: 3)], tope: 2)
        #expect(elegidas.isEmpty)
    }

    @Test func pautaCadaUnaODosHorasNoRepiteAvisos() {
        let cadaHora = Medicamento(nombre: "Ejemplo", dosis: "1 tableta", momentos: [], cadaHoras: 1,
                                   inicioIntervalo: fecha(2026, 11, 9, 8, 0))
        let cadaOcho = Medicamento(nombre: "Ejemplo", dosis: "1 tableta", momentos: [], cadaHoras: 8,
                                   inicioIntervalo: fecha(2026, 11, 9, 8, 0))
        let conComidas = Medicamento(nombre: "Ejemplo", dosis: "1 tableta", momentos: [.desayuno])
        #expect(ServicioAvisosSistema.repeticiones(para: cadaHora) == 0)
        #expect(ServicioAvisosSistema.repeticiones(para: cadaOcho) == Identificadores.maxRepeticiones)
        #expect(ServicioAvisosSistema.repeticiones(para: conComidas) == Identificadores.maxRepeticiones)
    }
}
