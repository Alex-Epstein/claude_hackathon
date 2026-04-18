//
//  LocationService.swift
//  Appetight
//

import Foundation
import CoreLocation
import Combine

enum LocationError: LocalizedError {
    case denied
    case unavailable
    case timeout

    var errorDescription: String? {
        switch self {
        case .denied: return "Location permission denied. Enable it in Settings."
        case .unavailable: return "Could not get your location."
        case .timeout: return "Location request timed out."
        }
    }
}

@MainActor
final class LocationService: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = LocationService()

    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocation, Error>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func requestLocation() async throws -> CLLocation {
        if continuation != nil {
            throw LocationError.unavailable
        }

        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            throw LocationError.denied
        default:
            break
        }

        return try await withCheckedThrowingContinuation { cont in
            self.continuation = cont
            self.manager.requestLocation()
        }
    }

    // MARK: - CLLocationManagerDelegate

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            guard let loc = locations.first, let cont = self.continuation else { return }
            self.continuation = nil
            cont.resume(returning: loc)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            guard let cont = self.continuation else { return }
            self.continuation = nil
            cont.resume(throwing: error)
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            let status = manager.authorizationStatus
            if status == .denied || status == .restricted, let cont = self.continuation {
                self.continuation = nil
                cont.resume(throwing: LocationError.denied)
            }
        }
    }
}
