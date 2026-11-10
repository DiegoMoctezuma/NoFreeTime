import Foundation
import Testing
@testable import IOSLAB_9Nov

/// El código comprueba que lo que propone el modelo está escrito en la foto (HCAI).
@MainActor
struct VerificacionTests {
    let receta = """
        Dr. Juan Pérez · Ced. 1234567
        Losartán 50 mg
        Tomar 1 tab c/24h x 30 días
        Metformina 850mg 1 tab desayuno y cena
        """

    @Test func nombreYConcentracionPresentesNoSonDudosos() {
        let p = IndicacionPropuesta(nombre: "Losartán", concentracion: "50 mg", dosis: "1 tableta",
                                    cadaHoras: 24, duracionDias: 30)
        #expect(MapeoIndicacion.noEncontrados(p, en: receta).isEmpty)
    }

    @Test func toleraUnaLetraMalLeida() {
        #expect(MapeoIndicacion.aparece("Metformina", en: "Metfornina 850mg"))
    }

    @Test func datoInventadoQuedaDudoso() {
        let p = IndicacionPropuesta(nombre: "Atorvastatina", concentracion: "20 mg", cadaHoras: 8, duracionDias: 10)
        let d = MapeoIndicacion.noEncontrados(p, en: receta)
        #expect(d == ["nombre", "concentracion", "cadaHoras", "duracionDias"])
    }

    @Test func sinTextoNoSeMarcaNada() {
        let p = IndicacionPropuesta(nombre: "Losartán")
        #expect(MapeoIndicacion.noEncontrados(p, en: "").isEmpty)
    }

    @Test func renglonFuenteIncluyeLaIndicacion() {
        let r = MapeoIndicacion.renglon(de: "Losartán", en: receta)
        #expect(r == "Losartán 50 mg Tomar 1 tab c/24h x 30 días")
    }

    @Test func nombreDeLaEntrevistaSinFrases() {
        #expect(LectorEntrevista.heuristica("me llamo ernesto") == "Ernesto")
        #expect(LectorEntrevista.heuristica("Soy doña Lupe.") == "Doña Lupe")
    }

    @Test func rutinaAdmiteDormirDespuesDeMedianoche() {
        let rutina = RutinaDicha(desayuno: "08:00", cena: "20:00", dormir: "00:30")
        #expect(LectorEntrevista.horas(de: rutina) == [.desayuno: 480, .cena: 1200, .dormir: 30])
    }

    @Test func rutinaHabladaConMuletillasYCorrecciones() {
        let texto = "Pues desayuno como a las ocho, eh, como a las tres. Ceno a las ocho y media. Me duermo a las 7, ah no, a las 9."
        #expect(LectorEntrevista.horasClaras(de: texto) == [.desayuno: 480, .comida: 900, .cena: 1230, .dormir: 1260])
        #expect(LectorEntrevista.horasClaras(de: "Me duermo a las siete… ah no, nueve")[.dormir] == 1260)
    }

    @Test func rutinaHabladaRespetaHorasExplicitasYOmiteAlternativas() {
        let texto = "Desayuno a las once de la noche. Como a las dos o tres. Ceno a las seis de la mañana y me acuesto a las doce de la noche."
        #expect(LectorEntrevista.horasClaras(de: texto) == [.desayuno: 1380, .cena: 360, .dormir: 0])
        #expect(LectorEntrevista.horas(de: RutinaDicha(desayuno: "23:00", cena: "06:00")) == [.desayuno: 1380, .cena: 360])
    }

    @Test func rutinaHabladaNoConservaUnaHoraRechazada() {
        #expect(LectorEntrevista.horasClaras(de: "Me duermo a las siete, ah no.").isEmpty)
        #expect(LectorEntrevista.horasClaras(de: "No desayuno a las ocho.").isEmpty)
    }

    @Test func dosisVaciaNoSeCompletaEnLaPropuesta() {
        let b = Borrador(nombre: "Ejemplo", dosis: "", momentos: [.desayuno], dudosos: ["dosis"])
        #expect(b.bloqueado)
        #expect(b.medicamento(colorHex: "#000000").dosis.isEmpty)
    }

