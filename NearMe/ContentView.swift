import SwiftUI
import CoreLocation
import MapKit

struct ContentView: View {

    @StateObject private var locationManager = LocationManager()
    @StateObject private var trackingManager = TrackingManager()

    @State private var searchText = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var selectedPlace: MKMapItem?
    @State private var route: MKRoute?
    @State private var selectedRadius: CLLocationDistance = 500

    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var selectedTab = 0

    // NEW:
    // Used so the map centers only when Home is opened,
    // not every time the user's GPS location changes.
    @State private var shouldCenterHomeMap = true

    var body: some View {

        ZStack {

            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {

                header

                if selectedTab == 0 {

                    ScrollView(
                        showsIndicators: false
                    ) {

                        VStack(spacing: 16) {

                            trackingStatusCard

                            searchSection

                            mapSection

                            if let selectedPlace {

                                destinationCard(
                                    place: selectedPlace
                                )

                                radiusSection

                                trackingControls
                            }

                            Spacer(
                                minLength: 100
                            )
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 20)
                    }

                } else {

                    historyView
                }
            }

            VStack {

                Spacer()

                bottomNavigation
            }
        }

        // MARK: - Initial Load
        .onAppear {

            locationManager.requestLocation()

            // Try immediately in case the location is
            // already available.
            centerHomeMapIfPossible()
        }

        // MARK: - Location Changed
        .onChange(
            of: locationManager.latitude
        ) { _, _ in

            updateRoute()

            // Only center the map when Home needs
            // its initial/current-location positioning.
            if selectedTab == 0 &&
                shouldCenterHomeMap {

                centerHomeMapIfPossible()
            }
        }

        // MARK: - Tab Changed
        .onChange(
            of: selectedTab
        ) { _, newTab in

            // When returning to Home,
            // center the map on the user's current location.
            if newTab == 0 {

                shouldCenterHomeMap = true

                // Small delay allows the Home view/map
                // to become active before changing camera.
                DispatchQueue.main.asyncAfter(
                    deadline: .now() + 0.15
                ) {

                    centerHomeMapIfPossible()
                }
            }
        }
    }

    // MARK: - Header

    private var header: some View {

        HStack {

            HStack(spacing: 10) {

                Image(
                    systemName: "location.fill"
                )
                .font(.system(size: 28))
                .foregroundStyle(.blue)

                Text("NearMe")
                    .font(
                        .system(
                            size: 28,
                            weight: .bold
                        )
                    )
            }

            Spacer()

            Image(
                systemName: "bell"
            )
            .font(.system(size: 22))
            .foregroundStyle(.blue)
            .frame(
                width: 44,
                height: 44
            )
            .background(
                Color.blue.opacity(0.06)
            )
            .clipShape(Circle())
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 8)
    }

    // MARK: - Tracking Status

