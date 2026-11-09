import Foundation
import SwiftData

/// Nombre y rutina de la persona (RF-01). Las horas se guardan en minutos desde medianoche.
@Model
final class Perfil {
    var nombre: String
    var desayunoMin: Int
    var comidaMin: Int
    var cenaMin: Int
    var dormirMin: Int
    /// Marca los datos de ejemplo ("Datos de ejemplo" en Ajustes).
    var esDemo: Bool

    init(nombre: String,
         desayunoMin: Int = Perfil.sugerido.desayuno,
         comidaMin: Int = Perfil.sugerido.comida,
         cenaMin: Int = Perfil.sugerido.cena,
         dormirMin: Int = Perfil.sugerido.dormir,
         esDemo: Bool = false) {
        self.nombre = nombre
        self.desayunoMin = desayunoMin
        self.comidaMin = comidaMin
        self.cenaMin = cenaMin
        self.dormirMin = dormirMin
        self.esDemo = esDemo
    }

    /// Valores sugeridos: 8:00, 14:00, 20:00, 22:00.
    static let sugerido = (desayuno: 8 * 60, comida: 14 * 60, cena: 20 * 60, dormir: 22 * 60)

    var desayuno: DateComponents {
        get { Perfil.componentes(desayunoMin) }
        set { desayunoMin = Perfil.minutos(newValue) }
    }
    var comida: DateComponents {
        get { Perfil.componentes(comidaMin) }
        set { comidaMin = Perfil.minutos(newValue) }
    }
    var cena: DateComponents {
        get { Perfil.componentes(cenaMin) }
        set { cenaMin = Perfil.minutos(newValue) }
    }
    var dormir: DateComponents {
        get { Perfil.componentes(dormirMin) }
        set { dormirMin = Perfil.minutos(newValue) }
    }

    /// Hora (hora y minuto) de un momento según esta rutina.
    func hora(de momento: Momento) -> DateComponents {
        switch momento {
        case .desayuno: desayuno
        case .comida: comida
        case .cena: cena
        case .dormir: dormir
        case .horaFija(let c): DateComponents(hour: c.hour ?? 0, minute: c.minute ?? 0)
        }
    }

    nonisolated static func componentes(_ minutos: Int) -> DateComponents {
        DateComponents(hour: minutos / 60, minute: minutos % 60)
    }

    nonisolated static func minutos(_ c: DateComponents) -> Int {
        (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }
}
