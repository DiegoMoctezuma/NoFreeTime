import Foundation
import Testing
@testable import IOSLAB_9Nov

struct AvisosTests {
    private let idToma = "3F2504E0-4F89-11D3-9A0C-0305E82C3301-20261110-0800"

    @Test func uuidDeAlarmaEsEstable() {
        #expect(Identificadores.alarma(idToma: idToma) == Identificadores.alarma(idToma: idToma))
        #expect(Identificadores.alarma(idToma: idToma, repeticion: 1) == Identificadores.alarma(idToma: idToma, repeticion: 1))
    }

    @Test func repeticionesTienenOtroIdentificador() {
        let ids = (0...Identificadores.maxRepeticiones).map { Identificadores.alarma(idToma: idToma, repeticion: $0) }
        #expect(Set(ids).count == ids.count)
        #expect(Identificadores.notificacion(idToma: idToma) == idToma)
        #expect(Identificadores.notificacion(idToma: idToma, repeticion: 2) == idToma + "-r2")
    }

    @Test func otraTomaOtroUUID() {
        let otra = "3F2504E0-4F89-11D3-9A0C-0305E82C3301-20261110-2000"
        #expect(Identificadores.alarma(idToma: idToma) != Identificadores.alarma(idToma: otra))
    }

    @Test func uuidEsVersion5() {
        let u = Identificadores.alarma(idToma: idToma).uuid
        #expect(u.6 >> 4 == 5)
        #expect(u.8 >> 6 == 0b10)
    }

    @Test @MainActor func idsDeNotificacionEmpiezanConElMedicamento() {
        // Cancelar por medicamento filtra por prefijo: el id de la toma empieza con el UUID del medicamento.
        let medID = UUID()
        let id = TomaProgramada.id(medicamentoID: medID, fecha: .now)
        #expect(Identificadores.notificacion(idToma: id, repeticion: 1).hasPrefix(medID.uuidString))
    }
}
