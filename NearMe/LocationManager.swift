import Foundation
import CoreLocation
import Combine
import MapKit

final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {

    private let manager = CLLocationManager()

    @Published var latitude: Double?
    @Published var longitude: Double?
    @Published var placeName: String?

    override init() {
        super.init()

        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    // MARK: - Request Location

    func requestLocation() {

        let status = manager.authorizationStatus

        if status == .notDetermined {

            manager.requestWhenInUseAuthorization()

        } else if status == .authorizedWhenInUse ||
                  status == .authorizedAlways {

            manager.startUpdatingLocation()
        }
    }

    // MARK: - Authorization Changed

    func locationManagerDidChangeAuthorization(
        _ manager: CLLocationManager
    ) {

        if manager.authorizationStatus == .authorizedWhenInUse ||
           manager.authorizationStatus == .authorizedAlways {

            manager.startUpdatingLocation()
        }
    }

    // MARK: - Location Updated

    func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {

        guard let location = locations.last else {
            return
        }

        latitude = location.coordinate.latitude
        longitude = location.coordinate.longitude

        reverseGeocode(location)
    }

    // MARK: - Reverse Geocoding

    private func reverseGeocode(
        _ location: CLLocation
    ) {

        guard let request = MKReverseGeocodingRequest(
            location: location
        ) else {
            return
        }

        Task {

            do {

                let mapItems = try await request.mapItems

                guard let mapItem = mapItems.first else {
                    return
                }

                let city =
                    mapItem.addressRepresentations?.cityName

                let region =
                    mapItem.addressRepresentations?.regionName

                await MainActor.run {

                    if let city, let region {

                        self.placeName =
                            "\(city), \(region)"

                    } else if let city {

                        self.placeName = city

                    } else if let address =
                                mapItem.address?.fullAddress {

                        self.placeName = address
                    }
                }

            } catch {

                print(
                    "Reverse geocoding failed: \(error)"
                )
            }
        }
    }
}
