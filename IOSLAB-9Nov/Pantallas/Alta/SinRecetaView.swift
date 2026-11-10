import SwiftUI

// Camino "No tengo receta" (RF-02): nombre, cuántas veces al día y cuándo.
// Termina en la misma tarjeta de "¿Está bien así?" que la receta.

struct SinRecetaNombreView: View {
    let seguir: () -> Void

    @Environment(ModeloAlta.self) private var modelo
    @FocusState private var enfocado: Bool

    private var nombreListo: Bool {
        !modelo.manualNombre.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        @Bindable var modelo = modelo
        PantallaPregunta(titulo: "¿Cómo se llama tu medicina?",
                         subtitulo: "Como viene en la caja. Por ejemplo: Losartán.") {
            TextField("Nombre de la medicina", text: $modelo.manualNombre)
                .font(.system(.title, design: .rounded, weight: .semibold))
                .foregroundStyle(Paleta.tinta)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .submitLabel(.next)
                .focused($enfocado)
                .onSubmit { if nombreListo { seguir() } }
                .padding(.horizontal, 22)
                .frame(minHeight: 72)
                .background(RoundedRectangle(cornerRadius: Radio.control, style: .continuous).fill(Paleta.tarjeta))
                .overlay(RoundedRectangle(cornerRadius: Radio.control, style: .continuous)
                    .strokeBorder(enfocado ? Paleta.marcaFuerte : Paleta.borde, lineWidth: enfocado ? 2.5 : 1))
        } botones: {
            BotonGrande(titulo: "Seguir", icono: "arrow.right", accion: seguir)
                .disabled(!nombreListo)
        }
        .onAppear { enfocado = true }
    }
}

struct SinRecetaVecesView: View {
    let seguir: () -> Void

    @Environment(ModeloAlta.self) private var modelo

    var body: some View {
        PantallaPregunta(titulo: "¿Cuántas veces al día?",
                         subtitulo: modelo.manualNombre.trimmingCharacters(in: .whitespaces)) {
            VStack(spacing: 14) {
                opcion(1, icono: "1.circle.fill", detalle: "Una sola vez")
                opcion(2, icono: "2.circle.fill", detalle: "Mañana y noche")
                opcion(3, icono: "3.circle.fill", detalle: "Con cada comida")
            }
        }
    }

    private func opcion(_ veces: Int, icono: String, detalle: String) -> some View {
        TarjetaOpcion(icono: icono,
                      titulo: veces == 1 ? "1 vez" : "\(veces) veces",
                      detalle: detalle) {
            modelo.manualVeces = veces
            switch veces {
            case 1: modelo.manualMomentos = [.desayuno]
            case 2: modelo.manualMomentos = [.desayuno, .cena]
            default: modelo.manualMomentos = [.desayuno, .comida, .cena]
            }
            seguir()
        }
    }
}

struct SinRecetaCuandoView: View {
    let seguir: () -> Void

    @Environment(ModeloAlta.self) private var modelo

    private let columnas = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        PantallaPregunta(titulo: "¿Cuándo te la tomas?",
                         subtitulo: "Ya marqué lo más común para \(modelo.manualVeces == 1 ? "1 vez" : "\(modelo.manualVeces) veces") al día.") {
            LazyVGrid(columns: columnas, spacing: 12) {
                ForEach(Momento.rutina, id: \.self) { m in
                    ChipSeleccion(titulo: m.nombre, icono: m.icono, elegido: modelo.manualMomentos.contains(m)) {
                        alternar(m)
                    }
                }
            }
        } botones: {
            BotonGrande(titulo: "Seguir", icono: "arrow.right") {
                let nombre = modelo.manualNombre.trimmingCharacters(in: .whitespaces)
                let concentracion = modelo.manualConcentracion.trimmingCharacters(in: .whitespaces)
                modelo.borradores = [Borrador(nombre: nombre, concentracion: concentracion, dosis: "",
                                              momentos: modelo.manualMomentos, dudosos: modelo.manualDudosos.union(["dosis"]),
                                              fuente: modelo.manualFuente, foto: modelo.manualFoto,
                                              pastillas: modelo.manualPastillas)]
                modelo.vieneDeReceta = false
                seguir()
            }
            .disabled(modelo.manualMomentos.isEmpty)
        }
    }

    private func alternar(_ m: Momento) {
        if let i = modelo.manualMomentos.firstIndex(of: m) {
            modelo.manualMomentos.remove(at: i)
        } else {
            modelo.manualMomentos.append(m)
            modelo.manualMomentos.sort { (Momento.rutina.firstIndex(of: $0) ?? 9) < (Momento.rutina.firstIndex(of: $1) ?? 9) }
        }
    }
}
