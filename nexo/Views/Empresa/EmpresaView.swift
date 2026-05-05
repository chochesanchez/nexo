//
//  EmpresaView.swift
//  nexo
//
//  Created by Grecia Saucedo on 05/05/26.
//

import SwiftUI
import CoreLocation
import SwiftData

struct EmpresaView: View {
    @EnvironmentObject private var repo     : ListingsRepository
    @EnvironmentObject private var location : LocationManager
    @EnvironmentObject private var auth     : AuthService
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    var preselectedMaterial  : NEXOMaterial? = nil
    var preselectedImageData : Data?         = nil

    @State private var selectedMaterial : NEXOMaterial?        = nil
    @State private var kgText           : String               = ""
    @State private var frecuencia       : FrecuenciaGeneracion = .semanal
    @State private var tipoGenerador    : TipoGenerador        = .empresa
    @State private var notes            : String               = ""
    @State private var step             : Int                  = 0
    @State private var isPublishing     : Bool                 = false
    @State private var publishError     : String?              = nil
    @State private var contentIn        : Bool                 = false

    private let materials: [NEXOMaterial] = [
        NEXOMaterial.all["pet_bottle"],
        NEXOMaterial.all["aluminum_can"],
        NEXOMaterial.all["cardboard_box"],
        NEXOMaterial.all["glass_bottle"],
        NEXOMaterial.all["organic_simple"],
        NEXOMaterial.all["battery_electronic"],
    ].compactMap { $0 }

