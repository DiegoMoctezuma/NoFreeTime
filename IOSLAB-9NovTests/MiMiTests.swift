import Testing
@testable import IOSLAB_9Nov

@MainActor
struct MiMiTests {
    @Test func entiendeLasPreguntasDelDemo() {
        #expect(IntencionMiMi.entender("MiMi, ¿hoy tengo que tomar medicina?") == .hoy)
        #expect(IntencionMiMi.entender("Quiero ir a mi calendario") == .ir(.calendario))
        #expect(IntencionMiMi.entender("Quiero agregar una receta") == .agregarReceta)
        #expect(IntencionMiMi.entender("Agregar la caja de mi medicina") == .agregarCaja)
        #expect(IntencionMiMi.entender("Quiero agregar un medicamento") == .ir(.escanear))
        #expect(IntencionMiMi.entender("¿Qué hago aquí?") == .queHago)
        #expect(IntencionMiMi.entender("¿Qué medicinas tengo?") == .misMedicinas)
        #expect(IntencionMiMi.entender("Llévame a mi perfil") == .ir(.perfil))
    }

    @Test func yaMeTomeConservaLaFrase() {
        guard case .yaTome(let frase) = IntencionMiMi.entender("¿Ya me tomé la de la PRESIÓN?") else {
            Issue.record("No entendió 'ya me tomé'")
            return
        }
        #expect(frase.contains("presion"))
    }

    @Test func loQueNoEntiendeNoSeAdivina() {
        #expect(IntencionMiMi.entender("") == .desconocida)
        #expect(IntencionMiMi.entender("cuéntame un chiste") == .desconocida)
    }
}

@MainActor
struct DictadoRecetaTests {
    @Test func dosisMomentosYDias() {
        let r = DictadoReceta.leer("Una tableta con el desayuno y la cena por siete días")
        #expect(r.dosis == "1 tableta")
        #expect(r.momentos == [.desayuno, .cena])
        #expect(r.dias == 7)
    }

    @Test func cadaHorasYPrimeraVez() {
        let r = DictadoReceta.leer("Media pastilla cada 8 horas, empiezo a las 8 de la noche, por una semana")
        #expect(r.dosis == "½ pastilla")
        #expect(r.cadaHoras == 8)
        #expect(r.hora == DateComponents(hour: 20, minute: 0))
        #expect(r.dias == 7)
        #expect(r.momentos.isEmpty)
    }

    @Test func siempreYNadaInventado() {
        #expect(DictadoReceta.leer("dos cápsulas para siempre").siempre)
        #expect(DictadoReceta.leer("dos cápsulas para siempre").dosis == "2 cápsulas")
        #expect(DictadoReceta.leer("hola mimi") == DictadoReceta.Resultado())
    }
}
