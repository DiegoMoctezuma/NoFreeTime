import Foundation

nonisolated struct ActividadConfianza: Sendable {
    enum Estado: Sendable { case confirmada, omitida, sinRegistro }
    let id: String
    let fecha: Date
    let estado: Estado
}

nonisolated struct ResumenConfianza: Sendable {
    private(set) var confirmadas = 0
    private(set) var omitidas = 0
    private(set) var sinConfirmar = 0
    private(set) var pendientes = 0
    var total: Int { confirmadas + omitidas + sinConfirmar + pendientes }
    var todoConfirmado: Bool { total > 0 && confirmadas == total }

    init(tomas: [ActividadConfianza], ahora: Date) {
        var vistos: Set<String> = []
        for toma in tomas where vistos.insert(toma.id).inserted {
            switch toma.estado {
            case .confirmada: confirmadas += 1
            case .omitida: omitidas += 1
            case .sinRegistro:
                // Treinta minutos es un margen de presentación, no una recomendación médica.
                if ahora >= toma.fecha.addingTimeInterval(30 * 60) { sinConfirmar += 1 }
                else { pendientes += 1 }
            }
        }
    }

    /// Resumen deliberadamente mínimo: sin nombres de medicinas, dosis, fotos ni diagnósticos.
    func mensaje(nombre: String, fecha: Date) -> String {
        let limpio = String(nombre.unicodeScalars.filter { !CharacterSet.controlCharacters.contains($0) && !CharacterSet.newlines.contains($0) })
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let persona = limpio.isEmpty ? "La persona que usa MiMi" : String(limpio.prefix(60))
        let dia = fecha.formatted(.dateTime.day().month(.wide).year().locale(Locale(identifier: "es_MX")))
        let encabezado = "MiMi · \(dia)\n"
        if total == 0 { return encabezado + "Sin actividades programadas para hoy." }
        if todoConfirmado { return encabezado + "\(persona) confirmó todas sus actividades de hoy (\(confirmadas) de \(total))." }
        return encabezado + "\(persona): \(confirmadas) de \(total) actividades confirmadas.\n"
            + "\(omitidas) marcadas como omitidas · \(sinConfirmar) sin confirmar después de 30 min · \(pendientes) pendientes o aún en su margen.\n"
            + "Sin confirmar no significa que no se haya realizado la actividad."
    }
}
