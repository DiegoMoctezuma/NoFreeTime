import SwiftUI
import UIKit

/// Claves de UserDefaults de la app.
enum ClavesApp {
    /// Se pone en true al terminar la presentación y la entrevista (v2: el onboarding nuevo se muestra una vez).
    static let altaTerminada = "mimi.onboarding.v2"
    /// Consentimiento para enviar texto a DeepSeek, con la información de privacidad actualizada.
    static let permitirNube = "mimi.permitirNube.v2"
    /// La persona puede apagar la lectura con IA (HCAI: control). Sin IA, se agregan a mano.
    static let usarIA = "mimi.usarIA"
    /// Tamaño de letra elegido en el onboarding o en Perfil (`TamanoLetra`).
    static let tamanoLetra = "mimi.tamanoLetra"
    /// Leer en voz alta cada tarjeta de "Tu plan" al aparecer.
    static let leerEnVoz = "mimi.leerEnVoz"
}

// MARK: Tamaño de letra

/// Tamaño de letra de la app. "Como en mi iPhone" respeta el ajuste del sistema;
/// los demás lo fijan para toda la app (también en hojas y alertas de la app).
enum TamanoLetra: String, CaseIterable, Identifiable {
    case sistema, grande, masGrande, muyGrande

    var id: String { rawValue }

    var titulo: String {
        switch self {
        case .sistema: "Como en mi iPhone"
        case .grande: "Grande"
        case .masGrande: "Más grande"
        case .muyGrande: "Muy grande"
        }
    }

    /// nil = el del sistema.
    var tamano: DynamicTypeSize? {
        switch self {
        case .sistema: nil
        case .grande: .xxLarge
        case .masGrande: .xxxLarge
        case .muyGrande: .accessibility2
        }
    }

    /// Tamaño con el que se muestra la opción en el selector (vista previa de sí misma).
    var muestra: DynamicTypeSize {
        tamano ?? DynamicTypeSize(UIApplication.shared.preferredContentSizeCategory) ?? .large
    }
}

/// Aplica el tamaño elegido a toda la vista (se usa en la raíz de la app).
struct AplicarTamanoLetra: ViewModifier {
    @AppStorage(ClavesApp.tamanoLetra) private var raw = TamanoLetra.sistema.rawValue
    /// El tamaño que eligió la persona en Ajustes del iPhone (se lee antes de aplicar el de MiMi).
    @Environment(\.dynamicTypeSize) private var delSistema

    func body(content: Content) -> some View {
        // Siempre el mismo modificador. Si se alternara entre "con" y "sin" .dynamicTypeSize,
        // SwiftUI reconstruiría toda la app y el onboarding regresaría al primer paso.
        content.dynamicTypeSize(TamanoLetra(rawValue: raw)?.tamano ?? delSistema)
    }
}

extension View {
    func tamanoLetraElegido() -> some View { modifier(AplicarTamanoLetra()) }
}

/// Opciones de tamaño de letra; cada una se ve con su propio tamaño. Se usa en el onboarding y en Perfil.
struct SelectorTamanoLetra: View {
    @AppStorage(ClavesApp.tamanoLetra) private var raw = TamanoLetra.sistema.rawValue

    var body: some View {
        VStack(spacing: 12) {
            ForEach(TamanoLetra.allCases) { opcion in
                let elegido = raw == opcion.rawValue
                Button {
                    withAnimation(.snappy) { raw = opcion.rawValue }
                } label: {
                    HStack(spacing: 14) {
                        RadioCoral(marcado: elegido)
                        Text(opcion.titulo)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Paleta.tinta)
                            .fixedSize(horizontal: false, vertical: true)
                            .dynamicTypeSize(opcion.muestra)
                        Spacer(minLength: 0)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: Radio.control, style: .continuous).fill(Paleta.fondo))
                    .overlay(RoundedRectangle(cornerRadius: Radio.control, style: .continuous)
                        .strokeBorder(elegido ? Paleta.marcaFuerte : Paleta.borde, lineWidth: elegido ? 2 : 1.2))
                    .contentShape(RoundedRectangle(cornerRadius: Radio.control, style: .continuous))
                }
                .buttonStyle(EstiloPresionable())
                .accessibilityLabel("Letra \(opcion.titulo)")
                .accessibilityAddTraits(elegido ? .isSelected : [])
            }
        }
    }
}

// MARK: Tarjeta

struct EstiloTarjeta: ViewModifier {
    var relleno: CGFloat = 20
    var color: Color = Paleta.tarjeta

