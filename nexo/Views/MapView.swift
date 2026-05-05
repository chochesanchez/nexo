import SwiftUI
import MapKit

// MARK: - FichaPin (actualizado con isLote)

struct FichaPin: Identifiable {
    let id         = UUID()
    let coordinate : CLLocationCoordinate2D
    let material   : NEXOMaterial
    let isLote     : Bool        // true = publicado desde Modo Empresa
    let kgLabel    : String?     // ej. "50 kg · Semanal"

    init(coordinate: CLLocationCoordinate2D, material: NEXOMaterial, isLote: Bool = false, kgLabel: String? = nil) {
        self.coordinate = coordinate
        self.material   = material
        self.isLote     = isLote
        self.kgLabel    = kgLabel
    }
}

// MARK: - Filtro de tipo de generador

enum FiltroGenerador: String, CaseIterable {
    case todos     = "Todos"
    case hogar     = "Hogar"
    case empresa   = "Empresa"

    var icon: String {
        switch self {
        case .todos:   return "square.grid.2x2"
        case .hogar:   return "house"
        case .empresa: return "building.2"
        }
    }
}

// MARK: - Mock pins con variedad hogar + empresa

func mockPins() -> [FichaPin] {
    let base = CLLocationCoordinate2D(latitude: 19.4326, longitude: -99.1332)
    typealias PinDef = (Double, Double, String, Bool, String?)
    let offsets: [PinDef] = [
        ( 0.003, -0.004, "pet_bottle",        false, nil),
        (-0.005,  0.002, "aluminum_can",       false, nil),
        ( 0.001,  0.006, "cardboard_box",      true,  "120 kg · Semanal"),
        (-0.003, -0.003, "glass_bottle",       false, nil),
        ( 0.006, -0.001, "organic_simple",     true,  "80 kg · Diaria"),
        (-0.002,  0.005, "battery_electronic", false, nil),
        ( 0.008,  0.003, "aluminum_can",       true,  "200 kg · Quincenal"),
        (-0.007, -0.005, "cardboard_box",      false, nil),
    ]
    return offsets.compactMap { (dlat, dlon, key, isLote, kg) in
        guard let mat = NEXOMaterial.all[key] else { return nil }
        return FichaPin(
            coordinate: CLLocationCoordinate2D(latitude: base.latitude + dlat,
                                              longitude: base.longitude + dlon),
            material: mat,
            isLote: isLote,
            kgLabel: kg
        )
    }
}

// MARK: - MapView

struct MapView: View {
    var listings  : [Listing] = []
    var isLoading : Bool      = false

