import SwiftUI
import SwiftData
import CoreLocation

// MARK: - RecoleccionDetailView

struct RecoleccionDetailView: View {
    let registros: [RecoleccionRegistro]
    @State var currentIndex: Int
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemGroupedBackground).ignoresSafeArea()

                TabView(selection: $currentIndex) {
                    ForEach(Array(registros.enumerated()), id: \.element.uuid) { idx, reg in
                        RecoleccionDetailContent(registro: reg)
                            .tag(idx)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .ignoresSafeArea(edges: .bottom)

                arrowOverlay
            }
            .navigationTitle("Recolección \(currentIndex + 1) de \(registros.count)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cerrar") { isPresented = false }
                        .foregroundStyle(Color.nexoBrand)
                }
            }
        }
    }

    private var arrowOverlay: some View {
        VStack {
            Spacer()
            HStack {
                arrowButton(direction: .left)
                Spacer()
                arrowButton(direction: .right)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }

    private enum ArrowDirection { case left, right }
    private func arrowButton(direction: ArrowDirection) -> some View {
        let isLeft = direction == .left
        let canMove = isLeft ? currentIndex > 0 : currentIndex < registros.count - 1
        return Button {
            withAnimation(.easeInOut(duration: 0.25)) {
                currentIndex += isLeft ? -1 : 1
            }
            UISelectionFeedbackGenerator().selectionChanged()
        } label: {
            Image(systemName: isLeft ? "chevron.left" : "chevron.right")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(canMove ? Color.nexoForest : Color(uiColor: .tertiaryLabel))
                .frame(width: 52, height: 52)
                .background(.ultraThinMaterial, in: Circle())
                .overlay(Circle().strokeBorder(Color(uiColor: .separator), lineWidth: 0.5))
                .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
        }
        .disabled(!canMove)
        .opacity(canMove ? 1 : 0.4)
    }
}

// MARK: - RecoleccionDetailContent

struct RecoleccionDetailContent: View {
    @Bindable var registro: RecoleccionRegistro
    @Environment(\.modelContext) private var context

    @StateObject private var speech = HistorialSpeech()
    @State private var notasDraft: String = ""
    @State private var isEditingNotas = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                imageHero
                materialHeader
                routeBadge
                metaCard
                instruccionCard
                metricsRow
                valueCard
                notasCard
                voiceButton
                Spacer(minLength: 100)
            }
        }
        .onAppear {
            notasDraft = registro.notas ?? ""
            resolveLocationIfNeeded()
        }
        .onDisappear {
            persistNotasIfChanged()
            speech.stop()
        }
    }

    // MARK: - Image hero

    @ViewBuilder
    private var imageHero: some View {
        ZStack(alignment: .bottomLeading) {
            if let data = registro.imageData, let uiImg = UIImage(data: data) {
                Image(uiImage: uiImg)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 300)
                    .clipped()
            } else {
                ZStack {
                    Rectangle().fill(Color(uiColor: .systemGray5))
                        .frame(height: 300)
                    VStack(spacing: 8) {
                        Image(systemName: "photo")
                            .font(.system(size: 36, weight: .ultraLight))
                            .foregroundStyle(Color(uiColor: .tertiaryLabel))
                        Text("Sin imagen disponible")
                            .font(.system(size: 12, weight: .light))
                            .foregroundStyle(Color(uiColor: .secondaryLabel))
                    }
                }
            }
            LinearGradient(colors: [.clear, .black.opacity(0.4)], startPoint: .center, endPoint: .bottom)
                .frame(height: 300)
                .allowsHitTesting(false)
        }
    }

    // MARK: - Material header

    private var materialHeader: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(materialAccent.opacity(0.12))
                    .frame(width: 56, height: 56)
                Image(systemName: registro.icon)
                    .font(.system(size: 22, weight: .light))
                    .foregroundStyle(materialAccent)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(registro.classKey.uppercased())
                    .font(.system(size: 9, weight: .semibold)).tracking(2)
                    .foregroundStyle(Color(uiColor: .secondaryLabel))
                Text(registro.displayName)
                    .font(.system(size: 24, weight: .bold)).tracking(-0.8)
                    .foregroundStyle(Color(uiColor: .label))
            }
            Spacer()
        }
        .padding(.horizontal, Sp.lg)
        .padding(.top, Sp.md)
        .padding(.bottom, Sp.md)
    }

    private var materialAccent: Color {
        NEXOMaterial.all[registro.classKey]?.accent ?? Color.nexoForest
    }

    // MARK: - Route badge

    private var routeBadge: some View {
        let routeIcon: String = {
            if registro.route.contains("Composta") { return "leaf.fill" }
            if registro.route.contains("acopio")   { return "exclamationmark.triangle.fill" }
            return "arrow.3.trianglepath"
        }()
        return HStack(spacing: 8) {
            Image(systemName: routeIcon)
                .font(.system(size: 12, weight: .semibold))
            Text(registro.route.isEmpty ? "Recolectado" : registro.route)
                .font(.system(size: 13, weight: .semibold))
        }
        .foregroundStyle(Color.nexoBrand)
        .padding(.horizontal, Sp.lg)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .systemBackground))
    }

    // MARK: - Meta card

    private var metaCard: some View {
        VStack(spacing: 0) {
            metaRow(
                icon : "calendar",
                label: "Fecha",
                value: registro.fecha.formatted(date: .complete, time: .shortened)
            )
            Divider().padding(.leading, 52)
            metaRow(
                icon : "mappin.and.ellipse",
                label: "Ubicación",
                value: registro.locationName ?? coordinateString
            )
        }
        .background(Color(uiColor: .systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: Rd.lg))
        .overlay(RoundedRectangle(cornerRadius: Rd.lg).strokeBorder(Color(uiColor: .separator), lineWidth: 0.5))
        .padding(.horizontal, Sp.lg)
        .padding(.top, 4)
    }

    private func metaRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(Color.nexoBrand)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 10, weight: .semibold)).tracking(0.5)
                    .textCase(.uppercase)
                    .foregroundStyle(Color(uiColor: .secondaryLabel))
                Text(value)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(Color(uiColor: .label))
            }
            Spacer()
        }
        .padding(Sp.md)
    }

    private var coordinateString: String {
        String(format: "%.4f, %.4f", registro.lat, registro.lng)
    }

    // MARK: - Instruction

    private var instruccionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Preparación")
                .font(.system(size: 11, weight: .semibold)).tracking(0.3)
                .foregroundStyle(Color(uiColor: .secondaryLabel))
            Text(registro.instructions.isEmpty
                 ? "Sin instrucciones registradas."
                 : registro.instructions.joined(separator: " "))
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(Color(uiColor: .label))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Sp.lg)
        .background(Color(uiColor: .systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: Rd.lg))
        .overlay(RoundedRectangle(cornerRadius: Rd.lg).strokeBorder(Color(uiColor: .separator), lineWidth: 0.5))
        .padding(.horizontal, Sp.lg)
        .padding(.top, Sp.sm)
    }

    // MARK: - Metrics

    private var metricsRow: some View {
        HStack(spacing: 0) {
            metricCell(label: "CO₂ evitado", value: registro.co2Raw, color: Color.nexoBrand)
        }
        .background(Color(uiColor: .systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: Rd.lg))
        .overlay(RoundedRectangle(cornerRadius: Rd.lg).strokeBorder(Color(uiColor: .separator), lineWidth: 0.5))
        .padding(.horizontal, Sp.lg)
        .padding(.top, Sp.sm)
    }

    private func metricCell(label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).font(.system(size: 10, weight: .semibold)).tracking(0.3)
                .foregroundStyle(Color(uiColor: .secondaryLabel))
            Text(value).font(.system(size: 22, weight: .bold)).tracking(-0.5).foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Sp.lg).padding(.vertical, Sp.md)
    }

    private var valueCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("Valor estimado")
                    .font(.system(size: 10, weight: .semibold)).tracking(0.3)
                    .foregroundStyle(Color(uiColor: .secondaryLabel))
                Text(registro.value)
                    .font(.system(size: 18, weight: .bold)).tracking(-0.3)
                    .foregroundStyle(Color(hex: "7A5F00"))
            }
            Spacer()
            Rectangle().fill(Color.nexoAmber).frame(width: 4, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 2))
        }
        .padding(.horizontal, Sp.lg)
        .padding(.vertical, Sp.md)
        .background(Color(hex: "FFFCE8"))
        .clipShape(RoundedRectangle(cornerRadius: Rd.lg))
        .padding(.horizontal, Sp.lg)
        .padding(.top, Sp.sm)
    }

    // MARK: - Notas

    private var notasCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Notas")
                    .font(.system(size: 11, weight: .semibold)).tracking(0.3)
                    .foregroundStyle(Color(uiColor: .secondaryLabel))
                Spacer()
                if isEditingNotas {
                    Button("Guardar") {
                        persistNotasIfChanged()
                        isEditingNotas = false
                        UISelectionFeedbackGenerator().selectionChanged()
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.nexoBrand)
                } else {
                    Button(notasDraft.isEmpty ? "Agregar nota" : "Editar") {
                        isEditingNotas = true
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.nexoBrand)
                }
            }

            if isEditingNotas {
                TextEditor(text: $notasDraft)
                    .font(.system(size: 14))
                    .frame(minHeight: 80, maxHeight: 160)
                    .padding(8)
                    .background(Color(uiColor: .systemBackground), in: RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.nexoBrand.opacity(0.3), lineWidth: 1))
            } else {
                Text(notasDraft.isEmpty ? "Sin notas. Toca \"Agregar nota\" para escribir algo sobre esta recolección." : notasDraft)
                    .font(.system(size: 14, weight: notasDraft.isEmpty ? .light : .regular))
                    .foregroundStyle(notasDraft.isEmpty ? Color(uiColor: .tertiaryLabel) : Color(uiColor: .label))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color(uiColor: .systemBackground), in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(Sp.lg)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: Rd.lg))
        .padding(.horizontal, Sp.lg)
        .padding(.top, Sp.sm)
    }

    // MARK: - Voice

    private var voiceButton: some View {
        Button { speech.toggle(text: voiceText) } label: {
            HStack(spacing: 8) {
                Image(systemName: speech.isSpeaking ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .font(.system(size: 14, weight: .semibold))
                Text(speech.isSpeaking ? "Detener" : "Leer en voz alta")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(Color.nexoForest, in: RoundedRectangle(cornerRadius: Rd.lg))
            .shadow(color: Color.nexoForest.opacity(0.2), radius: 8, y: 3)
        }
        .padding(.horizontal, Sp.lg)
        .padding(.top, Sp.md)
    }

    private var voiceText: String {
        var t = "\(registro.displayName). "
        if !registro.route.isEmpty { t += "Ruta: \(registro.route). " }
        if !registro.instructions.isEmpty {
            t += registro.instructions.joined(separator: " ")
        }
        t += " Valor estimado: \(registro.value)."
        if let n = registro.notas, !n.isEmpty { t += " Nota: \(n)." }
        return t
    }

    // MARK: - Helpers

    private func persistNotasIfChanged() {
        if (registro.notas ?? "") != notasDraft {
            registro.notas = notasDraft
            try? context.save()
        }
    }

    private func resolveLocationIfNeeded() {
        guard registro.locationName == nil else { return }
        let loc = CLLocation(latitude: registro.lat, longitude: registro.lng)
        let geocoder = CLGeocoder()
        Task {
            do {
                let placemarks = try await geocoder.reverseGeocodeLocation(loc)
                if let p = placemarks.first {
                    let parts = [p.thoroughfare, p.subLocality, p.locality]
                        .compactMap { $0 }
                        .filter { !$0.isEmpty }
                    let resolved = parts.joined(separator: ", ")
                    if !resolved.isEmpty {
                        await MainActor.run {
                            registro.locationName = resolved
                            try? context.save()
                        }
                    }
                }
            } catch {
                // silent fail
            }
        }
    }
}