    func body(content: Content) -> some View {
        content
            .padding(relleno)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: Radio.tarjeta, style: .continuous).fill(color))
    }
}

extension View {
    func tarjeta(relleno: CGFloat = 20, color: Color = Paleta.tarjeta) -> some View {
        modifier(EstiloTarjeta(relleno: relleno, color: color))
    }

    /// Etiqueta de sección ("Te toca ahora"): tamaño de lectura normal, sin mayúsculas (cuestan más leer)
    /// y en tinta, no en gris, porque muchas veces va sobre tarjetas pastel.
    func estiloMayusculas() -> some View {
        self.font(Tipo.mayusculas).foregroundStyle(Paleta.tinta)
    }
}

// MARK: Ilustraciones

/// Ilustración de línea. Si existe la imagen `nombre` en Assets la usa;
/// si no, dibuja círculos pastel con un símbolo de trazo fino como respaldo.
struct Ilustracion: View {
    let nombre: String
    var simbolo: String = "pills"
    var color: Color = Paleta.durazno
    var color2: Color = Paleta.agua
    var alto: CGFloat = 220

    var body: some View {
        Group {
            if let imagen = UIImage(named: nombre) {
                Image(uiImage: imagen)
                    .resizable()
                    .scaledToFit()
            } else {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.75))
                        .frame(width: alto * 0.62, height: alto * 0.62)
                        .offset(x: -alto * 0.32, y: -alto * 0.08)
                    Circle()
                        .fill(color2.opacity(0.9))
                        .frame(width: alto * 0.34, height: alto * 0.34)
                        .offset(x: alto * 0.5, y: -alto * 0.3)
                    Rectangle()
                        .fill(Paleta.tinta)
                        .frame(height: 1.2)
                        .offset(y: alto * 0.38)
                    Image(systemName: simbolo)
                        .font(.system(size: alto * 0.36, weight: .ultraLight))
                        .foregroundStyle(Paleta.tinta)
                }
            }
        }
        .frame(height: alto)
        .frame(maxWidth: .infinity)
        .clipped()
        .accessibilityHidden(true)
    }
}

// MARK: Opciones

/// Opción grande. `elegida == nil` → navega (icono y flecha); `true/false` → selección (círculo coral).
struct TarjetaOpcion: View {
    let icono: String
    let titulo: String
    var detalle: String? = nil
    var insignia: String? = nil
    var elegida: Bool? = nil
    let accion: () -> Void

    private var marcada: Bool { elegida == true }

    var body: some View {
        Button(action: accion) {
            HStack(spacing: 16) {
                if elegida != nil {
                    RadioCoral(marcado: marcada)
                } else {
                    Image(systemName: icono)
                        .font(.title2)
                        .foregroundStyle(Paleta.tinta)
                        .frame(width: 52, height: 52)
                        .background(Circle().fill(Paleta.marcaSuave))
                        .accessibilityHidden(true)
                }
                VStack(alignment: .leading, spacing: 4) {
                    if let insignia {
                        Text(insignia)
                            .font(.body.weight(.bold))
                            .foregroundStyle(Paleta.sobreAcento)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Paleta.acentoSuave))
                    }
                    Text(titulo)
                        .font(Tipo.seccion)
                        .foregroundStyle(Paleta.tinta)
                        .fixedSize(horizontal: false, vertical: true)
                    if let detalle {
                        Text(detalle)
                            .font(.body)
                            .foregroundStyle(Paleta.tintaSuave)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if elegida == nil {
                    Image(systemName: "chevron.right")
                        .font(.headline)
                        .foregroundStyle(Paleta.tintaSuave)
                        .accessibilityHidden(true)
                } else if elegida != nil {
                    Image(systemName: icono)
                        .font(.title3)
                        .foregroundStyle(Paleta.tintaSuave)
                        .accessibilityHidden(true)
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, minHeight: 84, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: Radio.control, style: .continuous).fill(Paleta.fondo))
            .overlay(
                RoundedRectangle(cornerRadius: Radio.control, style: .continuous)
                    .strokeBorder(marcada ? Paleta.marcaFuerte : Paleta.borde, lineWidth: marcada ? 2 : 1.2)
            )
            .contentShape(RoundedRectangle(cornerRadius: Radio.control, style: .continuous))
        }
        .buttonStyle(EstiloPresionable())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(marcada ? .isSelected : [])
    }
}

