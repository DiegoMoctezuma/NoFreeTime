import Foundation
import SwiftData

enum TipoAccionPlan: String, CaseIterable {
    case toma, aplicacion, cuidado

    var titulo: String {
        switch self {
        case .toma: "Toma"
        case .aplicacion: "Aplicación"
        case .cuidado: "Cuidado"
        }
    }

    var icono: String {
        switch self {
        case .toma: "pills"
        case .aplicacion: "hand.raised"
        case .cuidado: "checklist"
        }
    }

    var accionRegistro: String {
        switch self {
        case .toma: "Ya me la tomé"
        case .aplicacion: "Ya me la apliqué"
        case .cuidado: "Ya lo hice"
        }
    }

    var preguntaRegistro: String {
        switch self {
        case .toma: "¿Te la tomaste?"
        case .aplicacion: "¿Te la aplicaste?"
        case .cuidado: "¿Ya lo hiciste?"
        }
    }

    var estadoRegistrado: String {
        switch self {
        case .toma: "Tomada"
        case .aplicacion: "Aplicada"
        case .cuidado: "Realizado"
        }
    }
}

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
    var aplicacion: Bool?
    var tipoAccionRaw: String?
    /// Persistido como texto; usa `momentos`.
    var momentosCodigos: [String]
    var cadaHoras: Int?
    /// Primera toma confirmada para una pauta por intervalo. Las altas anteriores conservan sus momentos.
    var inicioIntervalo: Date?
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
         aplicacion: Bool? = nil,
         tipoAccion: TipoAccionPlan? = nil,
         momentos: [Momento],
         cadaHoras: Int? = nil,
         inicioIntervalo: Date? = nil,
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
        self.aplicacion = aplicacion
        self.tipoAccionRaw = tipoAccion?.rawValue
        self.momentosCodigos = momentos.map(\.codigo)
        self.cadaHoras = cadaHoras
        self.inicioIntervalo = inicioIntervalo
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

    var tipoAccion: TipoAccionPlan {
        tipoAccionRaw.flatMap(TipoAccionPlan.init(rawValue:)) ?? (aplicacion == true ? .aplicacion : .toma)
    }

    var accionRegistro: String { tipoAccion.accionRegistro }
    var preguntaRegistro: String { tipoAccion.preguntaRegistro }

    var textoPauta: String {
        if inicioIntervalo != nil, let cadaHoras {
            return cadaHoras == 1 ? "cada hora" : "cada \(cadaHoras) horas"
        }
        return momentos.map(\.nombre).formatted(.list(type: .and).locale(Locale(identifier: "es_MX")))
    }

    /// "Losartán 50 mg"
    var nombreTecnico: String {
        [nombre, concentracion].compactMap { $0 }.joined(separator: " ")
    }

    /// Último día (exclusivo) del tratamiento, si tiene duración.
    var fin: Date? {
        guard let duracionDias else { return nil }
        let cal = Calendar.current
        return cal.date(byAdding: .day, value: duracionDias, to: inicioIntervalo ?? cal.startOfDay(for: inicio))
    }
}
