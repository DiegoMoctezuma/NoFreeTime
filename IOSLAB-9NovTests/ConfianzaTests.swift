import Foundation
import Testing
#if SWIFT_PACKAGE
@testable import ConfianzaCore
#else
@testable import IOSLAB_9Nov
#endif

struct ConfianzaTests {
    private let ahora = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func telefonoInternacionalSeNormalizaSinCambiarPais() throws {
        let contacto = try ContactoConfianza(nombre: "  Ana  ", telefono: "+52 (55) 1234-5678", canal: .mensajes)
        #expect(contacto.nombre == "Ana")
        #expect(contacto.telefono == "+525512345678")
        #expect(contacto.urlLlamada.absoluteString == "tel:+525512345678")
    }

    @Test(arguments: ["5512345678", "+123", "+0123456789", "+525512345678;123", "+525512345678?body=hola", "+１２３４５６７８９", "+1234567890123456", "+5255\n12345678"])
    func rechazaNumerosAmbiguosOConInyeccion(telefono: String) {
        #expect(throws: ContactoConfianza.Fallo.self) {
            try ContactoConfianza(nombre: "Ana", telefono: telefono, canal: .mensajes)
        }
    }

    @Test(arguments: ["", "  ", "Ana\nMensaje", String(repeating: "a", count: 61)])
    func rechazaNombreVacioOQueAlteraElMensaje(nombre: String) {
        #expect(throws: ContactoConfianza.Fallo.self) {
            try ContactoConfianza(nombre: nombre, telefono: "+525512345678", canal: .mensajes)
        }
    }

    @Test func whatsappCodificaTextoSinCambiarDestinatario() throws {
        let contacto = try ContactoConfianza(nombre: "Ana", telefono: "+525512345678", canal: .whatsapp)
        let url = try #require(contacto.urlWhatsApp(texto: "Hola & gracias? #1"))
        let partes = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        #expect(partes.scheme == "https")
        #expect(partes.host == "wa.me")
        #expect(partes.path == "/525512345678")
        #expect(partes.queryItems == [URLQueryItem(name: "text", value: "Hola & gracias? #1")])
    }

    @Test func silencioYOmisionesNuncaCuentanComoConfirmadas() {
        let resumen = ResumenConfianza(tomas: [
            .init(id: "a", fecha: ahora.addingTimeInterval(-7200), estado: .confirmada),
            .init(id: "b", fecha: ahora.addingTimeInterval(-3600), estado: .omitida),
            .init(id: "c", fecha: ahora.addingTimeInterval(-1800), estado: .sinRegistro),
            .init(id: "d", fecha: ahora.addingTimeInterval(-1799), estado: .sinRegistro),
            .init(id: "e", fecha: ahora.addingTimeInterval(3600), estado: .sinRegistro)
        ], ahora: ahora)
        #expect(resumen.confirmadas == 1)
        #expect(resumen.omitidas == 1)
        #expect(resumen.sinConfirmar == 1)
        #expect(resumen.pendientes == 2)
        #expect(!resumen.todoConfirmado)
    }

    @Test func diaVacioNoDiceQueTomoTodo() {
        let resumen = ResumenConfianza(tomas: [], ahora: ahora)
        #expect(!resumen.todoConfirmado)
        #expect(resumen.total == 0)
        #expect(resumen.mensaje(nombre: "Ernesto", fecha: ahora).contains("Sin actividades programadas"))
    }

    @Test func diaCompletoEsPositivoSinNombresDeMedicamentos() {
        let resumen = ResumenConfianza(tomas: [.init(id: "a", fecha: ahora, estado: .confirmada)], ahora: ahora)
        #expect(resumen.todoConfirmado)
        let mensaje = resumen.mensaje(nombre: "Ernesto", fecha: ahora)
        #expect(mensaje.contains("Ernesto confirmó todas sus actividades de hoy"))
        #expect(!mensaje.contains("tomó todo"))
        #expect(!mensaje.contains("mg"))
    }

    @Test func deduplicaIdentificadoresSinInflarConteo() {
        let toma = ActividadConfianza(id: "a", fecha: ahora, estado: .confirmada)
        let resumen = ResumenConfianza(tomas: [toma, toma], ahora: ahora)
        #expect(resumen.total == 1)
        #expect(resumen.confirmadas == 1)
    }

    @Test func resumenNoInterpretaRegistroFuturoComoConfirmacion() {
        let resumen = ResumenConfianza(tomas: [.init(id: "a", fecha: ahora.addingTimeInterval(3600), estado: .sinRegistro)], ahora: ahora)
        #expect(resumen.pendientes == 1)
        #expect(resumen.sinConfirmar == 0)
        #expect(!resumen.todoConfirmado)
    }
}
