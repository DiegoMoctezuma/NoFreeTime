import SwiftUI

/// Estilo neutro de alto contraste (CONTRATOS §8). WP-06 cambia los valores, no la API.
enum Paleta {
    /// Colores de medicamento con buen contraste sobre fondo claro y oscuro.
    static let medicamentos = ["#2563EB", "#DC2626", "#16A34A", "#9333EA", "#EA580C", "#0891B2"]

    /// Tonos oscuros para los iconos de estado (el texto va en `.primary` para contraste AA).
    static let tomada = Color(hex: "#15803D")
    static let sePaso = Color(hex: "#C2410C")
    static let dudoso = Color.yellow.opacity(0.35)
    static let tarjeta = Color(.secondarySystemBackground)
    static let fondo = Color(.systemBackground)

    /// Siguiente color libre para un medicamento nuevo.
    static func siguiente(usados: [String]) -> String {
        medicamentos.first { !usados.contains($0) } ?? medicamentos[usados.count % medicamentos.count]
    }
}

extension Color {
    /// "#RRGGBB"
    init(hex: String) {
        let limpio = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var valor: UInt64 = 0
        Scanner(string: limpio).scanHexInt64(&valor)
        self.init(red: Double((valor >> 16) & 0xFF) / 255,
                  green: Double((valor >> 8) & 0xFF) / 255,
                  blue: Double(valor & 0xFF) / 255)
    }
}

/// Botón grande a lo ancho (≥ 60 pt de alto).
struct BotonGrande: View {
    enum Estilo { case principal, secundario }

    let titulo: String
    var icono: String? = nil
    var estilo: Estilo = .principal
    let accion: () -> Void

    var body: some View {
        Button(action: accion) {
            HStack(spacing: 12) {
                if let icono { Image(systemName: icono).accessibilityHidden(true) }
                Text(titulo).multilineTextAlignment(.center)
            }
            .font(.title3.weight(.semibold))
            .frame(maxWidth: .infinity, minHeight: 60)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .foregroundStyle(estilo == .principal ? Color.white : Color.primary)
        .background(estilo == .principal ? Color.accentColor : Paleta.tarjeta,
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            if estilo == .secundario {
                RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color.primary.opacity(0.6), lineWidth: 2)
            }
        }
        .contentShape(.rect)
    }
}

/// Una pregunta por pantalla: título grande arriba, contenido y botones abajo.
struct PantallaPregunta<Contenido: View, Botones: View>: View {
    let titulo: String
    var subtitulo: String? = nil
    @ViewBuilder var contenido: Contenido
    @ViewBuilder var botones: Botones

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(titulo)
                        .font(.largeTitle.bold())
                        .accessibilityAddTraits(.isHeader)
                    if let subtitulo {
                        Text(subtitulo).font(.title3).foregroundStyle(.secondary)
                    }
                    contenido
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
            }
            VStack(spacing: 16) { botones }
                .padding(20)
                .background(Paleta.fondo)
        }
        .background(Paleta.fondo)
    }
}

extension PantallaPregunta where Botones == EmptyView {
    init(titulo: String, subtitulo: String? = nil, @ViewBuilder contenido: () -> Contenido) {
        self.titulo = titulo
        self.subtitulo = subtitulo
        self.contenido = contenido()
        self.botones = EmptyView()
    }
}

/// Indicador de estado que nunca depende solo del color (icono + texto).
struct Etiqueta: View {
    let texto: String
    let icono: String
    let color: Color

    var body: some View {
        Label {
            Text(texto).foregroundStyle(.primary)
        } icon: {
            Image(systemName: icono).foregroundStyle(color)
        }
        .font(.headline)
    }
}

/// Fondo amarillo + "Revisa esto" para campos dudosos de la IA.
struct MarcaDudoso: ViewModifier {
    let activo: Bool
    func body(content: Content) -> some View {
        // Misma estructura siempre para no perder el estado del campo al alternar.
        VStack(alignment: .leading, spacing: 4) {
            content
            if activo {
                Label("Revisa esto", systemImage: "questionmark.circle").font(.subheadline.bold())
            }
        }
        .padding(activo ? 8 : 0)
        .background(activo ? Paleta.dudoso : Color.clear, in: RoundedRectangle(cornerRadius: 10))
    }
}

extension View {
    func dudoso(_ activo: Bool) -> some View { modifier(MarcaDudoso(activo: activo)) }
}
