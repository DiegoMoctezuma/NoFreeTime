import Foundation

nonisolated enum CanalConfianza: String, CaseIterable, Sendable {
    case mensajes, whatsapp

    var titulo: String { self == .mensajes ? "Mensajes" : "WhatsApp" }
}

nonisolated struct ContactoConfianza: Equatable, Sendable {
    enum Fallo: LocalizedError {
        case nombre, telefono
        var errorDescription: String? {
            switch self {
            case .nombre: "Escribe un nombre de hasta 60 letras, en una sola línea."
            case .telefono: "Incluye + y el código de país, por ejemplo +52 55 1234 5678."
            }
        }
    }
    let nombre: String
    let telefono: String
    let canal: CanalConfianza

    init(nombre: String, telefono: String, canal: CanalConfianza) throws {
        let limpio = nombre.trimmingCharacters(in: .whitespaces)
        guard !limpio.isEmpty, limpio.count <= 60,
              !limpio.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) || CharacterSet.newlines.contains($0) })
        else { throw Fallo.nombre }
        // Permitir solamente dígitos ASCII y separadores visuales conocidos; no extensiones ni URLs.
        let permitido = CharacterSet(charactersIn: "+0123456789 ()-")
        guard telefono.unicodeScalars.allSatisfy({ permitido.contains($0) }) else { throw Fallo.telefono }
        let numero = telefono.filter { !" ()-".contains($0) }
        let digitos = numero.dropFirst()
        guard numero.first == "+", (8...15).contains(digitos.count),
              digitos.first != "0", digitos.allSatisfy({ $0 >= "0" && $0 <= "9" })
        else { throw Fallo.telefono }
        self.nombre = limpio
        self.telefono = numero
        self.canal = canal
    }

    var urlLlamada: URL { URL(string: "tel:\(telefono)")! }

    /// Solo se abre tras revisar el mensaje y tocar «Abrir WhatsApp». No envía por sí misma.
    func urlWhatsApp(texto: String) -> URL? {
        var partes = URLComponents()
        partes.scheme = "https"
        partes.host = "wa.me"
        partes.path = "/\(telefono.dropFirst())"
        partes.queryItems = [URLQueryItem(name: "text", value: texto)]
        return partes.url
    }
}