    var body: some View {
        ZStack {
            // ── Fondo normal (steps 0 y 1) ──────────────────────────────
            Color(uiColor: .systemBackground).ignoresSafeArea()

            VStack {
                LinearGradient(
                    colors: [Color.nexoMint.opacity(0.5), Color.clear],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(height: 260)
                Spacer()
            }
            .ignoresSafeArea()

            VStack(spacing: 0) {
                header
                Rectangle().fill(Color.nexoForest.opacity(0.07)).frame(height: 0.5)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        if step == 0 { materialStep }
                        if step == 1 { detailStep   }
                    }
                    .padding(.bottom, 32)
                    .opacity(contentIn ? 1 : 0)
                    .offset(y: contentIn ? 0 : 10)
                }
                bottomBar
            }

            // ── Confirmación: cubre toda la pantalla ────────────────────
            if step == 2 {
                confirmedView
                    .transition(.opacity)
            }
        }
        .onAppear {
            if let mat = preselectedMaterial {
                selectedMaterial = mat
                step = 1
            }
            withAnimation(.easeOut(duration: 0.4).delay(0.1)) { contentIn = true }
            location.startUpdating()
        }
        .alert("Error al publicar", isPresented: .constant(publishError != nil)) {
            Button("OK") { publishError = nil }
        } message: { Text(publishError ?? "") }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                if preselectedMaterial != nil && step == 1 {
                    HStack(spacing: 5) {
                        Image(systemName: "viewfinder")
                            .font(.system(size: 9, weight: .semibold))
                        Text("DETECTADO POR ESCÁNER")
                            .font(.system(size: 9, weight: .semibold))
                            .tracking(1.5)
                    }
                    .foregroundStyle(Color.nexoBrand.opacity(0.6))
                } else {
                    Text("EMPRESA")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(2).textCase(.uppercase)
                        .foregroundStyle(Color.nexoBrand.opacity(0.5))
                }
                Text(stepTitle)
                    .font(.system(size: 28, weight: .bold))
                    .tracking(-1).foregroundStyle(Color.nexoForest)
                    .lineSpacing(2)
                    .animation(.easeOut(duration: 0.2), value: step)
            }
            Spacer()

            if preselectedMaterial != nil && step < 2 {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color(uiColor: .secondaryLabel))
                        .frame(width: 30, height: 30)
                        .background(Color(uiColor: .systemGray5), in: Circle())
                }
                .padding(.top, 4)
            } else if step < 2 {
                HStack(spacing: 6) {
                    ForEach(0..<2, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(step >= i ? Color.nexoForest : Color.nexoForest.opacity(0.12))
                            .frame(width: step == i ? 20 : 8, height: 4)
                            .animation(.easeOut(duration: 0.25), value: step)
                    }
                }
                .padding(.top, 10)
            }
        }
        .padding(.horizontal, Sp.lg)
        .padding(.top, 20).padding(.bottom, 20)
    }

    private var stepTitle: String {
        switch step {
        case 0:  return "¿Qué material\ngeneran?"
        case 1:  return "Detalles\ndel lote"
        default: return ""
        }
    }

    // MARK: - Step 0: Material + tipo

    private var materialStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionLabel("Tipo de residuo")
                .padding(.horizontal, Sp.lg).padding(.top, 24).padding(.bottom, 12)

            VStack(spacing: 8) {
                ForEach(materials) { mat in materialCard(mat) }
            }
            .padding(.horizontal, Sp.lg)

            sectionLabel("Tu tipo de negocio")
                .padding(.horizontal, Sp.lg).padding(.top, 28).padding(.bottom, 12)

            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                spacing: 8
            ) {
                ForEach(TipoGenerador.allCases, id: \.rawValue) { tipo in generadorChip(tipo) }
            }
            .padding(.horizontal, Sp.lg)
        }
    }

    private func materialCard(_ mat: NEXOMaterial) -> some View {
        let isOn = selectedMaterial?.classKey == mat.classKey
        return Button {
            withAnimation(.easeOut(duration: 0.18)) { selectedMaterial = mat }
        } label: {
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(mat.accent.opacity(0.1)).frame(width: 40, height: 40)
                    .overlay {
                        Image(systemName: mat.icon)
                            .font(.system(size: 16, weight: .light)).foregroundStyle(mat.accent)
                    }
                VStack(alignment: .leading, spacing: 3) {
                    Text(mat.displayName)
                        .font(.system(size: 15, weight: .semibold)).foregroundStyle(Color.nexoForest)
                    Text(mat.route.rawValue)
                        .font(.system(size: 11, weight: .light)).foregroundStyle(mat.route.color)
                }
                Spacer()
                Text(mat.value)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color(hex: "9A7800")).multilineTextAlignment(.trailing).frame(maxWidth: 72)
                ZStack {
                    Circle().strokeBorder(
                        isOn ? Color.nexoForest : Color(uiColor: .separator),
                        lineWidth: isOn ? 1.5 : 0.5
                    ).frame(width: 20, height: 20)
                    if isOn { Circle().fill(Color.nexoForest).frame(width: 10, height: 10) }
                }
            }
            .padding(.horizontal, Sp.md).padding(.vertical, 14)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Rd.md))
            .overlay(RoundedRectangle(cornerRadius: Rd.md).strokeBorder(
                isOn ? Color.nexoForest.opacity(0.3) : Color.nexoForest.opacity(0.07),
                lineWidth: isOn ? 1 : 0.5
            ))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(mat.displayName), \(mat.route.rawValue)")
    }

    private func generadorChip(_ tipo: TipoGenerador) -> some View {
        let isOn = tipoGenerador == tipo
        return Button {
            withAnimation(.easeOut(duration: 0.18)) { tipoGenerador = tipo }
        } label: {
            VStack(spacing: 6) {
                Image(systemName: tipo.icon)
                    .font(.system(size: 18, weight: .light))
                    .foregroundStyle(isOn ? Color.nexoForest : Color(uiColor: .tertiaryLabel))
                Text(tipo.rawValue)
                    .font(.system(size: 10, weight: isOn ? .semibold : .regular))
                    .foregroundStyle(isOn ? Color.nexoForest : Color(uiColor: .secondaryLabel))
                    .multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity).frame(height: 68)
            .background(
                isOn ? Color.nexoForest.opacity(0.07) : Color(uiColor: .secondarySystemBackground),
                in: RoundedRectangle(cornerRadius: 12)
            )
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(
                isOn ? Color.nexoForest.opacity(0.3) : Color.nexoForest.opacity(0.06), lineWidth: 0.5
            ))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Step 1: Detalles

    private var detailStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let mat = selectedMaterial {
                materialSummaryCard(mat)
                    .padding(.horizontal, Sp.lg).padding(.top, 20)
            }

            sectionLabel("Cantidad estimada por entrega")
                .padding(.horizontal, Sp.lg).padding(.top, 28).padding(.bottom, 8)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                TextField("0", text: $kgText)
                    .font(.system(size: 52, weight: .bold)).tracking(-2)
                    .foregroundStyle(Color.nexoForest).keyboardType(.decimalPad).frame(maxWidth: .infinity)
                Text("kg")
                    .font(.system(size: 22, weight: .light))
                    .foregroundStyle(Color(uiColor: .tertiaryLabel)).padding(.trailing, 4)
            }
            .padding(.horizontal, Sp.lg)

            if let mat = selectedMaterial, let kg = Double(kgText), kg > 0 {
                let digits = mat.co2.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
                if let co2 = Double(digits) {
                    HStack(spacing: 6) {
                        Image(systemName: "leaf.fill").font(.system(size: 10))
                        Text("≈ \(String(format: "%.0f g", co2 * kg)) CO₂ evitado por entrega")
                            .font(.system(size: 12, weight: .light))
                    }
                    .foregroundStyle(Color.nexoBrand)
                    .padding(.horizontal, Sp.lg).padding(.top, 6)
                }
            }

            Rectangle().fill(Color.nexoForest.opacity(0.07)).frame(height: 0.5).padding(.top, 16)

            sectionLabel("Frecuencia de generación")
                .padding(.horizontal, Sp.lg).padding(.top, 20).padding(.bottom, 12)

            HStack(spacing: 8) {
                ForEach(FrecuenciaGeneracion.allCases, id: \.rawValue) { freq in frecuenciaChip(freq) }
            }
            .padding(.horizontal, Sp.lg)

            Rectangle().fill(Color.nexoForest.opacity(0.07)).frame(height: 0.5).padding(.top, 20)

            sectionLabel("Notas adicionales (opcional)")
                .padding(.horizontal, Sp.lg).padding(.top, 20).padding(.bottom, 10)

            TextField(
                "Ej: disponible entre 9–13 h, requiere camión de carga…",
                text: $notes, axis: .vertical
            )
            .font(.system(size: 14, weight: .light)).foregroundStyle(Color.nexoForest)
            .lineLimit(3...6).padding(Sp.md)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Rd.md))
            .overlay(RoundedRectangle(cornerRadius: Rd.md).strokeBorder(Color.nexoForest.opacity(0.08), lineWidth: 0.5))
            .padding(.horizontal, Sp.lg)

            Rectangle().fill(Color.nexoForest.opacity(0.07)).frame(height: 0.5).padding(.top, 20)

            if let mat = selectedMaterial, let kg = Double(kgText), kg > 0 {
                impactProjection(mat: mat, kg: kg)
            }
        }
    }

    private func materialSummaryCard(_ mat: NEXOMaterial) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(mat.accent.opacity(0.1)).frame(width: 40, height: 40)
                .overlay {
                    Image(systemName: mat.icon)
                        .font(.system(size: 16, weight: .light)).foregroundStyle(mat.accent)
                }
            VStack(alignment: .leading, spacing: 3) {
                Text(mat.displayName)
                    .font(.system(size: 14, weight: .semibold)).foregroundStyle(Color.nexoForest)
                HStack(spacing: 5) {
                    if preselectedMaterial?.classKey == mat.classKey {
                        HStack(spacing: 4) {
                            Image(systemName: "viewfinder").font(.system(size: 9))
                            Text("Escaneado").font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundStyle(Color.nexoBrand)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.nexoMint, in: Capsule())
                    } else {
                        Image(systemName: tipoGenerador.icon).font(.system(size: 10))
                        Text(tipoGenerador.rawValue).font(.system(size: 11, weight: .light))
                            .foregroundStyle(Color(uiColor: .secondaryLabel))
                    }
                }
            }
            Spacer()
            if preselectedMaterial == nil {
                Button { withAnimation { step = 0 } } label: {
                    Text("Cambiar").font(.system(size: 11, weight: .medium)).foregroundStyle(Color.nexoBrand)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Color.nexoBrand.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
                }
            }
        }
        .padding(Sp.md)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Rd.md))
        .overlay(RoundedRectangle(cornerRadius: Rd.md).strokeBorder(Color.nexoForest.opacity(0.08), lineWidth: 0.5))
    }

    private func frecuenciaChip(_ freq: FrecuenciaGeneracion) -> some View {
        let isOn = frecuencia == freq
        return Button {
            withAnimation(.easeOut(duration: 0.18)) { frecuencia = freq }
        } label: {
            Text(freq.rawValue)
                .font(.system(size: 11, weight: isOn ? .semibold : .regular))
                .foregroundStyle(isOn ? Color.nexoForest : Color(uiColor: .secondaryLabel))
                .frame(maxWidth: .infinity).frame(height: 36)
                .background(
                    isOn ? Color.nexoForest.opacity(0.08) : Color(uiColor: .secondarySystemBackground),
                    in: RoundedRectangle(cornerRadius: 8)
                )
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(
                    isOn ? Color.nexoForest.opacity(0.3) : Color.nexoForest.opacity(0.06), lineWidth: 0.5
                ))
        }
        .buttonStyle(.plain)
    }

    private func impactProjection(mat: NEXOMaterial, kg: Double) -> some View {
        let mult: Double = {
            switch frecuencia {
            case .diaria: return 365; case .semanal: return 52
            case .quincenal: return 26; case .mensual: return 12
            }
        }()
        let kgAnual  = kg * mult
        let digits   = mat.co2.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        let co2Anual = (Double(digits) ?? 0) * kgAnual / 1000

        return VStack(alignment: .leading, spacing: 14) {
            sectionLabel("Proyección anual")
            HStack(spacing: 0) {
                projectionCell(label: "Kg anuales",  value: String(format: "%.0f kg", kgAnual),  color: Color.nexoForest)
                Rectangle().fill(Color.nexoForest.opacity(0.07)).frame(width: 0.5)
                projectionCell(label: "CO₂ evitado", value: String(format: "%.1f kg", co2Anual), color: Color.nexoBrand)
            }
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Rd.md))
            .overlay(RoundedRectangle(cornerRadius: Rd.md).strokeBorder(Color.nexoForest.opacity(0.07), lineWidth: 0.5))
        }
        .padding(.horizontal, Sp.lg).padding(.vertical, 20)
    }

    private func projectionCell(label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: 10, weight: .light)).foregroundStyle(Color(uiColor: .secondaryLabel))
            Text(value).font(.system(size: 26, weight: .bold)).tracking(-1).foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(Sp.md)
    }

    // MARK: - Confirmación

    private var confirmedView: some View {
        ZStack {
            Color(hex: "1B5E20")
                .ignoresSafeArea()
            VStack(spacing: 20) {
                Spacer()
                ZStack {
                    Circle().fill(Color.white.opacity(0.1)).frame(width: 90, height: 90)
                    Image(systemName: "shippingbox.fill")
                        .font(.system(size: 44, weight: .light)).foregroundStyle(.white)
                }
                VStack(spacing: 8) {
                    Text("Lote publicado")
                        .font(.system(size: 22, weight: .bold)).tracking(-1).foregroundStyle(.white)
                    Text("Los gestores certificados\ncontactarán a tu empresa.")
                        .font(.system(size: 14, weight: .light))
                        .foregroundStyle(.white.opacity(0.75))
                        .multilineTextAlignment(.center).lineSpacing(3)
                }
                Spacer()
                if preselectedMaterial != nil {
                    HStack(spacing: 10) {
                        Button { dismiss() } label: {
                            Text("Cerrar")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color(hex: "1B5E20"))
                                .frame(maxWidth: .infinity).frame(height: 54)
                                .background(.white, in: RoundedRectangle(cornerRadius: Rd.lg))
                        }
                        Button {
                            withAnimation { step = 1; kgText = ""; notes = "" }
                        } label: {
                            Text("Publicar otro")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity).frame(height: 54)
                                .background(Color.white.opacity(0.15), in: RoundedRectangle(cornerRadius: Rd.lg))
                        }
                    }
                    .padding(.horizontal, Sp.lg).padding(.bottom, 40)
                } else {
                    Button {
                        withAnimation { step = 0; selectedMaterial = nil; kgText = ""; notes = "" }
                    } label: {
                        Text("Publicar otro lote")
                            .font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                            .frame(maxWidth: .infinity).frame(height: 54)
                            .background(Color.white.opacity(0.15), in: RoundedRectangle(cornerRadius: Rd.lg))
                    }
                    .padding(.horizontal, Sp.lg).padding(.bottom, 40)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        VStack(spacing: 8) {
            Rectangle().fill(Color.nexoForest.opacity(0.07)).frame(height: 0.5)

            if step == 0 {
                Button {
                    guard selectedMaterial != nil else { return }
                    withAnimation(.easeOut(duration: 0.2)) { contentIn = false }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                        step = 1
                        withAnimation(.easeOut(duration: 0.3)) { contentIn = true }
                    }
                } label: {
                    Text(selectedMaterial == nil ? "Selecciona un material" : "Continuar")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(selectedMaterial == nil ? Color(uiColor: .tertiaryLabel) : .white)
                        .frame(maxWidth: .infinity).frame(height: 54)
                        .background(
                            selectedMaterial == nil ? Color(uiColor: .secondarySystemBackground) : Color.nexoForest,
                            in: RoundedRectangle(cornerRadius: Rd.lg)
                        )
                }
                .disabled(selectedMaterial == nil)
                .animation(.easeOut(duration: 0.2), value: selectedMaterial == nil)

            } else {
                HStack(spacing: 10) {
                    if preselectedMaterial == nil {
                        Button {
                            withAnimation(.easeOut(duration: 0.2)) { contentIn = false }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                                step = 0
                                withAnimation(.easeOut(duration: 0.3)) { contentIn = true }
                            }
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 15, weight: .semibold)).foregroundStyle(Color.nexoForest)
                                .frame(width: 54, height: 54)
                                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Rd.lg))
                                .overlay(RoundedRectangle(cornerRadius: Rd.lg).strokeBorder(Color.nexoForest.opacity(0.12), lineWidth: 0.5))
                        }
                    }

                    Button { publicarLote() } label: {
                        Group {
                            if isPublishing { ProgressView().tint(.white) }
                            else {
                                Text("Publicar lote")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(canPublish ? .white : Color(uiColor: .tertiaryLabel))
                            }
                        }
                        .frame(maxWidth: .infinity).frame(height: 54)
                        .background(
                            canPublish ? Color.nexoForest : Color(uiColor: .secondarySystemBackground),
                            in: RoundedRectangle(cornerRadius: Rd.lg)
                        )
                    }
                    .disabled(!canPublish || isPublishing)
                    .animation(.easeOut(duration: 0.2), value: canPublish)
                }
            }
        }
        .padding(.horizontal, Sp.lg).padding(.vertical, 12).padding(.bottom, 16)
        .background(.regularMaterial)
    }

    // MARK: - Helpers

    private var canPublish: Bool { selectedMaterial != nil && (Double(kgText) ?? 0) > 0 }

    private func sectionLabel(_ text: String) -> some View {
        Text(text).font(.system(size: 10, weight: .semibold)).tracking(2).textCase(.uppercase)
            .foregroundStyle(Color.nexoBrand.opacity(0.6))
    }

    private func publicarLote() {
        guard let mat = selectedMaterial, let kg = Double(kgText) else { return }
        if !location.isAvailable { location.requestWhenInUse() }
        isPublishing = true

        Task {
            let coord = location.anonymizedCoordinate
                     ?? location.coordinate
                     ?? CLLocationCoordinate2D(latitude: 19.4326, longitude: -99.1332)

            let quantityStr = "\(String(format: "%.0f", kg)) kg · \(frecuencia.rawValue)"
            let notesStr    = ["Tipo: \(tipoGenerador.rawValue)", notes.isEmpty ? nil : notes]
                .compactMap { $0 }.joined(separator: ". ")

            let nuevo = NewListing(
                material: mat.displayName, quantityLabel: quantityStr, notes: notesStr,
                lat: coord.latitude, lng: coord.longitude,
                classKey: mat.classKey, displayName: mat.displayName, icon: mat.icon,
                route: mat.route.rawValue, co2: mat.co2, water: mat.water, value: mat.value,
                fmInstruction: nil
            )
            let ok = await repo.publish(nuevo)
            isPublishing = false
            if ok {
                let registro = LoteRegistro(
                    material: mat, kgEstimados: kg,
                    frecuencia: frecuencia, tipoGenerador: tipoGenerador,
                    notes: notesStr, imageData: preselectedImageData
                )
                context.insert(registro)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                withAnimation(.easeOut(duration: 0.3)) { step = 2 }
            } else {
                publishError = repo.lastError ?? "Intenta de nuevo."
            }
        }
    }
}

#Preview("Empresa") {
    EmpresaView()
        .environmentObject(ListingsRepository())
        .environmentObject(LocationManager.shared)
        .environmentObject(AuthService.shared)
        .modelContainer(for: LoteRegistro.self, inMemory: true)
}

#Preview("Empresa desde scanner") {
    EmpresaView(preselectedMaterial: NEXOMaterial.all["cardboard_box"]!)
        .environmentObject(ListingsRepository())
        .environmentObject(LocationManager.shared)
        .environmentObject(AuthService.shared)
        .modelContainer(for: LoteRegistro.self, inMemory: true)
}
