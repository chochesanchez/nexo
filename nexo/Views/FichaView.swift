// FichaView.swift
import SwiftUI
import AVFoundation
import Combine
import SwiftData

private final class SpeechManager: NSObject, ObservableObject {
    @Published var isSpeaking = false
    private let synth = AVSpeechSynthesizer()
    override init() { super.init(); synth.delegate = self }
    func toggle(text: String) {
        if isSpeaking { synth.stopSpeaking(at: .immediate); isSpeaking = false }
        else {
            let utt = AVSpeechUtterance(string: text)
            utt.voice = AVSpeechSynthesisVoice(language: "es-MX"); utt.rate = 0.44
            synth.speak(utt); isSpeaking = true
        }
    }
    func stop() { synth.stopSpeaking(at: .immediate); isSpeaking = false }
}
extension SpeechManager: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { self.isSpeaking = false }
    }
}

struct FichaView: View {
    let material    : NEXOMaterial
    @Binding var isPresented: Bool
    @Environment(\.modelContext) private var context
    @StateObject private var speech = SpeechManager()
    @State private var iconIn    = false
    @State private var contentIn = false
    @State private var compartida = false

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: Sp.lg) {
                    routeBadge
                    instructionsCard
                    if let tip = material.smellTip { smellCard(tip) }
                    impactRow
                    valueRow
                }
                .padding(Sp.lg)
                .opacity(contentIn ? 1 : 0).offset(y: contentIn ? 0 : 18)
            }
            actionButtons
        }
        .ignoresSafeArea(edges: .top)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.1)) { iconIn = true }
            withAnimation(.easeOut(duration: 0.4).delay(0.35)) { contentIn = true }
        }
        .onDisappear { speech.stop() }
    }

    private var header: some View {
        ZStack(alignment: .bottom) {
            material.accent.ignoresSafeArea()
            VStack(spacing: Sp.md) {
                HStack {
                    Button { speech.stop(); isPresented = false } label: {
                        Image(systemName: "xmark").font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white).padding(10)
                            .background(.white.opacity(0.25), in: Circle())
                    }.accessibilityLabel("Cerrar")
                    Spacer()
                }.padding(.horizontal, Sp.lg).padding(.top, 60)
                Image(systemName: material.icon).font(.system(size: 62, weight: .light))
                    .foregroundStyle(.white).scaleEffect(iconIn ? 1 : 0.4).opacity(iconIn ? 1 : 0)
                    .accessibilityHidden(true)
                Text(material.displayName).font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white).accessibilityAddTraits(.isHeader)
                Spacer().frame(height: Sp.lg)
            }
        }.frame(height: 270)
    }

    private var routeBadge: some View {
        HStack(spacing: Sp.sm) {
            Image(systemName: material.route.icon).font(.system(size: 13, weight: .semibold))
            Text(material.route.rawValue).font(.system(size: 14, weight: .semibold))
        }
        .foregroundStyle(material.route.color).padding(.horizontal, 14).padding(.vertical, 8)
        .background(material.route.color.opacity(0.12), in: Capsule())
        .accessibilityLabel("Ruta: \(material.route.rawValue)")
    }

    private var instructionsCard: some View {
        VStack(alignment: .leading, spacing: Sp.sm) {
            sectionLabel("Cómo prepararlo")
            VStack(spacing: Sp.sm) {
                ForEach(Array(material.instructions.enumerated()), id: \.offset) { i, step in
                    HStack(alignment: .top, spacing: Sp.md) {
                        Text("\(i + 1)").font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(.white).frame(width: 22, height: 22)
                            .background(material.accent, in: Circle())
                        Text(step).font(.system(size: 15)).foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer()
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Paso \(i + 1): \(step)")
                }
            }
            .padding(Sp.md).background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: Rd.md))
        }
    }

    private func smellCard(_ tip: String) -> some View {
        HStack(alignment: .top, spacing: Sp.sm) {
            Image(systemName: "nose").font(.system(size: 16)).foregroundStyle(.orange)
            Text(tip).font(.system(size: 14)).foregroundStyle(.secondary)
        }
        .padding(Sp.md).background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: Rd.md))
        .accessibilityLabel("Tip de olor: \(tip)")
    }

    private var impactRow: some View {
        HStack(spacing: Sp.sm) {
            impactCell(icon: "wind", label: "CO₂ evitado", value: material.co2, color: Color.nexoGreen)
            if material.water != "—" {
                impactCell(icon: "drop.fill", label: "Agua ahorrada", value: material.water, color: Color.nexoBlue)
            }
        }
    }

    private func impactCell(icon: String, label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 11, weight: .semibold)).foregroundStyle(color)
                Text(label).font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
            }
            Text(value).font(.system(size: 17, weight: .bold, design: .rounded)).foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(Sp.md)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: Rd.md))
        .accessibilityElement(children: .combine).accessibilityLabel("\(label): \(value)")
    }

    private var valueRow: some View {
        HStack {
            Image(systemName: "tag.fill").foregroundStyle(Color.nexoAmber)
            Text("Valor estimado").font(.system(size: 14, weight: .medium)).foregroundStyle(.secondary)
            Spacer()
            Text(material.value).font(.system(size: 14, weight: .bold))
        }
        .padding(Sp.md).background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: Rd.md))
        .accessibilityElement(children: .combine).accessibilityLabel("Valor estimado: \(material.value)")
    }

    private var actionButtons: some View {
        VStack(spacing: Sp.sm) {
            Button {
                guard !compartida else { return }
                context.insert(FichaRegistro(material: material))
                withAnimation(.spring(response: 0.3)) { compartida = true }
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            } label: {
                Label(compartida ? "Ficha compartida ✓" : "Compartir ficha",
                      systemImage: compartida ? "checkmark.circle.fill" : "square.and.arrow.up")
                    .font(.system(size: 16, weight: .semibold)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 16)
                    .background(compartida ? Color.nexoGreen : Color.nexoDeep, in: RoundedRectangle(cornerRadius: Rd.pill))
            }
            .disabled(compartida)
            .accessibilityLabel(compartida ? "Ficha ya compartida" : "Compartir ficha con recolectores")

            Button { speech.toggle(text: material.voiceText) } label: {
                Label(speech.isSpeaking ? "Detener lectura" : "Leer en voz alta",
                      systemImage: speech.isSpeaking ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .font(.system(size: 15, weight: .semibold)).foregroundStyle(Color.nexoDeep)
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(Color.nexoDark.opacity(0.08), in: RoundedRectangle(cornerRadius: Rd.pill))
            }
            .accessibilityLabel(speech.isSpeaking ? "Detener lectura" : "Leer instrucciones en voz alta")
        }
        .padding(.horizontal, Sp.lg).padding(.vertical, Sp.md).padding(.bottom, 16)
        .background(.ultraThinMaterial)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text).font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary)
            .textCase(.uppercase).kerning(0.6).accessibilityAddTraits(.isHeader)
    }
}
