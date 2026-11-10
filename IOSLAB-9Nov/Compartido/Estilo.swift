import SwiftUI
import UIKit

// Sistema de diseño de MiMi, inspirado en apps de salud tranquilas (referencia: Clio).
// Pantallas blancas, títulos con serifa, texto casi negro, botón principal negro,
// selección en coral y tarjetas pastel. La app se muestra siempre en modo claro
// para que las ilustraciones de línea negra se vean bien.

enum Paleta {
    // Superficies
    static let fondo = Color(hex: "#FFFFFF")
    static let lienzo = Color(hex: "#E3ECEA")
    static let tarjeta = Color(hex: "#F4F7F6")
    static let hundido = Color(hex: "#EDF2F1")
    static let borde = Color(hex: "#DADFDE")

    // Texto
    static let tinta = Color(hex: "#161A19")
    static let tintaSuave = Color(hex: "#5F6664")

    /// Texto e iconos de marca (casi negro, como en la referencia).
    static let marca = Color(hex: "#161A19")
    /// Relleno oscuro con texto blanco encima.
    static let marcaFuerte = Color(hex: "#161A19")
    /// Fondo suave para iconos (salvia muy claro).
    static let marcaSuave = Color(hex: "#E3ECEA")

    /// Coral: selección, progreso y lo que "te toca". Texto encima siempre oscuro.
    static let acento = Color(hex: "#F07B6E")
    static let acentoSuave = Color(hex: "#FBDAD4")
    static let sobreAcento = Color(hex: "#161A19")

    // Pasteles para tarjetas grandes
    static let durazno = Color(hex: "#EDB29F")
    static let lavanda = Color(hex: "#CBC3E4")
    static let agua = Color(hex: "#DAEDEE")
    static let salvia = Color(hex: "#DCE8E5")
    static let sol = Color(hex: "#F5DFA4")

    // Estados: nunca solo color
    static let tomada = Color(hex: "#2C7652")
    static let tomadaFondo = Color(hex: "#E1F1E7")
    static let sePaso = Color(hex: "#B23E2C")
    static let sePasoFondo = Color(hex: "#FBE2DC")
    static let dudoso = Color(hex: "#FFF0C6")
    static let dudosoBorde = Color(hex: "#C08419")

    // Escala neutra (ilustraciones de respaldo)
    static let base100 = Color(hex: "#ECEFEE")
    static let base200 = Color(hex: "#D5DAD8")
    static let base300 = Color(hex: "#AEB5B3")
    static let base900 = Color(hex: "#161A19")

    /// Colores de medicamento: tonos medios que se distinguen entre sí.
    static let medicamentos = ["#2563EB", "#DC2626", "#16A34A", "#9333EA", "#EA580C", "#0891B2"]

    static func siguiente(usados: [String]) -> String {
        medicamentos.first { !usados.contains($0) } ?? medicamentos[usados.count % medicamentos.count]
    }

    /// Pastel por franja del día.
    static func pastel(_ franja: Franja) -> Color {
        switch franja {
        case .manana: durazno
        case .tarde: sol
        case .noche: lavanda
        }
    }
}

/// Tipografía: serifa del sistema (New York) para títulos, SF Pro para el resto.
/// Todo con estilos de Dynamic Type.
enum Tipo {
    static let grande = Font.system(.largeTitle, design: .serif, weight: .semibold)
    static let pregunta = Font.system(.title, design: .serif, weight: .semibold)
    static let titulo = Font.system(.title, design: .serif, weight: .semibold)
    static let tarjeta = Font.system(.title2, design: .serif, weight: .semibold)
    static let seccion = Font.system(.title3, weight: .semibold)
    static let etiqueta = Font.system(.headline, weight: .semibold)
    static let mayusculas = Font.system(.footnote, weight: .semibold)
}

enum Radio {
    static let tarjeta: CGFloat = 24
    static let control: CGFloat = 16
}

extension Color {
    /// "#RRGGBB"
    nonisolated init(hex: String) {
        self.init(uiColor: UIColor(hex: hex))
    }
}

extension UIColor {
    nonisolated convenience init(hex: String) {
        let limpio = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var valor: UInt64 = 0
        Scanner(string: limpio).scanHexInt64(&valor)
        self.init(red: CGFloat((valor >> 16) & 0xFF) / 255,
                  green: CGFloat((valor >> 8) & 0xFF) / 255,
                  blue: CGFloat(valor & 0xFF) / 255,
                  alpha: 1)
    }
}

// MARK: Botones

/// Botón grande a lo ancho (≥ 60 pt de alto).
struct BotonGrande: View {
    enum Estilo { case principal, secundario, texto }

    let titulo: String
    var icono: String? = nil
    var estilo: Estilo = .principal
    let accion: () -> Void

    var body: some View {
        Button(action: accion) {
            EtiquetaBoton(titulo: titulo, icono: icono, estilo: estilo)
        }
        .buttonStyle(EstiloBotonGrande(estilo: estilo))
    }
}

/// Contenido de un botón grande; también lo usan PhotosPicker y NavigationLink.
struct EtiquetaBoton: View {
    let titulo: String
    var icono: String? = nil
    var estilo: BotonGrande.Estilo = .principal

