import SwiftUI

/// Un solo ritmo para MiMi: respuesta rápida al tacto y entradas que descansan suavemente.
enum MovimientoMiMi {
    static let respuesta = Animation.spring(response: 0.28, dampingFraction: 0.82)
    static let cambio = Animation.spring(response: 0.44, dampingFraction: 0.9)
    static let entrada = Animation.spring(response: 0.58, dampingFraction: 0.88)

    static func pagina(adelante: Bool, reducir: Bool) -> AnyTransition {
        guard !reducir else { return .opacity }
        return .asymmetric(
            insertion: .offset(x: adelante ? 28 : -28).combined(with: .opacity),
            removal: .offset(x: adelante ? -16 : 16).combined(with: .opacity))
    }
}

private struct EntradaMiMi: ViewModifier {
    var orden: Int
    @Environment(\.accessibilityReduceMotion) private var reducir
    @State private var visible = false

    func body(content: Content) -> some View {
        content
            // El contenido siempre es legible y accesible, incluso antes de la entrada.
            .opacity(visible || reducir ? 1 : 0.72)
            .offset(y: visible || reducir ? 0 : 14)
            .task {
                guard !visible else { return }
                if reducir { visible = true; return }
                do {
                    try await Task.sleep(for: .milliseconds(min(max(orden, 0), 5) * 45))
                    try Task.checkCancellation()
                    withAnimation(MovimientoMiMi.entrada) { visible = true }
                } catch { /* Una vista que salió no inicia una animación pendiente. */ }
            }
    }
}

private struct CambioMiMi<Valor: Equatable>: ViewModifier {
    let valor: Valor
    @Environment(\.accessibilityReduceMotion) private var reducir

    func body(content: Content) -> some View {
        content.animation(reducir ? nil : MovimientoMiMi.cambio, value: valor)
    }
}

extension View {
    func entradaMiMi(orden: Int = 0) -> some View { modifier(EntradaMiMi(orden: orden)) }
    func cambioMiMi<V: Equatable>(_ valor: V) -> some View { modifier(CambioMiMi(valor: valor)) }
}
