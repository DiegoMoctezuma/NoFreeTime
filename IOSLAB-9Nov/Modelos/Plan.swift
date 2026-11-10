import Foundation

/// Una toma calculada a partir del plan; no se persiste (A5).
nonisolated struct TomaProgramada: Identifiable, Hashable, Sendable {
    /// Las pautas por intervalo usan UTC, para distinguir horas locales repetidas.
    let id: String
    let medicamentoID: UUID
    let fecha: Date
    let momento: Momento

    init(medicamentoID: UUID, fecha: Date, momento: Momento, enIntervalo: Bool = false) {
        self.id = TomaProgramada.id(medicamentoID: medicamentoID, fecha: fecha, enIntervalo: enIntervalo)
        self.medicamentoID = medicamentoID
        self.fecha = fecha
        self.momento = momento
    }

    static func id(medicamentoID: UUID, fecha: Date, enIntervalo: Bool = false) -> String {
        let formato = enIntervalo ? formatoIDUTC : formatoID
        return "\(medicamentoID.uuidString)-\(formato.string(from: fecha))"
    }

    /// Fecha programada de un id, o nil si no tiene el formato.
    static func partes(de idToma: String) -> (medicamentoID: UUID, fecha: Date)? {
        // UUID (36) + "-" + yyyyMMdd (8) + "-" + HHmm (4) = 50
        let enUTC = idToma.hasSuffix("Z")
        let longitudFecha = enUTC ? 14 : 13
        guard idToma.count == 37 + longitudFecha else { return nil }
        let uuidTexto = String(idToma.prefix(36))
        let fechaTexto = String(idToma.suffix(longitudFecha))
        let formato = enUTC ? formatoIDUTC : formatoID
        guard let uuid = UUID(uuidString: uuidTexto), let fecha = formato.date(from: fechaTexto) else { return nil }
        return (uuid, fecha)
    }

    var franja: Franja {
        Franja.de(hora: Calendar.current.component(.hour, from: fecha))
    }

    private static let formatoID = formato(zona: .autoupdatingCurrent, patron: "yyyyMMdd-HHmm")
    private static let formatoIDUTC = formato(zona: .gmt, patron: "yyyyMMdd-HHmm'Z'")

    private static func formato(zona: TimeZone, patron: String) -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = Calendar(identifier: .gregorian)
        f.timeZone = zona
        f.dateFormat = patron
        return f
    }
}

enum Plan {
    /// Tomas de un medicamento activo desde el inicio del día de `desde` durante `dias` días.
    /// Respeta `inicio` y `duracionDias` (RF-04 "Fin").
    static func tomas(de med: Medicamento, perfil: Perfil, desde: Date, dias: Int) -> [TomaProgramada] {
        guard med.activo, dias > 0 else { return [] }
        let cal = Calendar.current
        let primerDia = cal.startOfDay(for: desde)
        if let primeraToma = med.inicioIntervalo, let horas = med.cadaHoras, horas > 0,
           let finVentana = cal.date(byAdding: .day, value: dias, to: primerDia) {
            let intervalo = TimeInterval(horas) * 3600
            let saltos = max(0, ceil(primerDia.timeIntervalSince(primeraToma) / intervalo))
            var fecha = primeraToma.addingTimeInterval(saltos * intervalo)
            let limite = min(finVentana, med.fin ?? finVentana)
            var tomas: [TomaProgramada] = []
            while fecha < limite {
                let hora = cal.dateComponents([.hour, .minute], from: fecha)
                tomas.append(TomaProgramada(medicamentoID: med.id, fecha: fecha, momento: .horaFija(hora), enIntervalo: true))
                fecha = fecha.addingTimeInterval(intervalo)
            }
            return tomas
        }
        let inicio = cal.startOfDay(for: med.inicio)
        let fin = med.fin
        var resultado: [TomaProgramada] = []
        for d in 0..<dias {
            guard let dia = cal.date(byAdding: .day, value: d, to: primerDia) else { continue }
            if dia < inicio { continue }
            if let fin, dia >= fin { break }
            for momento in med.momentos {
                let h = perfil.hora(de: momento)
                guard let fecha = cal.date(bySettingHour: h.hour ?? 0, minute: h.minute ?? 0, second: 0, of: dia) else { continue }
                resultado.append(TomaProgramada(medicamentoID: med.id, fecha: fecha, momento: momento))
            }
        }
        // Dos momentos a la misma hora darían el mismo id: se deja una sola toma.
        var vistos = Set<String>()
        return resultado.filter { vistos.insert($0.id).inserted }.sorted { $0.fecha < $1.fecha }
    }

    /// Todas las tomas de hoy de los medicamentos activos, ordenadas por hora.
    static func tomasDeHoy(_ meds: [Medicamento], perfil: Perfil, ahora: Date = .now) -> [TomaProgramada] {
        meds.flatMap { tomas(de: $0, perfil: perfil, desde: ahora, dias: 1) }
            .sorted { $0.fecha < $1.fecha }
    }

    /// ¿El tratamiento ya terminó? (deja de aparecer y se cancelan sus avisos).
    static func termino(_ med: Medicamento, ahora: Date = .now) -> Bool {
        guard let fin = med.fin else { return false }
        return ahora >= fin
    }
}
