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

    /// Texto pequeño en mayúsculas con espacio entre letras ("PRÓXIMAS TOMAS").
    func estiloMayusculas() -> some View {
        self.font(Tipo.mayusculas).tracking(0.8).foregroundStyle(Paleta.tintaSuave).textCase(.uppercase)
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
                            .font(.caption.weight(.bold))
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
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(Color.white)
            }
        }
        .frame(width: 30, height: 30)
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
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.snappy(duration: 0.15), value: configuration.isPressed)
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
            DatePicker(momento.nombre, selection: fecha, displayedComponents: .hourAndMinute)
                .labelsHidden()
                .font(.title3)
        }
        .frame(minHeight: 56)
    }

    private var fecha: Binding<Date> {
        Binding {
            Calendar.current.date(bySettingHour: minutos / 60, minute: minutos % 60, second: 0, of: .now) ?? .now
        } set: { nueva in
            let c = Calendar.current.dateComponents([.hour, .minute], from: nueva)
            minutos = (c.hour ?? 0) * 60 + (c.minute ?? 0)
        }
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
