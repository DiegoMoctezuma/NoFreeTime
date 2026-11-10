import Foundation
import SwiftData
import Testing
@testable import IOSLAB_9Nov

@MainActor
struct ConfianzaPersistenciaTests {
    private func contenedor() throws -> ModelContainer {
        try ModelContainer(for: Almacen.esquema,
                           configurations: [ModelConfiguration(schema: Almacen.esquema, isStoredInMemoryOnly: true)])
    }

    @Test func perfilAnteriorSigueSinContactoYPuedeConfigurarYQuitar() throws {
        let almacen = try contenedor()
        let contexto = almacen.mainContext
        let perfil = Perfil(nombre: "Ernesto")
        contexto.insert(perfil)
        try contexto.save()
        #expect(perfil.personaConfianza == nil)
        let contacto = try ContactoConfianza(nombre: "Ana", telefono: "+525512345678", canal: .mensajes)
        try perfil.guardarConfianza(contacto, en: contexto)
        let otroContexto = ModelContext(almacen)
        let guardado = try #require(otroContexto.fetch(FetchDescriptor<Perfil>()).first)
        #expect(guardado.personaConfianza == contacto)
        try perfil.guardarConfianza(nil, en: contexto)
        let contextoNuevo = ModelContext(almacen)
        let quitado = try #require(contextoNuevo.fetch(FetchDescriptor<Perfil>()).first)
        #expect(quitado.personaConfianza == nil)
        #expect(quitado.confianzaTelefono == nil)
    }

    @Test func datosInvalidosOCanalDesconocidoNoHabilitanContacto() {
        let perfil = Perfil(nombre: "Ernesto")
        perfil.confianzaNombre = "Ana"
        perfil.confianzaTelefono = "+123"
        perfil.confianzaCanal = "mensajes"
        #expect(perfil.personaConfianza == nil)
        perfil.confianzaTelefono = "+525512345678"
        perfil.confianzaCanal = "desconocido"
        #expect(perfil.personaConfianza == nil)
    }

    @Test func reemplazarPorDemoNoConservaContactoReal() throws {
        let almacen = try contenedor()
        let contexto = almacen.mainContext
        let perfil = Perfil(nombre: "Ernesto")
        contexto.insert(perfil)
        try perfil.guardarConfianza(ContactoConfianza(nombre: "Ana", telefono: "+525512345678", canal: .mensajes), en: contexto)
        DatosDemo.cargar(en: contexto)
        let perfiles = try contexto.fetch(FetchDescriptor<Perfil>())
        #expect(perfiles.count == 1)
        #expect(perfiles.first?.esDemo == true)
        #expect(perfiles.first?.personaConfianza == nil)
    }

    @Test func adaptadorNoConfundeCuidadoConMedicinaNiOmitidaConConfirmada() {
        let fecha = Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: 10))!
        let perfil = Perfil(nombre: "Ernesto")
        let med = Medicamento(nombre: "No compartir este nombre", dosis: "100 mg", momentos: [.desayuno], inicio: fecha)
        let toma = TomaProgramada(medicamentoID: med.id, fecha: fecha.addingTimeInterval(8 * 3600), momento: .desayuno)
        let registro = RegistroToma(idToma: toma.id, medicamentoID: med.id, programada: toma.fecha, registrada: nil, estado: .sePaso)
        let cuidado = Medicamento(nombre: "Caminar", dosis: "10 minutos", tipoAccion: .cuidado, momentos: [.comida], inicio: fecha)
        let actividad = TomaProgramada(medicamentoID: cuidado.id, fecha: fecha.addingTimeInterval(14 * 3600), momento: .comida)
        let realizado = RegistroToma(idToma: actividad.id, medicamentoID: cuidado.id, programada: actividad.fecha, registrada: actividad.fecha, estado: .tomada)
        let resumen = ResumenConfianza.delDia(fecha, medicamentos: [med, cuidado], perfil: perfil, registros: [registro, realizado], ahora: fecha.addingTimeInterval(15 * 3600))
        #expect(resumen.omitidas == 1)
        #expect(resumen.confirmadas == 1)
        #expect(resumen.total == 2)
        #expect(!resumen.todoConfirmado)
        #expect(!resumen.mensaje(nombre: perfil.nombre, fecha: fecha).contains("100 mg"))
        #expect(!resumen.mensaje(nombre: perfil.nombre, fecha: fecha).contains(med.nombre))
    }
}
