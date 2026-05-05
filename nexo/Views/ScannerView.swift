import SwiftUI
import AVFoundation

struct ScannerView: View {
    @Binding var appMode: AppMode
    @StateObject private var camera  = CameraManager()
    @State private var showFicha     = false
    @State private var pulse         = false
    @State private var btnScale: CGFloat = 1

    var body: some View {
        ZStack {
            CameraPreview(session: camera.session).ignoresSafeArea()
            VStack {
                LinearGradient(colors: [.black.opacity(0.55), .clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: 160)
                Spacer()
            }.ignoresSafeArea()
            VStack {
                Spacer()
                LinearGradient(colors: [.clear, .black.opacity(0.55)], startPoint: .top, endPoint: .bottom)
                    .frame(height: 240)
            }.ignoresSafeArea()
            VStack(spacing: 0) {
                topBar
                Spacer()
                viewfinder
                Spacer()
                bottomCard
            }
        }
        .onAppear  { camera.start() }
        .onDisappear { camera.stop() }
        .onChange(of: camera.detectedMaterial) { _, mat in if mat != nil { showFicha = true } }
        .fullScreenCover(isPresented: $showFicha) {
            if let mat = camera.detectedMaterial {
                FichaView(material: mat, isPresented: $showFicha)
                    .onDisappear { camera.detectedMaterial = nil }
            }
        }
        .alert("Intenta de nuevo", isPresented: .constant(camera.errorMessage != nil)) {
            Button("OK") { camera.errorMessage = nil }
        } message: { Text(camera.errorMessage ?? "") }
    }

    private var topBar: some View {
        HStack(alignment: .center) {
            Text("NEXO")
                .font(.system(size: 24, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            HStack(spacing: 0) {
                ForEach(AppMode.allCases, id: \.self) { mode in
                    Button {
                        withAnimation(.spring(response: 0.3)) { appMode = mode }
                    } label: {
                        Text(mode.rawValue)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(appMode == mode ? Color.nexoDark : .white)
                            .padding(.horizontal, 14).padding(.vertical, 7)
                            .background(appMode == mode ? Color.white : .clear, in: Capsule())
                    }
                    .accessibilityLabel("Modo \(mode.rawValue)")
                }
            }
            .padding(3).background(.white.opacity(0.2), in: Capsule())
        }
        .padding(.horizontal, Sp.lg).padding(.top, Sp.md)
    }

    private var viewfinder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(.white.opacity(0.6), lineWidth: 1.5)
                .frame(width: 250, height: 250)
                .scaleEffect(pulse ? 1.04 : 1)
                .animation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true), value: pulse)
                .onAppear { pulse = true }
            CornerFrame(size: 250, cornerLen: 28, color: .nexoAmber, lw: 3)
            if camera.isAnalyzing {
                RoundedRectangle(cornerRadius: 20).fill(.black.opacity(0.65))
                    .frame(width: 250, height: 250)
                    .overlay {
                        VStack(spacing: 14) {
                            ProgressView().tint(.white).scaleEffect(1.4)
                            Text("Analizando…").font(.system(size: 15, weight: .medium)).foregroundStyle(.white)
                        }
                    }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(camera.isAnalyzing ? "Analizando residuo" : "Visor de cámara")
    }

    private var bottomCard: some View {
        VStack(spacing: Sp.lg) {
            Text(camera.isAnalyzing ? "Un momento…" : "Apunta a un residuo y toca el botón")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white.opacity(0.9))
                .multilineTextAlignment(.center)
            Button {
                guard !camera.isAnalyzing else { return }
                withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) { btnScale = 0.88 }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                    withAnimation(.spring(response: 0.3)) { btnScale = 1 }
                    camera.capture()
                }
            } label: {
                ZStack {
                    Circle().fill(Color.nexoAmber).frame(width: 76, height: 76)
                        .shadow(color: .nexoAmber.opacity(0.45), radius: 18, y: 6)
                    Image(systemName: camera.isAnalyzing ? "hourglass" : "viewfinder")
                        .font(.system(size: 30, weight: .semibold)).foregroundStyle(Color.nexoDeep)
                }
            }
            .scaleEffect(btnScale).disabled(camera.isAnalyzing)
            .accessibilityLabel("Escanear residuo")
        }
        .padding(.bottom, 52)
    }
}

struct CornerFrame: View {
    let size: CGFloat; let cornerLen: CGFloat; let color: Color; let lw: CGFloat
    var body: some View {
        Canvas { ctx, sz in
            let w = sz.width, h = sz.height, c = cornerLen
            let corners: [(CGPoint, CGPoint, CGPoint)] = [
                (CGPoint(x: 0, y: c),   CGPoint(x: 0, y: 0),   CGPoint(x: c, y: 0)),
                (CGPoint(x: w-c, y: 0), CGPoint(x: w, y: 0),   CGPoint(x: w, y: c)),
                (CGPoint(x: 0, y: h-c), CGPoint(x: 0, y: h),   CGPoint(x: c, y: h)),
                (CGPoint(x: w-c, y: h), CGPoint(x: w, y: h),   CGPoint(x: w, y: h-c)),
            ]
            for (a, b, cc) in corners {
                var p = Path(); p.move(to: a); p.addLine(to: b); p.addLine(to: cc)
                ctx.stroke(p, with: .color(color), style: StrokeStyle(lineWidth: lw, lineCap: .round, lineJoin: .round))
            }
        }
        .frame(width: size, height: size)
    }
}
