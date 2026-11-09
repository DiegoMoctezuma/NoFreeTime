import SwiftUI
import SwiftData
import PhotosUI

/// Pantalla de prueba de WP-01 (no es parte del recorrido): elige una foto de receta o caja
/// y muestra lo que propone el modelo y cuánto tardó. Sirve como evidencia en el iPhone.
struct PruebaLectorView: View {
    @Environment(\.modelContext) private var contexto
    @State private var lector = LectorIA()
    @State private var foto: PhotosPickerItem?
    @State private var esCaja = false
    @State private var resultado: String = ""

    var body: some View {
        List {
            Section {
                Text(disponibilidadTexto).font(.headline)
                Picker("Qué leer", selection: $esCaja) {
                    Text("Receta").tag(false)
                    Text("Caja").tag(true)
                }
                .pickerStyle(.segmented)
                PhotosPicker(selection: $foto, matching: .images) {
                    Label("Elegir foto", systemImage: "photo")
                        .font(.title3.bold())
                        .frame(maxWidth: .infinity, minHeight: 60)
                }
            }
            if lector.leyendo {
                Section { ProgressView(esCaja ? "Leyendo la caja…" : "Leyendo tu receta…") }
            }
            if let d = lector.ultimaDuracion {
                Section("Tiempo") {
                    Text(d.formatted(.units(allowed: [.seconds, .milliseconds], width: .abbreviated)))
                        .font(.title2.monospacedDigit())
                }
            }
            if !resultado.isEmpty {
                Section("Resultado") { Text(resultado).font(.body.monospaced()).textSelection(.enabled) }
            }
        }
        .navigationTitle("Prueba del lector")
        .onChange(of: foto) { _, nuevo in
            guard let nuevo else { return }
            Task { await leer(nuevo) }
        }
    }

    private var disponibilidadTexto: String {
        switch LectorIA.disponibilidad {
        case .disponible: "Apple Intelligence: disponible"
        case .noDisponible(let motivo): motivo
        }
    }

    private func leer(_ item: PhotosPickerItem) async {
        resultado = ""
        guard let data = try? await item.loadTransferable(type: Data.self),
              let imagen = UIImage(data: data)?.cgImageOrientado else {
            resultado = "No pude abrir la foto."
            return
        }
        do {
            if esCaja {
                let c = try await lector.leerCaja(imagen)
                resultado = "legible: \(c.legible)\nnombre: \(c.nombre ?? "—")\nconcentración: \(c.concentracion ?? "—")\npastillas: \(c.pastillas.map(String.init) ?? "—")"
            } else {
                let tratamiento = Almacen.medicamentosActivos(en: contexto)
                let r = try await lector.leerReceta(imagen, tratamiento: tratamiento)
                resultado = "legible: \(r.legible)\n\n" + r.indicaciones.map { i in
                    let p = i.propuesta
                    let m = MapeoIndicacion.momentos(de: p).momentos.map(\.nombre).joined(separator: ", ")
                    return "\(p.nombre) \(p.concentracion ?? "") · \(p.dosis ?? "?") · \(m) · cada \(p.cadaHoras.map(String.init) ?? "?") h · \(p.duracionDias.map { "\($0) días" } ?? "sin duración")"
                        + (i.yaRegistrado ? "\n  Ya lo tienes registrado" : "")
                        + (i.dudosos.isEmpty ? "" : "\n  Dudoso: \(i.dudosos.sorted().joined(separator: ", "))")
                }.joined(separator: "\n\n")
            }
        } catch {
            resultado = error.localizedDescription
        }
    }
}

extension UIImage {
    /// CGImage con la orientación ya aplicada (las fotos del iPhone vienen rotadas en los metadatos).
    var cgImageOrientado: CGImage? {
        if imageOrientation == .up, let cg = cgImage { return cg }
        let formato = UIGraphicsImageRendererFormat()
        formato.scale = 1
        return UIGraphicsImageRenderer(size: size, format: formato).image { _ in draw(at: .zero) }.cgImage
    }
}
