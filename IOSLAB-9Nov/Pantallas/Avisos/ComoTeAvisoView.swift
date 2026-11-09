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
        if sinPermiso {
            pantallaSinPermiso
        } else {
            pantallaEleccion
        }
    }

    private var pantallaEleccion: some View {
        PantallaPregunta(titulo: "¿Cómo te aviso?",
                         subtitulo: "La alarma suena aunque tu iPhone esté en silencio.") {
            ForEach(medicamentos) { med in
                tarjeta(med)
            }
            if mostrarPrueba {
                VStack(alignment: .leading, spacing: 8) {
                    BotonGrande(titulo: "Probar aviso en 1 minuto", icono: "timer", estilo: .secundario) {
                        Task { await probar() }
                    }
                    if let mensajePrueba {
                        Text(mensajePrueba).font(.body).foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 8)
            }
        } botones: {
            BotonGrande(titulo: guardando ? "Guardando…" : "Listo", icono: "checkmark") {
                Task { await confirmar() }
            }
            .disabled(guardando)
        }
        .onAppear {
            for med in medicamentos where eleccion[med.id] == nil {
                eleccion[med.id] = med.aviso == .ninguno ? .alarma : med.aviso
            }
        }
    }

    private func tarjeta(_ med: Medicamento) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Circle().fill(Color(hex: med.colorHex)).frame(width: 24, height: 24).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(med.nombreVisible.capitalizedPrimera).font(.title2.bold())
                    Text(med.nombreTecnico).font(.subheadline).foregroundStyle(.secondary)
                }
            }
            HStack(spacing: 12) {
                opcion(.alarma, med: med, icono: "alarm.fill", nota: "Recomendada")
                opcion(.recordatorio, med: med, icono: "bell.fill", nota: "Más suave")
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Paleta.tarjeta, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func opcion(_ tipo: TipoAviso, med: Medicamento, icono: String, nota: String) -> some View {
        let elegida = eleccion[med.id] == tipo
        return Button {
            eleccion[med.id] = tipo
        } label: {
            VStack(spacing: 6) {
                Image(systemName: elegida ? "checkmark.circle.fill" : icono).font(.title2)
                Text(tipo.titulo).font(.headline)
                Text(nota).font(.footnote)
            }
            .frame(maxWidth: .infinity, minHeight: 88)
            .padding(8)
            .foregroundStyle(elegida ? Color.white : Color.primary)
            .background(elegida ? Color.accentColor : Paleta.fondo,
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.primary.opacity(elegida ? 0 : 0.5), lineWidth: 2))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(tipo.titulo) para \(med.nombreVisible). \(nota)")
        .accessibilityAddTraits(elegida ? .isSelected : [])
    }

    private var pantallaSinPermiso: some View {
        PantallaPregunta(titulo: "Tu plan está guardado, pero no podré avisarte",
                         subtitulo: "Para que suenen tus avisos, permite las alarmas y notificaciones en Ajustes.") {
            Image(systemName: "bell.slash.fill")
                .font(.system(size: 64))
                .foregroundStyle(Paleta.sePaso)
                .frame(maxWidth: .infinity)
                .accessibilityHidden(true)
        } botones: {
            BotonGrande(titulo: "Abrir Ajustes", icono: "gearshape") {
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

    /// Adelanta a 1 minuto el aviso de la siguiente toma pendiente de hoy del primer medicamento.
    private func probar() async {
        guard let med = medicamentos.first, let perfil = Almacen.perfil(en: contexto) else { return }
        med.aviso = eleccion[med.id] ?? .alarma
        try? contexto.save()
        let permiso = await servicio.pedirPermiso(para: med.aviso)
        guard permiso == .concedido else {
            sinPermiso = true
            return
        }
        let tomas = Plan.tomas(de: med, perfil: perfil, desde: .now, dias: 1)
        let pendiente = tomas.first { Registro.registro(idToma: $0.id, contexto: contexto) == nil } ?? tomas.first
        guard let toma = pendiente else {
            mensajePrueba = "Este medicamento no tiene tomas hoy."
            return
        }
        do {
            try await servicio.programarPrueba(med, toma: toma)
            mensajePrueba = "Listo: \(med.nombreVisible) sonará en 1 minuto. Bloquea el iPhone para verlo."
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