    var body: some View {
        HStack(spacing: 10) {
            if let icono {
                Image(systemName: icono).fontWeight(.semibold).accessibilityHidden(true)
            }
            Text(titulo)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.system(.title3, weight: .semibold))
        .frame(maxWidth: .infinity, minHeight: estilo == .texto ? 48 : 60)
        .padding(.horizontal, 20)
        .padding(.vertical, 4)
        .contentShape(RoundedRectangle(cornerRadius: Radio.control, style: .continuous))
    }
}

struct EstiloBotonGrande: ButtonStyle {
    let estilo: BotonGrande.Estilo
    @Environment(\.isEnabled) private var activo

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(primerPlano)
            .background { fondo }
            .opacity(activo ? 1 : 0.35)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.snappy(duration: 0.15), value: configuration.isPressed)
    }

    private var primerPlano: Color {
        switch estilo {
        case .principal: Color.white
        case .secundario: Paleta.tinta
        case .texto: Paleta.tintaSuave
        }
    }

    @ViewBuilder private var fondo: some View {
        let forma = RoundedRectangle(cornerRadius: Radio.control, style: .continuous)
        switch estilo {
        case .principal:
            forma.fill(Paleta.marcaFuerte)
        case .secundario:
            forma.fill(Paleta.fondo).overlay(forma.strokeBorder(Paleta.borde, lineWidth: 1.5))
        case .texto:
            Color.clear
        }
    }
}

/// Botón redondo negro con flecha (avanzar en el onboarding).
struct BotonFlecha: View {
    var icono = "arrow.right"
    var etiqueta = "Siguiente"
    let accion: () -> Void

    var body: some View {
        Button(action: accion) {
            Image(systemName: icono)
                .font(.title2.weight(.semibold))
                .foregroundStyle(Color.white)
                .frame(width: 64, height: 64)
                .background(Circle().fill(Paleta.marcaFuerte))
        }
        .buttonStyle(EstiloPresionable())
        .accessibilityLabel(etiqueta)
    }
}

// MARK: Pantalla de una pregunta

/// Una pregunta por pantalla: ilustración opcional, título con serifa, contenido y botones abajo.
struct PantallaPregunta<Contenido: View, Botones: View>: View {
    let titulo: String
    let subtitulo: String?
    let paso: (Int, Int)?
    let ilustracion: Ilustracion?
    let contenido: Contenido
    let botones: Botones

    init(titulo: String,
         subtitulo: String? = nil,
         paso: (Int, Int)? = nil,
         ilustracion: Ilustracion? = nil,
         @ViewBuilder contenido: () -> Contenido,
         @ViewBuilder botones: () -> Botones) {
        self.titulo = titulo
        self.subtitulo = subtitulo
        self.paso = paso
        self.ilustracion = ilustracion
        self.contenido = contenido()
        self.botones = botones()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if let ilustracion {
                    ilustracion
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, -24)
                }
                if let paso {
                    IndicadorPaso(actual: paso.0, total: paso.1)
                }
                VStack(alignment: .leading, spacing: 10) {
                    Text(titulo)
                        .font(Tipo.pregunta)
                        .foregroundStyle(Paleta.tinta)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    if let subtitulo {
                        Text(subtitulo)
                            .font(.title3)
                            .foregroundStyle(Paleta.tintaSuave)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                contenido
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if Botones.self != EmptyView.self {
                VStack(spacing: 10) { botones }
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                    .padding(.bottom, 8)
                    .background(Paleta.fondo)
            }
        }
        .background(Paleta.fondo.ignoresSafeArea())
    }
}

extension PantallaPregunta where Botones == EmptyView {
    init(titulo: String, subtitulo: String? = nil, paso: (Int, Int)? = nil, ilustracion: Ilustracion? = nil,
         @ViewBuilder contenido: () -> Contenido) {
        self.init(titulo: titulo, subtitulo: subtitulo, paso: paso, ilustracion: ilustracion, contenido: contenido) { EmptyView() }
    }
}

/// Puntos de página (●  ·  ·) como en la referencia.
struct IndicadorPaso: View {
    let actual: Int
    let total: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(1...max(total, 1), id: \.self) { i in
                Capsule()
                    .fill(i == actual ? Paleta.marcaFuerte : Paleta.base200)
                    .frame(width: i == actual ? 22 : 8, height: 8)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Paso \(actual) de \(total)")
    }
}

// MARK: Estados y revisión

/// Indicador de estado que nunca depende solo del color (icono + texto).
struct Etiqueta: View {
    let texto: String
    let icono: String
    let color: Color

    var body: some View {
        Label {
            Text(texto).foregroundStyle(Paleta.tinta)
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
        VStack(alignment: .leading, spacing: 6) {
            content
            if activo {
                Label("Revisa esto", systemImage: "questionmark.circle.fill")
                    .font(.subheadline.bold())
                    .foregroundStyle(Paleta.tinta)
            }
        }
        .padding(activo ? 12 : 0)
        .background {
            if activo {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Paleta.dudoso)
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Paleta.dudosoBorde, style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])))
            }
        }
    }
}

extension View {
    func dudoso(_ activo: Bool) -> some View { modifier(MarcaDudoso(activo: activo)) }
}
