import Foundation
import MapKit
import Combine

@MainActor
final class NearbyPlacesManager: ObservableObject {

    @Published var places: [MKMapItem] = []
    @Published var isSearching = false
    @Published var errorMessage: String?

    func searchNearby(
        latitude: Double,
        longitude: Double,
        query: String
    ) async {

        isSearching = true
        errorMessage = nil
        places = []

        let coordinate = CLLocationCoordinate2D(
            latitude: latitude,
            longitude: longitude
        )

        let request = MKLocalSearch.Request()

        request.naturalLanguageQuery = query

        request.region = MKCoordinateRegion(
            center: coordinate,
            latitudinalMeters: 5000,
            longitudinalMeters: 5000
        )

        request.resultTypes = .pointOfInterest

        let search = MKLocalSearch(request: request)

        do {
            let response = try await search.start()

            places = response.mapItems

        } catch {
            errorMessage = error.localizedDescription
        }

        isSearching = false
    }
}

