// MapView.swift
// Acepta listings reales de Supabase. Si no hay, muestra datos mock.

import SwiftUI
import MapKit

struct FichaPin: Identifiable {
    let id        = UUID()
    let coordinate: CLLocationCoordinate2D
    let material  : NEXOMaterial
}

private func mockPins() -> [FichaPin] {
    let base = CLLocationCoordinate2D(latitude: 19.4326, longitude: -99.1332)
    let offsets: [(Double, Double, String)] = [
        ( 0.003, -0.004, "pet_bottle"),
        (-0.005,  0.002, "aluminum_can"),
        ( 0.001,  0.006, "cardboard_box"),
        (-0.003, -0.003, "glass_bottle"),
        ( 0.006, -0.001, "organic_simple"),
        (-0.002,  0.005, "battery_electronic"),
    ]
    return offsets.compactMap { (dlat, dlon, key) in
        guard let mat = NEXOMaterial.all[key] else { return nil }
        return FichaPin(coordinate: CLLocationCoordinate2D(latitude: base.latitude + dlat, longitude: base.longitude + dlon), material: mat)
    }
}

struct MapView: View {
    var listings   : [Listing] = []
    var isLoading  : Bool      = false

    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 19.4326, longitude: -99.1332),
        span:   MKCoordinateSpan(latitudeDelta: 0.03, longitudeDelta: 0.03)
    )
    @State private var selectedPin: FichaPin? = nil
    @State private var showFicha  = false

    private var pins: [FichaPin] {
        if listings.isEmpty { return mockPins() }
        return listings.compactMap { listing in
            guard let mat = NEXOMaterial.from(supabaseMaterial: listing.material) else { return nil }
            return FichaPin(coordinate: CLLocationCoordinate2D(latitude: listing.lat, longitude: listing.lng), material: mat)
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            Map(coordinateRegion: $region, showsUserLocation: true, annotationItems: pins) { pin in
                MapAnnotation(coordinate: pin.coordinate) {
                    PinView(material: pin.material) {
                        selectedPin = pin; showFicha = true
                    }
                }
            }
            .ignoresSafeArea()
            topBar
        }
        .ignoresSafeArea(edges: .top)
        .sheet(isPresented: $showFicha) {
            if let pin = selectedPin {
                FichaView(material: pin.material, isPresented: $showFicha)
            }
        }
    }

    private var topBar: some View {
        VStack(spacing: 0) {
            HStack {
                Text(listings.isEmpty ? "Fichas de ejemplo" : "Fichas disponibles")
                    .font(.system(size: 17, weight: .bold, design: .rounded)).foregroundStyle(.primary)
                Spacer()
                if isLoading {
                    ProgressView().tint(Color.nexoGreen)
                } else {
                    Text("\(pins.count)")
                        .font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Color.nexoGreen, in: Capsule())
                }
            }
            .padding(.horizontal, Sp.lg).padding(.top, 60).padding(.bottom, Sp.md)
            .background(.ultraThinMaterial)
        }
    }
}

struct PinView: View {
    let material: NEXOMaterial
    let onTap   : () -> Void
    @State private var pressed = false

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 2) {
                ZStack {
                    Circle().fill(material.accent).frame(width: 40, height: 40)
                        .shadow(color: material.accent.opacity(0.4), radius: 6, y: 3)
                    Image(systemName: material.icon).font(.system(size: 18, weight: .semibold)).foregroundStyle(.white)
                }
                Image(systemName: "arrowtriangle.down.fill").font(.system(size: 8))
                    .foregroundStyle(material.accent).offset(y: -3)
            }
        }
        .scaleEffect(pressed ? 0.88 : 1).animation(.spring(response: 0.25), value: pressed)
        .simultaneousGesture(DragGesture(minimumDistance: 0)
            .onChanged { _ in pressed = true }.onEnded { _ in pressed = false })
        .accessibilityLabel("\(material.displayName) disponible. Toca para ver la ficha.")
    }
}
