import AppIntents

/// Se ejecuta cuando la persona detiene la alarma sin tocar "Ya me la tomé":
/// la alarma se repite 10 min después (máximo 2 veces, RF-06). Detener no cuenta como toma.
struct RepetirTomaIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Recordar otra vez"
    static let isDiscoverable = false

    @Parameter(title: "Toma") var idToma: String
    @Parameter(title: "Repetición") var repeticion: Int

    init() {}

    init(idToma: String, repeticion: Int) {
        self.idToma = idToma
        self.repeticion = repeticion
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        await ServicioAvisosSistema.compartido.repetirAlarmaSiFalta(idToma: idToma, repeticion: repeticion)
        return .result()
    }
}
