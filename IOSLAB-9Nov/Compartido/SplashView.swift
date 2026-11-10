import SwiftUI

/// Splash de MiMi (diseño "Splash 2a — Expansión invertida", 2.7 s, sin texto).
/// 0.00–0.60 s el círculo aparece · 0.30–1.15 s se dibuja la "m" · 0.95/1.05 s los puntos ·
/// 1.65 s la marca se desvanece · 1.80–2.70 s el círculo crece hasta cubrir la pantalla y aparece la app.
/// Con "Reducir movimiento" solo se muestra el logo un momento y se desvanece.
struct SplashView: View {
    let alTerminar: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reducir
    @State private var escalaCirculo: CGFloat = 0
    @State private var trazo1: CGFloat = 0
    @State private var trazo2: CGFloat = 0
    @State private var punto1: CGFloat = 0
    @State private var punto2: CGFloat = 0
    @State private var opacidadMarca: Double = 1
    @State private var opacidadTodo: Double = 1

    private static let fondo = Color(hex: "#B4DCE6")
    private static let circulo = Color(hex: "#FAF9F5")
    private static let tinta = Color(hex: "#1C1E1E")
    private static let puntos = Color(hex: "#F0675A")
    private let lado: CGFloat = 120

    var body: some View {
        ZStack {
            Self.fondo.ignoresSafeArea()
            ZStack {
                Circle()
                    .fill(Self.circulo)
                    .frame(width: lado, height: lado)
                    .scaleEffect(escalaCirculo)
                ZStack {
                    TrazoM(parte: 1)
                        .trim(from: 0, to: trazo1)
                        .stroke(Self.tinta, style: StrokeStyle(lineWidth: lado * 0.132, lineCap: .round, lineJoin: .round))
                    TrazoM(parte: 2)
                        .trim(from: 0, to: trazo2)
                        .stroke(Self.tinta, style: StrokeStyle(lineWidth: lado * 0.132, lineCap: .round, lineJoin: .round))
                    punto(x: 29.3, y: 22.9, escala: punto1)
                    punto(x: 71.4, y: 23.1, escala: punto2)
                }
                .frame(width: lado, height: lado)
                .opacity(opacidadMarca)
            }
        }
        .opacity(opacidadTodo)
        .accessibilityHidden(true)
        .allowsHitTesting(false)
        .task { await animar() }
    }

    private func punto(x: CGFloat, y: CGFloat, escala: CGFloat) -> some View {
        Circle()
            .fill(Self.puntos)
            .frame(width: lado * 0.158, height: lado * 0.158)
            .scaleEffect(escala)
            .position(x: lado * x / 100, y: lado * y / 100)
    }

    private func esperar(_ segundos: Double) async {
        try? await Task.sleep(for: .milliseconds(Int(segundos * 1000)))
    }

    private func animar() async {
        if reducir {
            escalaCirculo = 1; trazo1 = 1; trazo2 = 1; punto1 = 1; punto2 = 1
            await esperar(0.8)
            withAnimation(.easeOut(duration: 0.3)) { opacidadTodo = 0 }
            await esperar(0.3)
            alTerminar()
            return
        }
        // Círculo: 0 → 1.08 → 1
        withAnimation(.timingCurve(0.22, 1, 0.36, 1, duration: 0.36)) { escalaCirculo = 1.08 }
        Task {
            await esperar(0.36)
            withAnimation(.easeOut(duration: 0.24)) { escalaCirculo = 1 }
        }
        await esperar(0.3)
        withAnimation(.timingCurve(0.65, 0, 0.35, 1, duration: 0.55)) { trazo1 = 1 }
        await esperar(0.3)   // 0.60 s
        withAnimation(.timingCurve(0.65, 0, 0.35, 1, duration: 0.55)) { trazo2 = 1 }
        await esperar(0.35)  // 0.95 s
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) { punto1 = 1 }
        await esperar(0.1)   // 1.05 s
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) { punto2 = 1 }
        await esperar(0.6)   // 1.65 s
        withAnimation(.easeOut(duration: 0.3)) { opacidadMarca = 0 }
        await esperar(0.15)  // 1.80 s: el círculo cubre la pantalla
        withAnimation(.timingCurve(0.7, 0, 0.3, 1, duration: 0.9)) { escalaCirculo = 15 }
        await esperar(0.9)   // 2.70 s
        withAnimation(.easeOut(duration: 0.25)) { opacidadTodo = 0 }
        await esperar(0.25)
        alTerminar()
    }
}

/// Los dos trazos de la "m" del logo, en el sistema de 100 × 100 del diseño.
private struct TrazoM: Shape {
    let parte: Int

    func path(in rect: CGRect) -> Path {
        let e = rect.width / 100
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: rect.minX + x * e, y: rect.minY + y * e) }
        var camino = Path()
        if parte == 1 {
            // M20.7 72.7 V52 a14.15 14.15 0 0 1 28.3 0 v13
            camino.move(to: p(20.7, 72.7))
            camino.addLine(to: p(20.7, 52))
            camino.addRelativeArc(center: p(34.85, 52), radius: 14.15 * e, startAngle: .degrees(180), delta: .degrees(180))
            camino.addLine(to: p(49, 65))
        } else {
            // M49 65 V52 a14 14 0 0 1 28 0 v20.7
            camino.move(to: p(49, 65))
            camino.addLine(to: p(49, 52))
            camino.addRelativeArc(center: p(63, 52), radius: 14 * e, startAngle: .degrees(180), delta: .degrees(180))
            camino.addLine(to: p(77, 72.7))
        }
        return camino
    }
}

#Preview {
    SplashView {}
}