    @State private var position: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 19.4326, longitude: -99.1332),
            span:   MKCoordinateSpan(latitudeDelta: 0.03, longitudeDelta: 0.03)
        )
    )
    @State private var selectedPin     : FichaPin? = nil
    @State private var showFicha       = false
    @State private var filtroActivo    : FiltroGenerador = .todos

    private var allPins: [FichaPin] {
        if listings.isEmpty { return mockPins() }
        return listings.compactMap { listing -> FichaPin? in
            guard let mat = NEXOMaterial.from(supabaseMaterial: listing.material) else { return nil }
            let isLote = listing.notes?.contains("Tipo:") ?? false
            return FichaPin(
                coordinate: CLLocationCoordinate2D(latitude: listing.lat, longitude: listing.lng),
                material  : mat,
                isLote    : isLote,
                kgLabel   : listing.quantityLabel
            )
        }
    }

    private var filteredPins: [FichaPin] {
        switch filtroActivo {
        case .todos:   return allPins
        case .hogar:   return allPins.filter { !$0.isLote }
        case .empresa: return allPins.filter {  $0.isLote }
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            Map(position: $position) {
                ForEach(filteredPins) { pin in
                    Annotation(pin.material.displayName, coordinate: pin.coordinate) {
                        PinView(material: pin.material, isLote: pin.isLote) {
                            selectedPin = pin; showFicha = true
                        }
                    }
                }
                UserAnnotation()
            }
            .ignoresSafeArea()

            topBar
        }
        .ignoresSafeArea(edges: .top)
        .sheet(isPresented: $showFicha) {
            if let pin = selectedPin {
                if pin.isLote {
                    LoteDetailSheet(pin: pin, isPresented: $showFicha)
                } else {
                    FichaView(
                        material    : pin.material,
                        ocrText     : nil,
                        isPresented : $showFicha
                    )
                }
            }
        }
    }

    // MARK: - Top bar con filtros

    private var topBar: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(listings.isEmpty ? "Fichas de ejemplo" : "Fichas disponibles")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                    if filtroActivo != .todos {
                        Text("\(filteredPins.count) de \(allPins.count)")
                            .font(.system(size: 11, weight: .light))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if isLoading {
                    ProgressView().tint(Color.nexoGreen)
                } else {
                    // Badge de conteo
                    HStack(spacing: 6) {
                        // Empresa count
                        let empresaCount = allPins.filter { $0.isLote }.count
                        if empresaCount > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "building.2.fill")
                                    .font(.system(size: 9, weight: .semibold))
                                Text("\(empresaCount)")
                                    .font(.system(size: 12, weight: .bold))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.nexoBlue, in: Capsule())
                        }
                        // Total
                        Text("\(filteredPins.count)")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.nexoGreen, in: Capsule())
                    }
                }
            }
            .padding(.horizontal, Sp.lg)
            .padding(.top, 60)
            .padding(.bottom, Sp.md)

            // Filtros de tipo de generador
            HStack(spacing: 6) {
                ForEach(FiltroGenerador.allCases, id: \.self) { filtro in
                    filtroChip(filtro)
                }
                Spacer()
            }
            .padding(.horizontal, Sp.lg)
            .padding(.bottom, Sp.md)

            Rectangle()
                .fill(Color.primary.opacity(0.06))
                .frame(height: 0.5)
        }
        .background(.ultraThinMaterial)
    }

    private func filtroChip(_ filtro: FiltroGenerador) -> some View {
        Button {
            withAnimation(.easeOut(duration: 0.2)) { filtroActivo = filtro }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: filtro.icon)
                    .font(.system(size: 10, weight: .semibold))
                Text(filtro.rawValue)
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(filtroActivo == filtro ? .white : Color.primary.opacity(0.6))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                filtroActivo == filtro ? Color.nexoBlack : Color.primary.opacity(0.06),
                in: Capsule()
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Filtrar por \(filtro.rawValue)")
    }
}

// MARK: - PinView (actualizado con isLote)

struct PinView: View {
    let material : NEXOMaterial
    let isLote   : Bool
    let onTap    : () -> Void
    @State private var pressed = false

    init(material: NEXOMaterial, isLote: Bool = false, onTap: @escaping () -> Void) {
        self.material = material
        self.isLote   = isLote
        self.onTap    = onTap
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 2) {
                ZStack {
                    // Pines de empresa: forma cuadrada redondeada, más grandes, con borde
                    if isLote {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.nexoBlue)
                            .frame(width: 46, height: 46)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .strokeBorder(.white.opacity(0.3), lineWidth: 1.5)
                            )
                            .shadow(color: Color.nexoBlue.opacity(0.5), radius: 8, y: 4)
                        VStack(spacing: 2) {
                            Image(systemName: material.icon)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white)
                            // Badge "KG" para empresa
                            Text("LOTE")
                                .font(.system(size: 6, weight: .black))
                                .tracking(0.5)
                                .foregroundStyle(.white.opacity(0.8))
                        }
                    } else {
                        // Pin de hogar: círculo clásico
                        Circle()
                            .fill(material.accent)
                            .frame(width: 40, height: 40)
                            .shadow(color: material.accent.opacity(0.4), radius: 6, y: 3)
                        Image(systemName: material.icon)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
                Image(systemName: "arrowtriangle.down.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(isLote ? Color.nexoBlue : material.accent)
                    .offset(y: -3)
            }
        }
        .scaleEffect(pressed ? 0.88 : 1)
        .animation(.spring(response: 0.25), value: pressed)
        .simultaneousGesture(DragGesture(minimumDistance: 0)
            .onChanged { _ in pressed = true }
            .onEnded   { _ in pressed = false }
        )
        .accessibilityLabel(
            isLote
                ? "\(material.displayName) — lote empresarial. Toca para ver detalles."
                : "\(material.displayName) disponible. Toca para ver la ficha."
        )
    }
}