/// Círculo de selección: vacío o coral con palomita.
struct RadioCoral: View {
    let marcado: Bool

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(marcado ? Paleta.acento : Paleta.base300, lineWidth: 1.5)
            if marcado {
                Circle().fill(Paleta.acento)
                Image(systemName: "checkmark")
                    .font(.body.weight(.bold))
                    .foregroundStyle(Color.white)
            }
        }
        .frame(width: 30, height: 30)
        .cambioMiMi(marcado)
        .accessibilityHidden(true)
    }
}

/// Chip de selección múltiple (momentos del día, dosis, duración).
struct ChipSeleccion: View {
    let titulo: String
    var icono: String? = nil
    let elegido: Bool
    let accion: () -> Void

    var body: some View {
        Button(action: accion) {
            HStack(spacing: 10) {
                RadioCoral(marcado: elegido)
                    .scaleEffect(0.85)
                Text(titulo)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                if let icono {
                    Image(systemName: icono)
                        .foregroundStyle(Paleta.tintaSuave)
                        .accessibilityHidden(true)
                }
            }
            .font(Tipo.etiqueta)
            .foregroundStyle(Paleta.tinta)
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, minHeight: 58)
            .background(RoundedRectangle(cornerRadius: Radio.control, style: .continuous).fill(Paleta.fondo))
            .overlay(RoundedRectangle(cornerRadius: Radio.control, style: .continuous)
                .strokeBorder(elegido ? Paleta.marcaFuerte : Paleta.borde, lineWidth: elegido ? 2 : 1.2))
            .contentShape(RoundedRectangle(cornerRadius: Radio.control, style: .continuous))
        }
        .buttonStyle(EstiloPresionable())
        .accessibilityAddTraits(elegido ? .isSelected : [])
    }
}

/// Encoge un poco al presionar; sin cambiar colores.
struct EstiloPresionable: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reducir

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reducir ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.86 : 1)
            .animation(reducir ? nil : MovimientoMiMi.respuesta, value: configuration.isPressed)
    }
}

// MARK: Medicamento

/// Foto de la caja (si la hay) o el color del medicamento con una pastilla.
struct IconoMedicamento: View {
    let colorHex: String
    let foto: Data?
    let simbolo: String
    var tamano: CGFloat = 56

    init(_ med: Medicamento, tamano: CGFloat = 56) {
        self.colorHex = med.colorHex
        self.foto = med.fotoCaja
        self.simbolo = med.tipoAccion.icono
        self.tamano = tamano
    }

    init(colorHex: String, foto: Data? = nil, tamano: CGFloat = 56) {
        self.colorHex = colorHex
        self.foto = foto
        self.simbolo = "pills"
        self.tamano = tamano
    }

    var body: some View {
        let color = Color(hex: colorHex)
        let forma = RoundedRectangle(cornerRadius: tamano * 0.3, style: .continuous)
        ZStack {
            if let foto, let imagen = UIImage(data: foto) {
                Image(uiImage: imagen).resizable().scaledToFill()
            } else {
                forma.fill(Paleta.fondo)
                Image(systemName: simbolo)
                    .font(.system(size: tamano * 0.42, weight: .light))
                    .foregroundStyle(Paleta.tinta)
            }
        }
        .frame(width: tamano, height: tamano)
        .clipShape(forma)
        .overlay(forma.strokeBorder(Paleta.tinta.opacity(0.12), lineWidth: 1))
        .overlay(alignment: .bottomTrailing) {
            Circle()
                .fill(color)
                .frame(width: tamano * 0.3, height: tamano * 0.3)
                .overlay(Circle().strokeBorder(Color.white, lineWidth: 2.5))
                .offset(x: 4, y: 4)
        }
        .accessibilityHidden(true)
    }
}

// MARK: Horas de la rutina

extension Momento {
    var icono: String {
        switch self {
        case .desayuno: "sunrise"
        case .comida: "sun.max"
        case .cena: "sunset"
        case .dormir: "moon.stars"
        case .horaFija: "clock"
        }
    }
}

extension Franja {
    var icono: String {
        switch self {
        case .manana: "sunrise"
        case .tarde: "sun.max"
        case .noche: "moon.stars"
        }
    }
}

/// Fila "Desayuno · 8:00" con selector de hora del sistema.
struct FilaHora: View {
    let momento: Momento
    @Binding var minutos: Int
    var resaltar = false
    @Environment(\.dynamicTypeSize) private var tamanoLetra