    @Test func lavadoConPautaSeAgendaSinInventarCantidad() {
        let lavado = IndicacionPropuesta(nombre: "Lavados nasales", momentos: [.dormir], cuidado: true)
        let resultado = LectorIA.separarCuidados([lavado], notas: ["Evitar bebidas azucaradas"],
                                                texto: "Lavados nasales al dormir\n• Evitar bebidas azucaradas")
        #expect(resultado.programables == [lavado])
        #expect(resultado.notas == ["Evitar bebidas azucaradas"])
        #expect(MapeoIndicacion.dudosos(de: lavado).isEmpty)
        let cuidado = MapeoIndicacion.medicamento(de: lavado, inicio: .now)
        #expect(cuidado.dosis.isEmpty)
        #expect(cuidado.tipoAccion == .cuidado)
        #expect(cuidado.accionRegistro == "Ya lo hice")
    }

    @Test func pautaCondicionalOSemanalSeGuardaComoNota() {
        let lavado = IndicacionPropuesta(nombre: "Lavados nasales", momentos: [.dormir], cuidado: true)
        let curacion = IndicacionPropuesta(nombre: "Curación", momentos: [.desayuno], cuidado: true)
        let resultado = LectorIA.separarCuidados(
            [lavado, curacion], notas: [], texto: "Lavados nasales al dormir si hay congestión\nCuración los lunes"
        )
        #expect(resultado.programables.isEmpty)
        #expect(resultado.notas == ["Lavados nasales al dormir si hay congestión", "Curación los lunes"])
    }

    @Test func recetaDeSoloNotasConservaLaNegacion() {
        let resultado = LectorIA.separarCuidados([], notas: ["Comer alimentos picantes", "No comer alimentos picantes"],
                                                texto: "No comer alimentos picantes")
        #expect(resultado.programables.isEmpty)
        #expect(resultado.notas == ["No comer alimentos picantes"])
    }

    @Test func aplicacionGuardadaAntesConservaSuAccion() {
        let crema = Medicamento(nombre: "Crema", dosis: "Capa delgada", aplicacion: true, momentos: [.dormir])
        #expect(crema.tipoAccion == .aplicacion)
        #expect(crema.accionRegistro == "Ya me la apliqué")
    }

    @Test func humectanteConRangoSeRecuperaSinInventarDosisNiElegirHoras() throws {
        let linea = "Aplicar humectante cada 2–3 hrs por 5 días"
        let resultado = LectorIA.separarCuidados([], notas: [linea], texto: linea)
        let propuesta = try #require(resultado.programables.first)
        #expect(resultado.notas.isEmpty)
        #expect(propuesta.nombre == "humectante")
        #expect(propuesta.duracionDias == 5)
        #expect(propuesta.dosis == nil)
        #expect(propuesta.cadaHoras == nil)
        #expect(MapeoIndicacion.rangoHoras(de: propuesta) == 2...3)
        #expect(MapeoIndicacion.dudosos(de: propuesta).isEmpty)
        #expect(MapeoIndicacion.noEncontrados(propuesta, en: linea).isEmpty)

        let revisada = IndicacionRevisada(propuesta: propuesta, yaRegistrado: false, fuente: linea)
        let borrador = Borrador(revisada: revisada)
        #expect(borrador.faltaElegirIntervalo)
        #expect(borrador.bloqueado)
    }

    @Test func rangoDeLaRecetaCorrigeIntervaloFijoDelModelo() throws {
        let propuesta = IndicacionPropuesta(nombre: "Humectante", cadaHoras: 2)
        let resultado = LectorIA.separarCuidados([propuesta], notas: [],
                                                texto: "Aplicar humectante\ncada 2 a 3 h")
        let leida = try #require(resultado.programables.first)
        #expect(resultado.programables.count == 1)
        #expect(MapeoIndicacion.tipoAccion(de: leida) == .aplicacion)
        #expect(MapeoIndicacion.rangoHoras(de: leida) == 2...3)
        #expect(leida.cadaHoras == nil)
    }

    @Test func rangoCondicionalNoSeAgenda() {
        let texto = "Aplicar humectante cada 2-3 hrs si hay resequedad"
        let resultado = LectorIA.separarCuidados([], notas: [texto], texto: texto)
        #expect(resultado.programables.isEmpty)
        #expect(resultado.notas == [texto])
    }
}
