// ScannerView.swift

import SwiftUI
import AVFoundation

// MARK: - Contexto del scanner

enum ScannerContext {
    case hogar
    case empresa
}

struct ScannerView: View {
    @Binding var appMode: AppMode

    /// Contexto que determina qué flujo abrir al detectar un material.
    var scannerContext: ScannerContext = .hogar

    @StateObject private var camera = CameraManager()
    @State private var showFicha         = false
    @State private var showEmpresaSheet  = false
    @State private var btnScale: CGFloat = 1
    @State private var pulse             = false
    @State private var topIn             = false

    var body: some View {
        ZStack {
            CameraPreview(session: camera.session).ignoresSafeArea()

            // Vignettes
            VStack {
                LinearGradient(colors: [.black.opacity(0.45), .clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: 140)
                Spacer()
                LinearGradient(colors: [.clear, .black.opacity(0.55)], startPoint: .top, endPoint: .bottom)
                    .frame(height: 260)
            }
            .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                Spacer()
                viewfinder
                Spacer()
                bottomControls
            }
        }
        .onAppear {
            camera.start()
            withAnimation(.easeOut(duration: 0.4).delay(0.1)) { topIn = true }
        }
        .onDisappear { camera.stop() }
        .onChange(of: camera.detectedMaterial) { _, mat in
            guard mat != nil else { return }
            switch scannerContext {
            case .hogar:   showFicha = true
            case .empresa: showEmpresaSheet = true
            }
        }
        // ── Flujo Hogar → FichaView ─────────────────────────────────────
        .fullScreenCover(isPresented: $showFicha) {
            if let mat = camera.detectedMaterial {
                if mat.classKey == "organic_simple" {
                    OrganicFichaView(material: mat, isPresented: $showFicha)
                } else {
                    FichaView(
                        material    : mat,
                        ocrText     : camera.detectedOCRText,
                        imageData   : camera.capturedImageData,
                        isPresented : $showFicha
                    )
                    .onDisappear { resetCamera() }
                }
            }
        }
        // ── Flujo Empresa → EmpresaView pre-llenado ──────────────────────
        .sheet(isPresented: $showEmpresaSheet, onDismiss: { resetCamera() }) {
            if let mat = camera.detectedMaterial {
                EmpresaView(preselectedMaterial: mat, preselectedImageData: camera.capturedImageData)
                    .presentationDetents([.large])
            }
        }
        .alert("Intenta de nuevo", isPresented: .constant(camera.errorMessage != nil)) {
            Button("OK") { camera.errorMessage = nil }
        } message: { Text(camera.errorMessage ?? "") }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack(alignment: .center) {
            // Logo
            Text("NEXO")
                .font(.system(size: 20, weight: .bold))
                .tracking(-1)
                .foregroundStyle(.white)
                .accessibilityAddTraits(.isHeader)

            Spacer()

            // Indicador de contexto (empresa muestra badge)
            if scannerContext == .empresa {
                HStack(spacing: 5) {
                    Image(systemName: "building.2.fill")
                        .font(.system(size: 10, weight: .semibold))
                    Text("Modo Empresa")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(Color.nexoForest)
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(Color.nexoGreen, in: Capsule())
            } else {
                // Mode toggle solo en modo hogar
                HStack(spacing: 1) {
                    ForEach(AppMode.allCases, id: \.self) { mode in
                        Button {
                            withAnimation(.easeOut(duration: 0.2)) { appMode = mode }
                        } label: {
                            Text(mode.rawValue)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(appMode == mode ? Color.nexoForest : .white.opacity(0.55))
                                .padding(.horizontal, 11).padding(.vertical, 7)
                                .background(
                                    appMode == mode ? Color.white.opacity(0.92) : Color.clear,
                                    in: RoundedRectangle(cornerRadius: 6)
                                )
                        }
                        .accessibilityLabel("Modo \(mode.rawValue)")
                    }
                }
                .padding(2)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.white.opacity(0.15), lineWidth: 0.5))
            }
        }
        .padding(.horizontal, Sp.lg)
        .padding(.top, Sp.lg)
        .opacity(topIn ? 1 : 0)
        .offset(y: topIn ? 0 : -8)
    }

    // MARK: - Viewfinder

    private var viewfinder: some View {
        ZStack {
            // Color de esquinas según contexto
            let cornerColor: Color = scannerContext == .empresa
                ? Color.nexoForest.opacity(0.9)
                : Color.nexoGreen.opacity(0.9)

            CornerFrame(size: 200, cornerLen: 24, color: cornerColor, lw: 2.5)
                .scaleEffect(pulse ? 1.02 : 1)
                .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: pulse)
                .onAppear { pulse = true }

            if camera.isAnalyzing {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                    .frame(width: 200, height: 200)
                    .overlay {
                        VStack(spacing: 12) {
                            ProgressView()
                                .tint(scannerContext == .empresa ? Color.nexoForest : Color.nexoGreen)
                                .scaleEffect(1.3)
                            Text("Identificando…")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.white.opacity(0.85))
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
            // Hint contextual
            Text(hintText)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)

            // Botón de captura
            Button {
                guard !camera.isAnalyzing else { return }
                withAnimation(.spring(response: 0.18, dampingFraction: 0.5)) { btnScale = 0.88 }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                    withAnimation(.spring(response: 0.3)) { btnScale = 1 }
                    camera.capture()
                }
            } label: {
                ZStack {
                    Circle()
                        .strokeBorder(captureColor.opacity(0.3), lineWidth: 1.5)
                        .frame(width: 72, height: 72)
                    Circle()
                        .fill(captureColor)
                        .frame(width: 60, height: 60)
                        .shadow(color: captureColor.opacity(0.4), radius: 12, y: 4)
                        .overlay {
                            if camera.isAnalyzing {
                                ProgressView()
                                    .tint(.white)
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "camera")
                                    .font(.system(size: 22, weight: .light))
                                    .foregroundStyle(.white)
                            }
                        }
                }
            }
            .scaleEffect(btnScale)
            .disabled(camera.isAnalyzing)
            .accessibilityLabel("Escanear residuo")
        }
        .padding(.top, 24)
        .padding(.bottom, 40)
        .padding(.horizontal, Sp.lg)
    }

    // MARK: - Helpers

    private var hintText: String {
        if camera.isAnalyzing { return "Identificando material…" }
        return scannerContext == .empresa
            ? "Escanea el residuo para pre-llenar el lote"
            : "Apunta al residuo y toca el botón"
    }

    private var captureColor: Color {
        scannerContext == .empresa ? Color.nexoForest : Color.nexoGreen
    }

    private func resetCamera() {
        camera.detectedMaterial  = nil
        camera.detectedOCRText   = nil
        camera.capturedImageData = nil
    }
}

// MARK: - CornerFrame

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
