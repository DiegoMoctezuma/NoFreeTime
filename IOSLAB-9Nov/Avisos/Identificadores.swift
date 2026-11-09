import Foundation
import CryptoKit

/// Identificadores estables de avisos (CONTRATOS §5): reprogramar nunca duplica.
nonisolated enum Identificadores {
    /// Notificación base y repeticiones (+10 y +20 min).
    static func notificacion(idToma: String, repeticion: Int = 0) -> String {
        repeticion == 0 ? idToma : "\(idToma)-r\(repeticion)"
    }

    /// UUID determinista para AlarmKit a partir del id de la toma y la repetición.
    static func alarma(idToma: String, repeticion: Int = 0) -> UUID {
        uuid(de: notificacion(idToma: idToma, repeticion: repeticion))
    }

    /// SHA-256 → 16 bytes con versión 5 y variante RFC 4122.
    static func uuid(de texto: String) -> UUID {
        var b = Array(SHA256.hash(data: Data(texto.utf8)).prefix(16))
        b[6] = (b[6] & 0x0F) | 0x50
        b[8] = (b[8] & 0x3F) | 0x80
        return UUID(uuid: (b[0], b[1], b[2], b[3], b[4], b[5], b[6], b[7],
                           b[8], b[9], b[10], b[11], b[12], b[13], b[14], b[15]))
    }

    /// Repeticiones si la persona no confirma (RF-06): máximo 2, cada 10 min.
    static let maxRepeticiones = 2
    static let minutosEntreRepeticiones = 10

    static let categoriaToma = "TOMA"
    static let accionYaMeLaTome = "YA_ME_LA_TOME"
}