// MARK: - LoteDetailSheet (hoja de detalle para pines de empresa)

struct LoteDetailSheet: View {
    let pin         : FichaPin
    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Handle
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.primary.opacity(0.12))
                .frame(width: 32, height: 3)
                .padding(.top, Sp.md)
                .padding(.bottom, 20)

            // Header
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.nexoBlue.opacity(0.1))
                    .frame(width: 52, height: 52)
                    .overlay {
                        Image(systemName: pin.material.icon)
                            .font(.system(size: 20, weight: .light))
                            .foregroundStyle(Color.nexoBlue)
                    }

                VStack(alignment: .leading, spacing: 4) {
                    Text(pin.material.displayName)
                        .font(.system(size: 20, weight: .black))
                        .tracking(-1)

                    HStack(spacing: 6) {
                        Image(systemName: "building.2.fill")
                            .font(.system(size: 9))
                        Text("Lote empresarial")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(Color.nexoBlue)
                }
                Spacer()

                // Badge grande de lote
                VStack(spacing: 2) {
                    Image(systemName: "shippingbox.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.nexoBlue)
                    Text("LOTE")
                        .font(.system(size: 8, weight: .black))
                        .tracking(0.8)
                        .foregroundStyle(Color.nexoBlue)
                }
                .padding(10)
                .background(Color.nexoBlue.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
            }
            .padding(.horizontal, Sp.lg)
            .padding(.bottom, Sp.md)

            Rectangle().fill(Color.primary.opacity(0.06)).frame(height: 0.5)

            // Cantidad y frecuencia
            if let kg = pin.kgLabel {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Cantidad · Frecuencia")
                            .font(.system(size: 9, weight: .semibold))
                            .tracking(1.5)
                            .textCase(.uppercase)
                            .foregroundStyle(Color.secondary)
                        Text(kg)
                            .font(.system(size: 22, weight: .black))
                            .tracking(-1)
                            .foregroundStyle(Color.nexoBlue)
                    }
                    Spacer()
                }
                .padding(.horizontal, Sp.lg)
                .padding(.vertical, 16)

                Rectangle().fill(Color.primary.opacity(0.06)).frame(height: 0.5)
            }

            // Ruta de disposición
            HStack(spacing: 8) {
                Image(systemName: pin.material.route.icon)
                    .font(.system(size: 11))
                Text("Ruta: \(pin.material.route.rawValue)")
                    .font(.system(size: 13, weight: .light))
                Spacer()
            }
            .foregroundStyle(pin.material.route.color)
            .padding(.horizontal, Sp.lg)
            .padding(.vertical, 14)

            Rectangle().fill(Color.primary.opacity(0.06)).frame(height: 0.5)

            // Diferenciador empresarial
            VStack(alignment: .leading, spacing: 10) {
                Text("¿Por qué este lote?")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(1.5)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.secondary)

                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "scalemass.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.nexoGreen)
                    Text("Volumen industrial — se requiere gestor certificado, no recolector individual.")
                        .font(.system(size: 13, weight: .light))
                        .foregroundStyle(Color.primary.opacity(0.7))
                }
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "repeat")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.nexoGreen)
                    Text("Generación recurrente — oportunidad de contrato a largo plazo.")
                        .font(.system(size: 13, weight: .light))
                        .foregroundStyle(Color.primary.opacity(0.7))
                }
            }
            .padding(.horizontal, Sp.lg)
            .padding(.vertical, 16)

            Spacer()

            // CTA
            Button { isPresented = false } label: {
                Text("Cerrar")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.primary.opacity(0.5))
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: Rd.sm))
                    .overlay(
                        RoundedRectangle(cornerRadius: Rd.sm)
                            .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
                    )
            }
            .padding(.horizontal, Sp.lg)
            .padding(.bottom, 32)
        }
        .presentationDetents([.medium, .large])
    }
}

#Preview("Mapa con fichas de ejemplo") {
    MapView()
}
