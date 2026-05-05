import SwiftUI
import SwiftData
import CoreLocation
import AVFoundation
import Combine

// MARK: - Speech manager

@MainActor
final class HistorialSpeech: NSObject, ObservableObject {
    @Published var isSpeaking = false
    private let synth = AVSpeechSynthesizer()
    override init() { super.init(); synth.delegate = self }

    func toggle(text: String) {
        if isSpeaking {
            synth.stopSpeaking(at: .immediate)
            isSpeaking = false
        } else {
            let utt = AVSpeechUtterance(string: text)
            utt.voice = AVSpeechSynthesisVoice(language: "es-MX")
            utt.rate = 0.44
            synth.speak(utt)
            isSpeaking = true
        }
    }
    func stop() { synth.stopSpeaking(at: .immediate); isSpeaking = false }
}
extension HistorialSpeech: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ s: AVSpeechSynthesizer, didFinish u: AVSpeechUtterance) {
        Task { @MainActor in self.isSpeaking = false }
    }
}

// MARK: - FichaDetailView

struct FichaDetailView: View {
    let fichas: [FichaRegistro]
    @State var currentIndex: Int
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemGroupedBackground).ignoresSafeArea()

                TabView(selection: $currentIndex) {
                    ForEach(Array(fichas.enumerated()), id: \.element.persistentModelID) { idx, ficha in
                        FichaDetailContent(ficha: ficha)
                            .tag(idx)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .ignoresSafeArea(edges: .bottom)

                arrowOverlay
            }
            .navigationTitle("Ficha \(currentIndex + 1) de \(fichas.count)")
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
        let canMove = isLeft ? currentIndex > 0 : currentIndex < fichas.count - 1
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

// MARK: - FichaDetailContent

struct FichaDetailContent: View {
    @Bindable var ficha: FichaRegistro
    @Environment(\.modelContext) private var context

    @StateObject private var speech = HistorialSpeech()
    @State private var notasDraft: String = ""
    @State private var isEditingNotas = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                imageHero
                statusBadge
                materialHeader
                routeBadge
                metaCard
                instruccionCard
                if let ocr = ficha.ocrText, !ocr.isEmpty { ocrCard(ocr) }
                metricsRow
                valueCard
                notasCard
                voiceButton
                Spacer(minLength: 100)
            }
        }
        .onAppear {
            notasDraft = ficha.notas ?? ""
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
            if let data = ficha.imageData, let uiImg = UIImage(data: data) {
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

    // MARK: - Status badge

    private var statusBadge: some View {
        HStack {
            HStack(spacing: 6) {
                Circle().fill(estadoColor).frame(width: 6, height: 6)
                Text(estadoLabel)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(estadoColor)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(estadoColor.opacity(0.1), in: Capsule())
            Spacer()
        }
        .padding(.horizontal, Sp.lg)
        .padding(.top, Sp.md)
        .padding(.bottom, 4)
    }

    private var estadoColor: Color {
        switch ficha.estado {
        case "pendiente": return Color.nexoAmber
        case "activa":    return Color.nexoGreen
        case "recogida":  return Color.nexoBrand
        default:          return Color(uiColor: .secondaryLabel)
        }
    }

    private var estadoLabel: String {
        switch ficha.estado {
        case "pendiente": return "Por compartir"
        case "activa":    return "En el mapa"
        case "recogida":  return "Recogida"
        default:          return ficha.estado
        }
    }

    // MARK: - Material header

    private var materialHeader: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(materialAccent.opacity(0.12))
                    .frame(width: 56, height: 56)
                Image(systemName: ficha.icon)
                    .font(.system(size: 22, weight: .light))
                    .foregroundStyle(materialAccent)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(ficha.classKey.uppercased())
                    .font(.system(size: 9, weight: .semibold)).tracking(2)
                    .foregroundStyle(Color(uiColor: .secondaryLabel))
                Text(ficha.displayName)
                    .font(.system(size: 24, weight: .bold)).tracking(-0.8)
                    .foregroundStyle(Color(uiColor: .label))
            }
            Spacer()
        }
        .padding(.horizontal, Sp.lg)
        .padding(.bottom, Sp.md)
    }

    private var materialAccent: Color {
        NEXOMaterial.all[ficha.classKey]?.accent ?? Color.nexoForest
    }

    // MARK: - Route badge

    private var routeBadge: some View {
        let routeIcon: String = {
            if ficha.route.contains("Composta")  { return "leaf.fill" }
            if ficha.route.contains("acopio")    { return "exclamationmark.triangle.fill" }
            return "arrow.3.trianglepath"
        }()
        return HStack(spacing: 8) {
            Image(systemName: routeIcon)
                .font(.system(size: 12, weight: .semibold))
            Text(ficha.route)
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
                value: ficha.fecha.formatted(date: .complete, time: .shortened)
            )
            Divider().padding(.leading, 52)
            metaRow(
                icon : "mappin.and.ellipse",
                label: "Ubicación",
                value: ficha.locationName ?? coordinateString
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
        String(format: "%.4f, %.4f", ficha.lat, ficha.lng)
    }

    // MARK: - Instruction

    private var instruccionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Preparación")
                .font(.system(size: 11, weight: .semibold)).tracking(0.3)
                .foregroundStyle(Color(uiColor: .secondaryLabel))
            Text(ficha.instruccionFM ?? "Vacíalo, enjuágalo y prepáralo según su tipo.")
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

    // MARK: - OCR

    private func ocrCard(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "text.viewfinder")
                .font(.system(size: 13))
                .foregroundStyle(Color.nexoBlue)
            VStack(alignment: .leading, spacing: 3) {
                Text("Texto detectado en etiqueta")
                    .font(.system(size: 10, weight: .semibold)).tracking(0.5)
                    .foregroundStyle(Color(uiColor: .secondaryLabel))
                Text(text)
                    .font(.system(size: 14))
                    .foregroundStyle(Color(uiColor: .label))
            }
        }
        .padding(Sp.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.nexoBlue.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: Rd.lg))
        .padding(.horizontal, Sp.lg)
        .padding(.top, Sp.sm)
    }

    // MARK: - Metrics

    private var metricsRow: some View {
        HStack(spacing: 0) {
            metricCell(label: "CO₂ evitado", value: ficha.co2, color: Color.nexoBrand)
            if ficha.water != "—" {
                Divider().frame(height: 48)
                metricCell(label: "Agua ahorrada", value: ficha.water, color: Color.nexoBlue)
            }
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
                Text(ficha.value)
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
                Text(notasDraft.isEmpty ? "Sin notas. Toca \"Agregar nota\" para escribir algo sobre este escaneo." : notasDraft)
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
        var t = "\(ficha.displayName). Ruta: \(ficha.route). "
        t += ficha.instruccionFM ?? "Prepáralo según las instrucciones."
        t += " Valor estimado: \(ficha.value)."
        if let n = ficha.notas, !n.isEmpty { t += " Nota: \(n)." }
        return t
    }

    // MARK: - Helpers

    private func persistNotasIfChanged() {
        if (ficha.notas ?? "") != notasDraft {
            ficha.notas = notasDraft
            try? context.save()
        }
    }

    private func resolveLocationIfNeeded() {
        guard ficha.locationName == nil else { return }
        let loc = CLLocation(latitude: ficha.lat, longitude: ficha.lng)
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
                            ficha.locationName = resolved
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