    private var trackingStatusCard: some View {

        HStack(spacing: 14) {

            ZStack {

                Circle()
                    .fill(
                        trackingManager.isTracking
                        ? Color.green.opacity(0.15)
                        : Color.blue.opacity(0.10)
                    )
                    .frame(
                        width: 52,
                        height: 52
                    )

                Image(
                    systemName:
                        trackingManager.isTracking
                        ? "location.fill"
                        : "location"
                )
                .foregroundStyle(
                    trackingManager.isTracking
                    ? .green
                    : .blue
                )
                .font(.system(size: 22))
            }

            VStack(
                alignment: .leading,
                spacing: 4
            ) {

                Text(
                    trackingManager.isTracking
                    ? trackingManager.isPaused
                        ? "Tracking Paused"
                        : "Tracking Active"
                    : "Ready to track"
                )
                .font(.headline)

                if let selectedPlace {

                    Text(
                        "\(selectedPlace.name ?? "Destination") • \(radiusText)"
                    )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                } else {

                    Text(
                        "Select a destination to get started"
                    )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if trackingManager.isTracking {

                Circle()
                    .fill(
                        trackingManager.isPaused
                        ? .orange
                        : .green
                    )
                    .frame(
                        width: 10,
                        height: 10
                    )
            }
        }
        .padding(16)
        .background(.regularMaterial)
        .clipShape(
            RoundedRectangle(
                cornerRadius: 20
            )
        )
    }

    // MARK: - Search

    private var searchSection: some View {

        VStack(spacing: 10) {

            HStack(spacing: 10) {

                Image(
                    systemName: "magnifyingglass"
                )
                .foregroundStyle(.secondary)

                TextField(
                    "Search places",
                    text: $searchText
                )
                .textInputAutocapitalization(.words)
                .submitLabel(.search)
                .onSubmit {
                    performSearch()
                }

                if !searchText.isEmpty {

                    Button {

                        searchText = ""
                        searchResults = []

                    } label: {

                        Image(
                            systemName:
                                "xmark.circle.fill"
                        )
                        .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 16)
            .frame(height: 54)
            .background(.regularMaterial)
            .clipShape(
                RoundedRectangle(
                    cornerRadius: 18
                )
            )

            Button {

                performSearch()

            } label: {

                HStack {

                    Image(
                        systemName:
                            "magnifyingglass"
                    )

                    Text("Search")
                        .fontWeight(.semibold)
                }
                .font(.title3)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(.blue)
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: 18
                    )
                )
            }

            if !searchResults.isEmpty {

                VStack(spacing: 8) {

                    ForEach(
                        searchResults,
                        id: \.self
                    ) { place in

                        Button {

                            selectPlace(place)

                        } label: {

                            HStack(spacing: 12) {

                                Image(
                                    systemName:
                                        "mappin.circle.fill"
                                )
                                .font(.system(size: 28))
                                .foregroundStyle(.blue)

                                VStack(
                                    alignment: .leading,
                                    spacing: 4
                                ) {

                                    Text(
                                        place.name
                                        ?? "Unknown place"
                                    )
                                    .font(.headline)
                                    .foregroundStyle(.primary)

                                    Text(
                                        place.placemark.title
                                        ?? "Address unavailable"
                                    )
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                                }

                                Spacer()

                                Image(
                                    systemName:
                                        "chevron.right"
                                )
                                .foregroundStyle(.secondary)
                            }
                            .padding(12)
                            .background(
                                .regularMaterial
                            )
                            .clipShape(
                                RoundedRectangle(
                                    cornerRadius: 16
                                )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Map

    private var mapSection: some View {

        MapReader { proxy in

            Map(
                position: $cameraPosition
            ) {

                UserAnnotation()

                if trackingManager.isTracking,
                   let route {

                    MapPolyline(
                        route.polyline
                    )
                    .stroke(
                        Color.blue,
                        lineWidth: 6
                    )
                }

                if let selectedPlace {

                    let coordinate =
                        selectedPlace.placemark.coordinate

                    MapCircle(
                        center: coordinate,
                        radius: selectedRadius
                    )
                    .foregroundStyle(
                        Color.blue.opacity(0.15)
                    )
                    .stroke(
                        Color.blue.opacity(0.8),
                        lineWidth: 2
                    )

                    Marker(
                        selectedPlace.name
                        ?? "Destination",
                        coordinate: coordinate
                    )
                    .tint(.red)
                }
            }
            .mapStyle(
                .standard(
                    elevation: .realistic
                )
            )
            .mapControls {

                MapCompass()

                MapUserLocationButton()
            }
            .frame(height: 320)
            .clipShape(
                RoundedRectangle(
                    cornerRadius: 24
                )
            )
            .onTapGesture { point in

                guard
                    let coordinate =
                        proxy.convert(
                            point,
                            from: .local
                        )
                else {
                    return
                }

                selectMapCoordinate(
                    coordinate
                )
            }
        }
    }

    // MARK: - Destination

    private func destinationCard(
        place: MKMapItem
    ) -> some View {

        VStack(
            alignment: .leading,
            spacing: 14
        ) {

            HStack {

                Text("Selected destination")
                    .font(.subheadline)
                    .foregroundStyle(.blue)

                Spacer()

                Button {

                    Task {

                        await trackingManager.stopTracking()

                        await MainActor.run {
                            route = nil
                        }
                    }

                } label: {

                    Image(
                        systemName: "xmark"
                    )
                    .foregroundStyle(.secondary)
                    .frame(
                        width: 36,
                        height: 36
                    )
                    .background(
                        Color.gray.opacity(0.12)
                    )
                    .clipShape(Circle())
                }
            }

            Text(
                place.name
                ?? "Selected location"
            )
            .font(.title2)
            .fontWeight(.bold)

            Text(
                place.placemark.title
                ?? "Address unavailable"
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)

            if let currentCoordinate {

                let destinationCoordinate =
                    place.placemark.coordinate

                let distance =
                    CLLocation(
                        latitude:
                            currentCoordinate.latitude,
                        longitude:
                            currentCoordinate.longitude
                    )
                    .distance(
                        from:
                            CLLocation(
                                latitude:
                                    destinationCoordinate.latitude,
                                longitude:
                                    destinationCoordinate.longitude
                            )
                    )

                HStack(spacing: 8) {

                    Image(
                        systemName:
                            "location.fill"
                    )
                    .foregroundStyle(.blue)

                    Text(
                        formatDistance(distance)
                    )
                    .font(.headline)

                    Text("away")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
        .padding(18)
        .background(.regularMaterial)
        .clipShape(
            RoundedRectangle(
                cornerRadius: 22
            )
        )
    }

    // MARK: - Radius

    private var radiusSection: some View {

        VStack(
            alignment: .leading,
            spacing: 14
        ) {

            HStack {

                Image(
                    systemName:
                        "dot.radiowaves.left.and.right"
                )
                .foregroundStyle(.blue)

                Text(
                    "Notify me when I'm within"
                )
                .font(.headline)

                Spacer()

                Text(radiusText)
                    .font(.headline)
                    .foregroundStyle(.blue)
            }

            Slider(
                value: $selectedRadius,
                in: 100...2000,
                step: 50
            )
            .tint(.blue)

            HStack {

                Text("100 m")

                Spacer()

                Text("2 km")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            Text(
                "The blue circle on the map shows your notification area."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(18)
        .background(.regularMaterial)
        .clipShape(
            RoundedRectangle(
                cornerRadius: 22
            )
        )
    }

    // MARK: - Tracking Controls

    private var trackingControls: some View {

        HStack(spacing: 10) {

            Button {

                if !trackingManager.isTracking {

                    guard
                        let destination =
                            selectedPlace
                    else {
                        return
                    }

                    let coordinate =
                        destination.placemark.coordinate

                    Task {

                        await trackingManager.startTracking(
                            name:
                                destination.name
                            ?? "Selected location",
                            address:
                                destination.placemark.title
                            ?? "Address unavailable",
                            latitude:
                                coordinate.latitude,
                            longitude:
                                coordinate.longitude,
                            radius:
                                selectedRadius
                        )
                    }

                } else if trackingManager.isPaused {

                    Task {

                        await trackingManager.resumeTracking()
                    }

                } else {

                    Task {

                        await trackingManager.pauseTracking()
                    }
                }

            } label: {

                HStack {

                    Image(
                        systemName:
                            !trackingManager.isTracking
                            ? "bell.fill"
                            : trackingManager.isPaused
                            ? "play.fill"
                            : "pause.fill"
                    )

                    Text(
                        !trackingManager.isTracking
                        ? "Start Tracking"
                        : trackingManager.isPaused
                        ? "Resume Tracking"
                        : "Pause Tracking"
                    )
                    .fontWeight(.semibold)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    trackingManager.isTracking &&
                    !trackingManager.isPaused
                    ? Color.blue
                    : Color.green
                )
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: 18
                    )
                )
            }

            if trackingManager.isTracking {

                Button {
                    Task {
                        await trackingManager.stopTracking()
                        route = nil
                    }
                } label: {
                    Image(systemName: "stop.fill")
                        .foregroundStyle(.red)
                        .frame(
                            width: 56,
                            height: 56
                        )
                        .background(
                            Color.red.opacity(0.08)
                        )
                        .clipShape(
                            RoundedRectangle(
                                cornerRadius: 18
                            )
                        )
                }
            }
        }
    }

    // MARK: - History

    private var historyView: some View {

        VStack(spacing: 16) {

            Spacer()

            Image(
                systemName:
                    "clock.arrow.circlepath"
            )
            .font(.system(size: 50))
            .foregroundStyle(.blue)

            Text("History")
                .font(.title)
                .fontWeight(.bold)

            Text(
                "Your completed tracking destinations will appear here."
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 40)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Bottom Navigation

    private var bottomNavigation: some View {

        HStack {

            bottomTab(
                icon: "house.fill",
                title: "Home",
                index: 0
            )

            bottomTab(
                icon: "clock",
                title: "History",
                index: 1
            )
        }
        .padding(.horizontal, 10)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(.regularMaterial)
        .overlay(alignment: .top) {

            Divider()
        }
    }

    private func bottomTab(
        icon: String,
        title: String,
        index: Int
    ) -> some View {

        Button {

            selectedTab = index

        } label: {

            VStack(spacing: 4) {

                Image(systemName: icon)

                Text(title)
                    .font(.caption)
            }
            .foregroundStyle(
                selectedTab == index
                ? .blue
                : .secondary
            )
            .frame(
                maxWidth: .infinity
            )
        }
    }

    // MARK: - Search

    private func performSearch() {

        let query =
            searchText.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        guard !query.isEmpty else {
            return
        }

        let request =
            MKLocalSearch.Request()

        request.naturalLanguageQuery =
            query

        if let coordinate =
            currentCoordinate {

            request.region =
                MKCoordinateRegion(
                    center: coordinate,
                    latitudinalMeters: 5000,
                    longitudinalMeters: 5000
                )
        }

        let search =
            MKLocalSearch(
                request: request
            )

        search.start { response, error in

            DispatchQueue.main.async {

                if let error {

                    print(
                        "Search failed: \(error.localizedDescription)"
                    )

                    searchResults = []

                    return
                }

                searchResults =
                    response?.mapItems ?? []

                if let first =
                    searchResults.first {

                    cameraPosition =
                        .region(
                            MKCoordinateRegion(
                                center:
                                    first.placemark.coordinate,
                                latitudinalMeters:
                                    3000,
                                longitudinalMeters:
                                    3000
                            )
                        )
                }
            }
        }
    }

    // MARK: - Select Place

    private func selectPlace(
        _ place: MKMapItem
    ) {

        selectedPlace =
            place

        searchResults = []

        searchText =
            place.name ?? ""

        zoomToSelectedPlace()

        calculateRoute(
            to: place
        )
    }

    // MARK: - Select Map Location

    private func selectMapCoordinate(
        _ coordinate:
            CLLocationCoordinate2D
    ) {

        let location =
            CLLocation(
                latitude:
                    coordinate.latitude,
                longitude:
                    coordinate.longitude
            )

        let geocoder =
            CLGeocoder()

        geocoder.reverseGeocodeLocation(
            location
        ) { placemarks, error in

            guard
                error == nil,
                let placemark =
                    placemarks?.first
            else {
                return
            }

            let mapItem =
                MKMapItem(
                    placemark:
                        MKPlacemark(
                            coordinate:
                                coordinate
                        )
                )

            mapItem.name =
                placemark.name
                ?? placemark.locality
                ?? "Selected location"

            DispatchQueue.main.async {

                selectedPlace =
                    mapItem

                searchResults = []

                searchText =
                    mapItem.name ?? ""

                zoomToSelectedPlace()

                calculateRoute(
                    to: mapItem
                )
            }
        }
    }

    // MARK: - Route

    private func calculateRoute(
        to destination: MKMapItem
    ) {

        guard
            let currentCoordinate
        else {
            return
        }

        let source =
            MKMapItem(
                placemark:
                    MKPlacemark(
                        coordinate:
                            currentCoordinate
                    )
            )

        let request =
            MKDirections.Request()

        request.source =
            source

        request.destination =
            destination

        request.transportType =
            .automobile

        let directions =
            MKDirections(
                request: request
            )

        directions.calculate {

            response,
            error in

            guard
                error == nil,
                let calculatedRoute =
                    response?.routes.first
            else {

                DispatchQueue.main.async {

                    route = nil
                }

                return
            }

            DispatchQueue.main.async {

                route =
                    calculatedRoute
            }
        }
    }

    private func updateRoute() {

        guard trackingManager.isTracking else {
            return
        }

        guard let selectedPlace else {
            return
        }

        calculateRoute(
            to: selectedPlace
        )
    }

    // MARK: - Map Camera

    private func zoomToSelectedPlace() {

        guard
            let selectedPlace
        else {
            return
        }

        let coordinate =
            selectedPlace.placemark.coordinate

        let meters =
            max(
                selectedRadius * 3,
                1000
            )

        cameraPosition =
            .region(
                MKCoordinateRegion(
                    center:
                        coordinate,
                    latitudinalMeters:
                        meters,
                    longitudinalMeters:
                        meters
                )
            )
    }

    // MARK: - NEW: Center Home Map

    private func centerHomeMapIfPossible() {

        guard
            selectedTab == 0,
            let coordinate = currentCoordinate
        else {
            return
        }

        // Close enough to clearly show the user's
        // current position without being too zoomed in.
        let meters: CLLocationDistance = 1500

        cameraPosition =
            .region(
                MKCoordinateRegion(
                    center: coordinate,
                    latitudinalMeters: meters,
                    longitudinalMeters: meters
                )
            )

        // We have successfully centered the map.
        shouldCenterHomeMap = false
    }

    // MARK: - Helpers

    private var currentCoordinate:
        CLLocationCoordinate2D? {

        guard
            let latitude =
                locationManager.latitude,
            let longitude =
                locationManager.longitude
        else {
            return nil
        }

        return CLLocationCoordinate2D(
            latitude:
                latitude,
            longitude:
                longitude
        )
    }

    private var radiusText: String {

        if selectedRadius >= 1000 {

            let km =
                selectedRadius / 1000

            return
                "\(String(format: "%.1f", km)) km"
        }

        return
            "\(Int(selectedRadius)) m"
    }

    private func formatDistance(
        _ distance:
            CLLocationDistance
    ) -> String {

        if distance >= 1000 {

            return String(
                format:
                    "%.1f km",
                distance / 1000
            )
        }

        return
            "\(Int(distance)) m"
    }
}

#Preview {
    ContentView()
}
