// LocationManager.swift
// Wrapper de CoreLocation para obtener coordenadas del usuario
// en el momento de publicar una ficha. Las coordenadas se almacenan
// con radio de anonimización de 200 m antes de publicarse.

import Foundation
import CoreLocation
import Combine

@MainActor
final class LocationManager: NSObject, ObservableObject {

    static let shared = LocationManager()

    @Published var coordinate: CLLocationCoordinate2D? = nil
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined

    private let manager = CLLocationManager()

    // Radio de anonimización en metros
    private let anonymizationRadius: Double = 200.0

    private override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    // MARK: - Public API

    func requestWhenInUse() {
        manager.requestWhenInUseAuthorization()
    }

    func startUpdating() {
        switch authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.startUpdatingLocation()
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        default:
            break
        }
    }

    func stopUpdating() {
        manager.stopUpdatingLocation()
    }

    /// Devuelve coordenadas anonimizadas (offset aleatorio de hasta 200 m).
    var anonymizedCoordinate: CLLocationCoordinate2D? {
        guard let base = coordinate else { return nil }
        // 1 grado ≈ 111 000 m → 200 m ≈ 0.0018 grados
        let maxDelta = anonymizationRadius / 111_000.0
        let dLat = Double.random(in: -maxDelta...maxDelta)
        let dLon = Double.random(in: -maxDelta...maxDelta)
        return CLLocationCoordinate2D(
            latitude:  base.latitude  + dLat,
            longitude: base.longitude + dLon
        )
    }

    /// true cuando tenemos una coordenada utilizable
    var isAvailable: Bool { coordinate != nil }
}

// MARK: - CLLocationManagerDelegate
extension LocationManager: CLLocationManagerDelegate {

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            authorizationStatus = manager.authorizationStatus
            if manager.authorizationStatus == .authorizedWhenInUse
                || manager.authorizationStatus == .authorizedAlways {
                manager.startUpdatingLocation()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager,
                                     didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        Task { @MainActor in
            coordinate = loc.coordinate
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager,
                                     didFailWithError error: Error) {
        print("[LocationManager] error:", error.localizedDescription)
    }
}
