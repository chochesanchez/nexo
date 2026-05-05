// ScannerView.swift — Rediseño Bateman/Apple
import SwiftUI
import AVFoundation

struct ScannerView: View {
    @Binding var appMode: AppMode
    @StateObject private var camera = CameraManager()
    @State private var showFicha = false
    @State private var btnScale: CGFloat = 1
    @State private var pulse = false

    var body: some View {
        ZStack {
            // Cámara full bleed
            CameraPreview(session: camera.session).ignoresSafeArea()

            // Gradientes de vignette — mínimos
            VStack {
                LinearGradient(
                    colors: [.black.opacity(0.6), .clear],
                    startPoint: .top, endPoint: .bottom
                ).frame(height: 140)
                Spacer()
                LinearGradient(
                    colors: [.clear, .black.opacity(0.7)],
                    startPoint: .top, endPoint: .bottom
                ).frame(height: 220)
            }.ignoresSafeArea()

            // UI
            VStack(spacing: 0) {
                topBar
                Spacer()
                viewfinder
                Spacer()
                bottomControls
            }
        }
        .onAppear    { camera.start() }
        .onDisappear { camera.stop()  }
        .onChange(of: camera.detectedMaterial) { _, mat in
            if mat != nil { showFicha = true }
        }
        .fullScreenCover(isPresented: $showFicha) {
            if let mat = camera.detectedMaterial {
                FichaView(
                    material    : mat,
                    ocrText     : camera.detectedOCRText,
                    imageData   : camera.capturedImageData,
                    isPresented : $showFicha
                )
                .onDisappear {
                    camera.detectedMaterial  = nil
                    camera.detectedOCRText   = nil
                    camera.capturedImageData = nil
                }
            }
        }
        .alert("Intenta de nuevo", isPresented: .constant(camera.errorMessage != nil)) {
            Button("OK") { camera.errorMessage = nil }
        } message: { Text(camera.errorMessage ?? "") }
    }

    // MARK: - Top bar
    private var topBar: some View {
        HStack {
            Text("NEXO")
                .font(.system(size: 20, weight: .black))
                .tracking(-1.5)
                .foregroundStyle(.white)
                .accessibilityAddTraits(.isHeader)

            Spacer()

            // Mode toggle — rectangular, no Capsule
            HStack(spacing: 1) {
                ForEach(AppMode.allCases, id: \.self) { mode in
                    Button {
                        withAnimation(.easeOut(duration: 0.2)) { appMode = mode }
                    } label: {
                        Text(mode.rawValue)
                            .font(.system(size: 10, weight: .semibold))
                            .tracking(0.5)
                            .foregroundStyle(appMode == mode ? Color.nexoBlack : Color.white.opacity(0.4))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(
                                appMode == mode
                                ? Color.white.opacity(0.92)
                                : Color.clear
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    .accessibilityLabel("Modo \(mode.rawValue)")
                }
            }
            .padding(2)
            .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
        }
        .padding(.horizontal, Sp.lg)
        .padding(.top, Sp.lg)
    }

    // MARK: - Viewfinder — solo esquinas, sin caja
    private var viewfinder: some View {
        ZStack {
            // Solo las 4 esquinas en ámbar, sin RoundedRectangle
            CornerFrame(size: 150, cornerLen: 20, color: Color.nexoAmber.opacity(0.9), lw: 2)
                .scaleEffect(pulse ? 1.03 : 1)
                .animation(
                    .easeInOut(duration: 2).repeatForever(autoreverses: true),
                    value: pulse
                )
                .onAppear { pulse = true }

            // Estado de análisis
            if camera.isAnalyzing {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black.opacity(0.7))
                    .frame(width: 150, height: 150)
                    .overlay {
                        VStack(spacing: 10) {
                            ProgressView().tint(.white).scaleEffect(1.2)
                            Text("Identificando")
                                .font(.system(size: 11, weight: .medium))
                                .tracking(0.5)
                                .foregroundStyle(Color.white.opacity(0.7))
                        }
                    }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(camera.isAnalyzing ? "Analizando residuo" : "Visor de cámara")
    }

    // MARK: - Bottom controls
    private var bottomControls: some View {
        VStack(spacing: 20) {
            // Hint text
            Text(camera.isAnalyzing ? "Identificando material…" : "Apunta al residuo y toca el botón")
                .font(.system(size: 11, weight: .regular))
                .tracking(0.3)
                .foregroundStyle(Color.white.opacity(0.4))
                .multilineTextAlignment(.center)

            // Botón de captura — círculo ámbar limpio
            Button {
                guard !camera.isAnalyzing else { return }
                withAnimation(.spring(response: 0.18, dampingFraction: 0.5)) { btnScale = 0.88 }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                    withAnimation(.spring(response: 0.3)) { btnScale = 1 }
                    camera.capture()
                }
            } label: {
                ZStack {
                    // Halo exterior
                    Circle()
                        .strokeBorder(Color.nexoAmber.opacity(0.25), lineWidth: 1)
                        .frame(width: 68, height: 68)

                    // Botón principal
                    Circle()
                        .fill(Color.nexoAmber)
                        .frame(width: 56, height: 56)
                        .overlay {
                            if camera.isAnalyzing {
                                ProgressView().tint(Color.nexoBlack).scaleEffect(0.8)
                            } else {
                                Circle()
                                    .strokeBorder(Color.nexoBlack.opacity(0.2), lineWidth: 2)
                                    .frame(width: 36, height: 36)
                            }
                        }
                }
            }
            .scaleEffect(btnScale)
            .disabled(camera.isAnalyzing)
            .accessibilityLabel("Escanear residuo")
        }
        .padding(.bottom, 52)
    }
}

// MARK: - CornerFrame (sin cambios, ya era correcto)
struct CornerFrame: View {
    let size: CGFloat; let cornerLen: CGFloat; let color: Color; let lw: CGFloat
    var body: some View {
        Canvas { ctx, sz in
            let w = sz.width, h = sz.height, c = cornerLen
            let corners: [(CGPoint, CGPoint, CGPoint)] = [
                (CGPoint(x: 0,   y: c),   CGPoint(x: 0, y: 0),   CGPoint(x: c,   y: 0)),
                (CGPoint(x: w-c, y: 0),   CGPoint(x: w, y: 0),   CGPoint(x: w,   y: c)),
                (CGPoint(x: 0,   y: h-c), CGPoint(x: 0, y: h),   CGPoint(x: c,   y: h)),
                (CGPoint(x: w-c, y: h),   CGPoint(x: w, y: h),   CGPoint(x: w,   y: h-c)),
            ]
            for (a, b, cc) in corners {
                var p = Path(); p.move(to: a); p.addLine(to: b); p.addLine(to: cc)
                ctx.stroke(p, with: .color(color),
                           style: StrokeStyle(lineWidth: lw, lineCap: .round, lineJoin: .round))
            }
        }
        .frame(width: size, height: size)
    }
}

