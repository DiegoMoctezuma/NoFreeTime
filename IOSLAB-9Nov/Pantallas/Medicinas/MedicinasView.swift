import SwiftUI
import SwiftData

/// "Tus medicinas" dentro de Perfil: cómo avisa cada una y dejar de tomarla.
struct SeccionMedicinas: View {
    @Query(filter: #Predicate<Medicamento> { $0.activo }, sort: \Medicamento.nombre) private var medicamentos: [Medicamento]
    @Environment(Navegacion.self) private var navegacion
    @State private var elegido: Medicamento?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Medicinas y cuidados").font(Tipo.tarjeta).foregroundStyle(Paleta.tinta)
                Spacer()
                Button {
                    navegacion.pestana = .escanear
                } label: {
                    Label("Agregar", systemImage: "plus")
                        .font(Tipo.etiqueta)
                        .foregroundStyle(Paleta.tinta)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 44)
                        .overlay(Capsule().strokeBorder(Paleta.borde, lineWidth: 1.2))
                }
            }
            if medicamentos.isEmpty {
                Text("Aquí verás tus medicinas y cuidados con horario.")
                    .font(.body)
                    .foregroundStyle(Paleta.tintaSuave)
                    .tarjeta()
            }
            ForEach(medicamentos) { med in
                Button { elegido = med } label: { TarjetaMedicina(med: med) }
                    .buttonStyle(EstiloPresionable())
            }
        }
        .sheet(item: $elegido) { med in
            DetalleMedicinaView(med: med)
        }
    }
}

struct TarjetaMedicina: View {
    let med: Medicamento

    @ViewBuilder private var etiquetas: some View {
        etiquetaAviso
        if let fin = med.fin {
            Label("Hasta el \(fin.formatted(.dateTime.day().month(.wide).locale(Locale(identifier: "es_MX"))))",
                  systemImage: "calendar")
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            IconoMedicamento(med, tamano: 60)
            VStack(alignment: .leading, spacing: 6) {
                Text(med.nombreVisible.capitalizedPrimera)
                    .font(.system(.title3, design: .serif, weight: .semibold))
                    .foregroundStyle(Paleta.tinta)
                    .fixedSize(horizontal: false, vertical: true)
                if med.apodo != nil {
                    Text(med.nombreTecnico)
                        .font(.body)
                        .foregroundStyle(Paleta.tintaSuave)
                }
                Text([med.dosis, med.textoPauta].filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.body)
                    .foregroundStyle(Paleta.tinta)
                    .fixedSize(horizontal: false, vertical: true)
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) { etiquetas }
                    VStack(alignment: .leading, spacing: 6) { etiquetas }
                }
                .font(.body.weight(.semibold))
                .foregroundStyle(Paleta.tintaSuave)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "chevron.right")
                .foregroundStyle(Paleta.tintaSuave)
                .accessibilityHidden(true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(RoundedRectangle(cornerRadius: Radio.control + 4, style: .continuous).strokeBorder(Paleta.borde, lineWidth: 1.2))
        .contentShape(RoundedRectangle(cornerRadius: Radio.control + 4, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private var etiquetaAviso: some View {
        switch med.aviso {
        case .alarma: Label("Alarma", systemImage: "alarm")
        case .recordatorio: Label("Recordatorio", systemImage: "bell")
        case .ninguno: Label("Sin aviso", systemImage: "bell.slash")
        }
    }
}

/// Detalle: cambiar el aviso o dejar de tomarla.
struct DetalleMedicinaView: View {
    @Bindable var med: Medicamento

    @Environment(\.modelContext) private var contexto
    @Environment(\.dismiss) private var cerrar
    @Environment(\.openURL) private var abrirURL
    @State private var confirmarQuitar = false
    @State private var sinPermiso = false

    private let servicio = ServicioAvisosSistema.compartido

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack(spacing: 16) {
                    IconoMedicamento(med, tamano: 84)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(med.nombreVisible.capitalizedPrimera)
                            .font(Tipo.titulo)
                            .foregroundStyle(Paleta.tinta)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(med.nombreTecnico)
                            .font(.body)
                            .foregroundStyle(Paleta.tintaSuave)
                    }
                }
                .accessibilityElement(children: .combine)

                VStack(alignment: .leading, spacing: 10) {
                    Text("¿Cómo te aviso?")
                        .font(Tipo.seccion)
                        .foregroundStyle(Paleta.tinta)
                    TarjetaOpcion(icono: "alarm", titulo: "Alarma",
                                  detalle: "Suena aunque esté en silencio",
                                  elegida: med.aviso == .alarma) { cambiarAviso(.alarma) }
                    TarjetaOpcion(icono: "bell", titulo: "Recordatorio",
                                  detalle: "Una notificación, más suave",
                                  elegida: med.aviso == .recordatorio) { cambiarAviso(.recordatorio) }
                    if sinPermiso {
                        Button {
                            if let url = URL(string: UIApplication.openSettingsURLString) { abrirURL(url) }
                        } label: {
                            Label("No tengo permiso para avisarte. Toca para abrir Ajustes.", systemImage: "bell.slash")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(Paleta.sePaso)
                                .tarjeta(relleno: 16, color: Paleta.sePasoFondo)
                        }
                        .buttonStyle(.plain)
                    }
                }

                BotonGrande(titulo: "Quitar del plan", icono: "xmark", estilo: .secundario) { confirmarQuitar = true }
                    .confirmationDialog("¿Quitar \(med.nombreVisible) de tu plan?",
                                        isPresented: $confirmarQuitar, titleVisibility: .visible) {
                        Button("Quitar del plan", role: .destructive, action: quitar)
                        Button("Cancelar", role: .cancel) {}
                    } message: {
                        Text("Los avisos de esta indicación se cancelarán.")
                    }
            }
            .padding(24)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(32)
        .presentationBackground(Paleta.fondo)
    }

