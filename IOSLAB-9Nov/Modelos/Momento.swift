import Foundation

/// Momento del día en que se toma un medicamento (CONTRATOS §1).
/// Se persiste como texto (`codigo`) para que SwiftData no tenga que guardar valores asociados.
nonisolated enum Momento: Codable, Hashable, Sendable {
    case desayuno, comida, cena, dormir
    case horaFija(DateComponents)

    /// "desayuno" | "comida" | "cena" | "dormir" | "hora:HH:mm"
    var codigo: String {
        switch self {
        case .desayuno: "desayuno"
        case .comida: "comida"
        case .cena: "cena"
        case .dormir: "dormir"
        case .horaFija(let c):
            String(format: "hora:%02d:%02d", c.hour ?? 0, c.minute ?? 0)
        }
    }

    init?(codigo: String) {
        switch codigo {
        case "desayuno": self = .desayuno
        case "comida": self = .comida
        case "cena": self = .cena
        case "dormir": self = .dormir
        default:
            guard codigo.hasPrefix("hora:"),
                  let c = Momento.componentes(deHora: String(codigo.dropFirst(5))) else { return nil }
            self = .horaFija(c)
        }
    }

    /// "07:00" o "7:30" → DateComponents(hour:minute:)
    static func componentes(deHora texto: String) -> DateComponents? {
        let partes = texto.trimmingCharacters(in: .whitespaces).split(separator: ":")
        guard partes.count == 2, let h = Int(partes[0]), let m = Int(partes[1]),
              (0..<24).contains(h), (0..<60).contains(m) else { return nil }
        return DateComponents(hour: h, minute: m)
    }

    /// Texto para la persona: "con el desayuno", "a las 7:00".
    var texto: String {
        switch self {
        case .desayuno: "con el desayuno"
        case .comida: "con la comida"
        case .cena: "con la cena"
        case .dormir: "al dormir"
        case .horaFija(let c): String(format: "a las %d:%02d", c.hour ?? 0, c.minute ?? 0)
        }
    }

    /// Nombre corto para botones: "Desayuno".
    var nombre: String {
        switch self {
        case .desayuno: "Desayuno"
        case .comida: "Comida"
        case .cena: "Cena"
        case .dormir: "Al dormir"
        case .horaFija(let c): String(format: "%d:%02d", c.hour ?? 0, c.minute ?? 0)
        }
    }

    static let rutina: [Momento] = [.desayuno, .comida, .cena, .dormir]

    // Codable por `codigo` para que el formato guardado sea estable.
    init(from decoder: Decoder) throws {
        let s = try decoder.singleValueContainer().decode(String.self)
        guard let m = Momento(codigo: s) else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Momento inválido: \(s)"))
        }
        self = m
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(codigo)
    }
}

/// Franja para agrupar Tu día.
nonisolated enum Franja: String, CaseIterable, Sendable {
    case manana, tarde, noche

    var titulo: String {
        switch self {
        case .manana: "Mañana"
        case .tarde: "Tarde"
        case .noche: "Noche"
        }
    }

    /// Antes de las 12:00 mañana; antes de las 19:00 tarde; después, noche.
    static func de(hora: Int) -> Franja {
        if hora < 12 { return .manana }
        if hora < 19 { return .tarde }
        return .noche
    }
}

nonisolated enum TipoAviso: String, Codable, CaseIterable, Sendable {
    case alarma, recordatorio, ninguno

    var titulo: String {
        switch self {
        case .alarma: "Alarma"
        case .recordatorio: "Recordatorio"
        case .ninguno: "Sin aviso"
        }
    }
}

nonisolated enum EstadoToma: String, Codable, Sendable {
    case tomada, sePaso
}
