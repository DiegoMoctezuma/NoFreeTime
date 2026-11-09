import Foundation

/// Contrato de avisos (CONTRATOS §5). Lo implementa WP-02 en `Avisos/`.
enum Permiso: Sendable { case concedido, negado, sinPedir }

struct EstadoPermisos: Sendable {
    var alarmas: Permiso
    var notificaciones: Permiso
}

protocol ServicioAvisos {
    /// Programa los avisos de las tomas con identificador estable (no duplica al repetir).
    func programar(_ med: Medicamento, tomas: [TomaProgramada]) async throws
    func cancelar(medicamentoID: UUID) async
    /// Cancela las repeticiones (+10 y +20 min) de una toma ya registrada.
    func cancelarRepeticiones(idToma: String) async
    func estadoPermisos() async -> EstadoPermisos
    func pedirPermiso(para tipo: TipoAviso) async -> Permiso
}