    private func cambiarAviso(_ tipo: TipoAviso) {
        med.aviso = tipo
        try? contexto.save()
        Task {
            sinPermiso = await servicio.pedirPermiso(para: tipo) == .negado
            await Reprogramador.reprogramarTodo(contexto: contexto, servicio: servicio)
        }
    }

    private func quitar() {
        med.activo = false
        try? contexto.save()
        let id = med.id
        Task { await servicio.cancelar(medicamentoID: id) }
        cerrar()
    }
}

/// "Notas de tus recetas" en Perfil: lo que la receta decía además de las medicinas.
struct SeccionNotas: View {
    @Query(sort: \NotaReceta.fecha, order: .reverse) private var notas: [NotaReceta]
    @Environment(\.modelContext) private var contexto
    @State private var porBorrar: NotaReceta?

    var body: some View {
        if !notas.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Notas de tus recetas").font(Tipo.tarjeta).foregroundStyle(Paleta.tinta)
                ForEach(notas) { nota in
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(nota.texto.capitalizedPrimera)
                                .font(.body)
                                .foregroundStyle(Paleta.tinta)
                                .fixedSize(horizontal: false, vertical: true)
                            Text("Receta del \(nota.fecha.formatted(.dateTime.day().month(.wide).locale(Locale(identifier: "es_MX"))))")
                                .font(.body)
                                .foregroundStyle(Paleta.tinta)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        Button { Voz.decir(nota.texto) } label: {
                            Image(systemName: "speaker.wave.2").frame(width: 44, height: 44)
                        }
                        .accessibilityLabel("Leer en voz alta")
                        Button { porBorrar = nota } label: {
                            Image(systemName: "trash").frame(width: 44, height: 44)
                        }
                        .accessibilityLabel("Borrar nota")
                    }
                    .foregroundStyle(Paleta.tinta)
                    .tarjeta(relleno: 16, color: Paleta.sol.opacity(0.45))
                }
            }
            .confirmationDialog("¿Borrar esta nota?", isPresented: Binding(get: { porBorrar != nil }, set: { if !$0 { porBorrar = nil } }),
                                titleVisibility: .visible) {
                Button("Borrar", role: .destructive) {
                    if let n = porBorrar { contexto.delete(n); try? contexto.save() }
                    porBorrar = nil
                }
                Button("Cancelar", role: .cancel) { porBorrar = nil }
            }
        }
    }
}
