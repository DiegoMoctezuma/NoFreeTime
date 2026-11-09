import Foundation
import SwiftData

/// Un medicamento del tratamiento confirmado por la persona (A5).
@Model
final class Medicamento {
    @Attribute(.unique) var id: UUID
    var nombre: String
    var concentracion: String?
    var apodo: String?
    var colorHex: String
    @Attribute(.externalStorage) var fotoCaja: Data?
    var pastillasPorCaja: Int?
    var dosis: String
    /// Persistido como texto; usa `momentos`.
    var momentosCodigos: [String]
    var cadaHoras: Int?
    var duracionDias: Int?
    var inicio: Date
    var indicaciones: String?
    /// Persistido como texto; usa `aviso`.
    var avisoRaw: String
    var activo: Bool

    init(id: UUID = UUID(),
         nombre: String,
         concentracion: String? = nil,
         apodo: String? = nil,
         colorHex: String = Paleta.medicamentos[0],
         fotoCaja: Data? = nil,
         pastillasPorCaja: Int? = nil,
         dosis: String,
         momentos: [Momento],
         cadaHoras: Int? = nil,
         duracionDias: Int? = nil,
         inicio: Date = .now,
         indicaciones: String? = nil,
         aviso: TipoAviso = .alarma,
         activo: Bool = true) {
        self.id = id
        self.nombre = nombre
        self.concentracion = concentracion
        self.apodo = apodo
        self.colorHex = colorHex
        self.fotoCaja = fotoCaja
        self.pastillasPorCaja = pastillasPorCaja
        self.dosis = dosis
        self.momentosCodigos = momentos.map(\.codigo)
        self.cadaHoras = cadaHoras
        self.duracionDias = duracionDias
        self.inicio = inicio
        self.indicaciones = indicaciones
        self.avisoRaw = aviso.rawValue
        self.activo = activo
    }

    var momentos: [Momento] {
        get { momentosCodigos.compactMap(Momento.init(codigo:)) }
        set { momentosCodigos = newValue.map(\.codigo) }
    }

    var aviso: TipoAviso {
        get { TipoAviso(rawValue: avisoRaw) ?? .ninguno }
        set { avisoRaw = newValue.rawValue }
    }

    /// Lo que ve la persona: el apodo si lo tiene ("la de la presión").
    var nombreVisible: String { apodo ?? nombre }

    /// "Losartán 50 mg"
    var nombreTecnico: String {
        [nombre, concentracion].compactMap { $0 }.joined(separator: " ")
    }

    /// Último día (exclusivo) del tratamiento, si tiene duración.
    var fin: Date? {
        guard let duracionDias else { return nil }
        let cal = Calendar.current
        return cal.date(byAdding: .day, value: duracionDias, to: cal.startOfDay(for: inicio))
    }
}
