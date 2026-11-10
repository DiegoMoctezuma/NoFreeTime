import SwiftUI
import SwiftData

/// "¿Cómo te aviso?" (RF-05): por medicamento, Alarma (recomendada) o Recordatorio.
/// Guardar la elección y programar los avisos ocurre solo al tocar "Listo".
struct ComoTeAvisoView: View {
    let medicamentos: [Medicamento]
    let alTerminar: () -> Void

    @Environment(\.modelContext) private var contexto
    @Environment(\.openURL) private var abrirURL
    @State private var eleccion: [UUID: TipoAviso] = [:]
    @State private var guardando = false
    @State private var sinPermiso = false
    @State private var mensajePrueba: String?

    private let servicio = ServicioAvisosSistema.compartido

    var body: some View {
        Group {
            if sinPermiso {
                pantallaSinPermiso
            } else {
                pantallaEleccion
            }
        }
        .animation(.easeInOut(duration: 0.25), value: sinPermiso)
    }

    private var pantallaEleccion: some View {
        PantallaPregunta(titulo: "¿Cómo te aviso?",
                         subtitulo: "La alarma suena aunque tu iPhone esté en silencio.") {
            VStack(spacing: 16) {
                ForEach(medicamentos) { med in
                    tarjeta(med)
                }
            }
            if mostrarPrueba {
                VStack(alignment: .leading, spacing: 6) {
                    BotonGrande(titulo: "Probar aviso en 10 segundos", icono: "timer", estilo: .texto) {
                        Task { await probar() }
                    }
                    if let mensajePrueba {
                        Text(mensajePrueba)
                            .font(.body)
                            .foregroundStyle(Paleta.tintaSuave)
                            .frame(maxWidth: .infinity)
                            .multilineTextAlignment(.center)
                    }
                }
            }
        } botones: {
            BotonGrande(titulo: guardando ? "Guardando…" : "Listo", icono: "checkmark") {
                Task { await confirmar() }
            }
            .disabled(guardando)
            BotonGrande(titulo: "Ahora no", estilo: .texto, accion: alTerminar)
                .disabled(guardando)
        }
        .onAppear {
            for med in medicamentos where eleccion[med.id] == nil {
                eleccion[med.id] = med.aviso == .ninguno ? .alarma : med.aviso
            }
        }
    }

    private func tarjeta(_ med: Medicamento) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                IconoMedicamento(med, tamano: 52)
                VStack(alignment: .leading, spacing: 2) {
                    Text(med.nombreVisible.capitalizedPrimera)
                        .font(Tipo.tarjeta)
                        .foregroundStyle(Paleta.tinta)
                    Text(med.nombreTecnico)
                        .font(.body)
                        .foregroundStyle(Paleta.tintaSuave)
                }
            }
            .accessibilityElement(children: .combine)
            VStack(spacing: 10) {
                TarjetaOpcion(icono: "alarm.fill", titulo: "Alarma",
                              detalle: "Suena fuerte, con pantalla completa",
                              insignia: "Recomendada",
                              elegida: eleccion[med.id] == .alarma) {
                    eleccion[med.id] = .alarma
                }
                .accessibilityLabel("Alarma para \(med.nombreVisible). Recomendada")
                TarjetaOpcion(icono: "bell.fill", titulo: "Recordatorio",
                              detalle: "Una notificación, más suave",
                              elegida: eleccion[med.id] == .recordatorio) {
                    eleccion[med.id] = .recordatorio
                }
                .accessibilityLabel("Recordatorio para \(med.nombreVisible)")
            }
        }
        .tarjeta(relleno: 18, color: Paleta.hundido)
    }

    private var pantallaSinPermiso: some View {
        PantallaPregunta(titulo: "Tu plan está guardado, pero no podré avisarte",
                         subtitulo: "Para que suenen tus avisos, permite las alarmas y notificaciones en Ajustes.") {
            Image(systemName: "bell.slash.fill")
                .font(.system(size: 64))
                .foregroundStyle(Paleta.sePaso)
                .frame(width: 150, height: 150)
                .background(FormaOrganica().fill(Paleta.sePasoFondo))
                .frame(maxWidth: .infinity)
                .accessibilityHidden(true)
        } botones: {
            BotonGrande(titulo: "Abrir Ajustes", icono: "gearshape.fill") {
                if let url = URL(string: UIApplication.openSettingsURLString) { abrirURL(url) }
            }
            BotonGrande(titulo: "Seguir sin avisos", estilo: .secundario) { alTerminar() }
        }
    }

    /// Botón de demo (PRD A6): con datos de ejemplo o en DEBUG.
    private var mostrarPrueba: Bool {
        #if DEBUG
        return true
        #else
        return Almacen.perfil(en: contexto)?.esDemo == true
        #endif
    }

    private func confirmar() async {
        guardando = true
        defer { guardando = false }
        for med in medicamentos { med.aviso = eleccion[med.id] ?? .alarma }
        try? contexto.save()

        var negado = false
        for tipo in Set(medicamentos.map(\.aviso)) where tipo != .ninguno {
            if await servicio.pedirPermiso(para: tipo) == .negado { negado = true }
        }
        await Reprogramador.reprogramarTodo(contexto: contexto, servicio: servicio)
        if negado {
            sinPermiso = true
        } else {
            alTerminar()
        }
    }

    /// Adelanta a 10 segundos el aviso de la siguiente toma pendiente del primer medicamento.
    private func probar() async {
        guard let med = medicamentos.first, let perfil = Almacen.perfil(en: contexto) else { return }
        med.aviso = eleccion[med.id] ?? .alarma
        try? contexto.save()
        let permiso = await servicio.pedirPermiso(para: med.aviso)
        guard permiso == .concedido else {
            sinPermiso = true
            return
        }
        let tomas = Plan.tomas(de: med, perfil: perfil, desde: .now, dias: 2)
        let pendiente = tomas.first { Registro.registro(idToma: $0.id, contexto: contexto) == nil } ?? tomas.first
        guard let toma = pendiente else {
            mensajePrueba = "Este medicamento no tiene tomas hoy."
            return
        }
        do {
            try await servicio.programarPrueba(med, toma: toma)
            mensajePrueba = "Listo: \(med.nombreVisible) sonará en 10 segundos. Bloquea el iPhone para verlo en pantalla completa."
        } catch {
            mensajePrueba = "No se pudo programar: \(error.localizedDescription)"
        }
    }
}

#Preview {
    let c = Almacen.vistaPrevia()
    let meds = (try? c.mainContext.fetch(FetchDescriptor<Medicamento>())) ?? []
    return ComoTeAvisoView(medicamentos: meds) {}
        .modelContainer(c)
}