    var body: some View {
        let disposicion = tamanoLetra.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10))
            : AnyLayout(HStackLayout(spacing: 14))
        disposicion {
            HStack(spacing: 14) {
                Image(systemName: momento.icono)
                    .font(.title3)
                    .foregroundStyle(Paleta.tinta)
                    .frame(width: 46, height: 46)
                    .background(Circle().fill(resaltar ? Paleta.acentoSuave : Paleta.marcaSuave))
                    .accessibilityHidden(true)
                Text(momento.nombre)
                    .font(Tipo.seccion)
                    .foregroundStyle(Paleta.tinta)
            }
            if !tamanoLetra.isAccessibilitySize { Spacer(minLength: 8) }
            // Botones grandes de −30 y +30 minutos: más fáciles que la rueda con temblor en las manos.
            HStack(spacing: 10) {
                botonCambio("minus", etiqueta: "Media hora antes", minutos: -30)
                Text(horaTexto)
                    .font(.system(.title3, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(Paleta.tinta)
                    .frame(minWidth: 96)
                    .contentTransition(.numericText())
                    .accessibilityLabel("\(momento.nombre) a las \(horaTexto)")
                botonCambio("plus", etiqueta: "Media hora después", minutos: 30)
            }
        }
        .frame(minHeight: 56)
    }

    private var horaTexto: String {
        let fecha = Calendar.current.date(bySettingHour: minutos / 60, minute: minutos % 60, second: 0, of: .now) ?? .now
        return fecha.formatted(date: .omitted, time: .shortened)
    }

    private func botonCambio(_ icono: String, etiqueta: String, minutos delta: Int) -> some View {
        Button { cambiar(delta) } label: {
            Image(systemName: icono)
                .font(.title3.weight(.bold))
                .foregroundStyle(Paleta.tinta)
                .frame(width: 52, height: 52)
                .background(Circle().fill(Paleta.marcaSuave))
        }
        .buttonStyle(EstiloPresionable())
        .accessibilityLabel("\(etiqueta) para \(momento.nombre)")
    }

    private func cambiar(_ delta: Int) {
        withAnimation(.snappy) { minutos = ((minutos + delta) % 1440 + 1440) % 1440 }
    }
}

// MARK: Formas y marca

/// Forma orgánica para fondos e ilustraciones.
struct FormaOrganica: Shape {
    func path(in r: CGRect) -> Path {
        let w = r.width
        let h = r.height
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: r.minX + x * w, y: r.minY + y * h) }
        var path = Path()
        path.move(to: p(0.52, 0.02))
        path.addCurve(to: p(0.98, 0.42), control1: p(0.80, 0.0), control2: p(1.0, 0.18))
        path.addCurve(to: p(0.56, 0.98), control1: p(0.97, 0.72), control2: p(0.82, 1.0))
        path.addCurve(to: p(0.03, 0.58), control1: p(0.28, 0.97), control2: p(0.0, 0.84))
        path.addCurve(to: p(0.52, 0.02), control1: p(0.05, 0.26), control2: p(0.24, 0.04))
        path.closeSubpath()
        return path
    }
}

/// Logotipo de texto provisional: "mimi." con serifa. Se cambia por el logo del equipo.
struct MarcaMiMi: View {
    var tamano: Font = .system(size: 64, weight: .bold, design: .serif)

    var body: some View {
        Text("mimi.")
            .font(tamano)
            .foregroundStyle(Paleta.tinta)
            .accessibilityLabel("MiMi")
    }
}

// MARK: Pestañas (barra nativa con Liquid Glass)

enum Pestana: CaseIterable, Hashable {
    case hoy, calendario, escanear, perfil

    var titulo: String {
        switch self {
        case .hoy: "Inicio"
        case .calendario: "Calendario"
        case .escanear: "Agregar"
        case .perfil: "Perfil"
        }
    }

    var icono: String {
        switch self {
        case .hoy: "house"
        case .calendario: "calendar"
        case .escanear: "plus.viewfinder"
        case .perfil: "person.crop.circle"
        }
    }
}

// MARK: Fotos

extension UIImage {
    /// Copia reducida (lado mayor ≤ `maximo`) y ya orientada, para leer con el modelo.
    func reducida(maximo: CGFloat) -> UIImage {
        let lado = max(size.width, size.height)
        let escala = lado > maximo ? maximo / lado : 1
        let nuevo = CGSize(width: (size.width * escala).rounded(), height: (size.height * escala).rounded())
        let formato = UIGraphicsImageRendererFormat()
        formato.scale = 1
        return UIGraphicsImageRenderer(size: nuevo, format: formato).image { _ in
            draw(in: CGRect(origin: .zero, size: nuevo))
        }
    }
}
