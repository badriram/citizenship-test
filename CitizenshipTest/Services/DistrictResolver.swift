import Foundation
import CoreLocation

@MainActor
@Observable
final class DistrictResolver: NSObject {
    private(set) var resolvedState: String?
    private(set) var resolvedDistrict: Int?
    private(set) var resolvedRepresentative: String?
    private(set) var isResolving = false
    private(set) var error: String?
    private(set) var locationPermissionDenied = false

    private var locationManager: CLLocationManager?
    private var locationContinuation: CheckedContinuation<CLLocation, Error>?

    func clear() {
        resolvedState = nil
        resolvedDistrict = nil
        resolvedRepresentative = nil
        error = nil
        locationPermissionDenied = false
    }

    // MARK: - Location-based Resolution

    func resolveFromLocation(using store: LegislatorStore) async {
        isResolving = true
        error = nil
        locationPermissionDenied = false
        defer { isResolving = false }

        do {
            let location = try await requestLocation()
            let (state, district) = try await geocodeDistrict(lat: location.coordinate.latitude, lon: location.coordinate.longitude)
            self.resolvedState = state
            self.resolvedDistrict = district
            self.resolvedRepresentative = store.representativeForDistrict(state: state, district: district)
        } catch let clError as CLError where clError.code == .denied {
            self.locationPermissionDenied = true
            self.error = "Location access denied. Please use ZIP code instead."
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - ZIP Code Resolution

    func resolveFromZIP(_ zip: String, using store: LegislatorStore) async {
        isResolving = true
        error = nil
        defer { isResolving = false }

        do {
            // Use CoreLocation to convert ZIP to coordinates, then Census API
            let geocoder = CLGeocoder()
            let placemarks = try await geocoder.geocodeAddressString(zip)
            guard let location = placemarks.first?.location else {
                self.error = "Could not find location for ZIP code \(zip)"
                return
            }

            let (state, district) = try await geocodeDistrict(lat: location.coordinate.latitude, lon: location.coordinate.longitude)
            self.resolvedState = state
            self.resolvedDistrict = district
            self.resolvedRepresentative = store.representativeForDistrict(state: state, district: district)
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Census Geocoder API

    private func geocodeDistrict(lat: Double, lon: Double) async throws -> (String, Int) {
        var components = URLComponents(string: "https://geocoding.geo.census.gov/geocoder/geographies/coordinates")!
        components.queryItems = [
            URLQueryItem(name: "x", value: String(lon)),
            URLQueryItem(name: "y", value: String(lat)),
            URLQueryItem(name: "benchmark", value: "Public_AR_Current"),
            URLQueryItem(name: "vintage", value: "Current_Current"),
            URLQueryItem(name: "format", value: "json"),
        ]

        let (data, _) = try await URLSession.shared.data(from: components.url!)
        return try parseDistrictResponse(data)
    }

    private func parseDistrictResponse(_ data: Data) throws -> (String, Int) {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let result = json["result"] as? [String: Any],
              let geographies = result["geographies"] as? [String: Any] else {
            throw NSError(domain: "DistrictResolver", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not parse Census API response"])
        }

        // Find the congressional district key dynamically — it changes each session
        // e.g. "119th Congressional Districts", "118th Congressional Districts"
        let districtKey = geographies.keys.first { $0.lowercased().contains("congressional district") }
        guard let districtKey,
              let districts = geographies[districtKey] as? [[String: Any]],
              let firstDistrict = districts.first else {
            throw NSError(domain: "DistrictResolver", code: 2, userInfo: [NSLocalizedDescriptionKey: "No congressional district data found for this location"])
        }

        // Parse district number from BASENAME (e.g. "7") or at-large
        let districtNumber: Int
        if let basename = firstDistrict["BASENAME"] as? String, let num = Int(basename) {
            districtNumber = num
        } else if let basename = firstDistrict["BASENAME"] as? String,
                  basename.lowercased().contains("at large") {
            districtNumber = 0
        } else {
            districtNumber = 0
        }

        // Parse state FIPS code
        guard let stateFIPS = firstDistrict["STATE"] as? String else {
            throw NSError(domain: "DistrictResolver", code: 3, userInfo: [NSLocalizedDescriptionKey: "Could not determine state from Census data"])
        }

        // Also try to get the state abbreviation from the States geography
        let stateCode: String
        if let states = geographies["States"] as? [[String: Any]],
           let firstState = states.first,
           let stusab = firstState["STUSAB"] as? String {
            stateCode = stusab
        } else {
            stateCode = stateCodeFromFIPS(stateFIPS)
        }

        return (stateCode, districtNumber)
    }

    // MARK: - Location Manager

    private func requestLocation() async throws -> CLLocation {
        return try await withCheckedThrowingContinuation { continuation in
            self.locationContinuation = continuation
            let manager = CLLocationManager()
            manager.delegate = self
            self.locationManager = manager

            switch manager.authorizationStatus {
            case .notDetermined:
                manager.requestWhenInUseAuthorization()
            case .authorizedWhenInUse, .authorizedAlways:
                manager.requestLocation()
            case .denied, .restricted:
                continuation.resume(throwing: CLError(.denied))
                self.locationContinuation = nil
            @unknown default:
                manager.requestWhenInUseAuthorization()
            }
        }
    }

    // MARK: - FIPS to State Code

    private func stateCodeFromFIPS(_ fips: String) -> String {
        let fipsMap: [String: String] = [
            "01": "AL", "02": "AK", "04": "AZ", "05": "AR", "06": "CA",
            "08": "CO", "09": "CT", "10": "DE", "11": "DC", "12": "FL",
            "13": "GA", "15": "HI", "16": "ID", "17": "IL", "18": "IN",
            "19": "IA", "20": "KS", "21": "KY", "22": "LA", "23": "ME",
            "24": "MD", "25": "MA", "26": "MI", "27": "MN", "28": "MS",
            "29": "MO", "30": "MT", "31": "NE", "32": "NV", "33": "NH",
            "34": "NJ", "35": "NM", "36": "NY", "37": "NC", "38": "ND",
            "39": "OH", "40": "OK", "41": "OR", "42": "PA", "44": "RI",
            "45": "SC", "46": "SD", "47": "TN", "48": "TX", "49": "UT",
            "50": "VT", "51": "VA", "53": "WA", "54": "WV", "55": "WI",
            "56": "WY",
        ]
        return fipsMap[fips] ?? fips
    }
}

// MARK: - CLLocationManagerDelegate

extension DistrictResolver: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else { return }
        Task { @MainActor in
            locationContinuation?.resume(returning: location)
            locationContinuation = nil
            locationManager = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            locationContinuation?.resume(throwing: error)
            locationContinuation = nil
            locationManager = nil
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            switch manager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                manager.requestLocation()
            case .denied, .restricted:
                locationContinuation?.resume(throwing: CLError(.denied))
                locationContinuation = nil
                locationManager = nil
            default:
                break
            }
        }
    }
}
