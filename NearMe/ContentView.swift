import SwiftUI
import CoreLocation
import MapKit

struct ContentView: View {

    @StateObject private var locationManager = LocationManager()
    @StateObject private var trackingManager = TrackingManager()
    @StateObject private var searchCompleter = SearchCompleter()

    @State private var searchResults: [MKMapItem] = []
    @State private var selectedPlace: MKMapItem?
    @State private var route: MKRoute?
    @State private var selectedRadius: CLLocationDistance = 500

    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var selectedTab = 0 // 0 = Home, 1 = History

    // NEW properties for bottom sheet
    @State private var showSheet = true
    @State private var sheetDetent: PresentationDetent = .fraction(0.15)
    @State private var shouldCenterHomeMap = true

    var body: some View {
        ZStack(alignment: .top) {
            // 1. Full-screen map
            mapSection
                .ignoresSafeArea()

            // 2. Floating Header and Status
            VStack(spacing: 12) {
                header
                
                if trackingManager.isTracking {
                    trackingStatusCard
                        .padding(.horizontal, 16)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(.spring(), value: trackingManager.isTracking)
        }
        .sheet(isPresented: $showSheet) {
            sheetContent
                .presentationDetents([.fraction(0.15), .medium, .large], selection: $sheetDetent)
                .presentationBackgroundInteraction(.enabled(upThrough: .medium))
                .presentationCornerRadius(32)
                .presentationBackground(.thinMaterial)
                .interactiveDismissDisabled()
        }
        .onAppear {
            locationManager.requestLocation()
            centerHomeMapIfPossible()
            searchCompleter.updateRegion(currentCoordinate)
        }
        .onChange(of: locationManager.latitude) { _, _ in
            checkDistance()
            updateRoute()
            searchCompleter.updateRegion(currentCoordinate)
            if selectedTab == 0 && shouldCenterHomeMap {
                centerHomeMapIfPossible()
            }
        }
        .onChange(of: selectedPlace) { _, place in
            if place != nil {
                sheetDetent = .medium
            }
        }
    }

    // MARK: - Header
    private var header: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "location.north.circle.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(.blue)
                
                Text("NearMe")
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.regularMaterial)
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.1), radius: 5, y: 2)
            
            Spacer()
            
            Button(action: {
                // Toggle history view inside sheet
                withAnimation {
                    selectedTab = selectedTab == 0 ? 1 : 0
                    if selectedTab == 1 {
                        sheetDetent = .large
                    } else {
                        sheetDetent = .fraction(0.15)
                    }
                }
            }) {
                Image(systemName: selectedTab == 0 ? "clock.fill" : "map.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(selectedTab == 0 ? Color.secondary : Color.blue)
                    .frame(width: 44, height: 44)
                    .background(.regularMaterial)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.1), radius: 5, y: 2)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
    }

    // MARK: - Floating Tracking Status
    private var trackingStatusCard: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(trackingManager.isPaused ? Color.orange.opacity(0.2) : Color.green.opacity(0.2))
                    .frame(width: 44, height: 44)
                
                Image(systemName: trackingManager.isPaused ? "pause.fill" : "location.fill")
                    .foregroundStyle(trackingManager.isPaused ? .orange : .green)
                    .font(.system(size: 20))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(trackingManager.isPaused ? "Tracking Paused" : "Tracking Active")
                    .font(.headline)
                    .fontWeight(.bold)
                
                if let selectedPlace {
                    Text("\(selectedPlace.name ?? "Destination") • \(radiusText)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()
        }
        .padding(12)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.15), radius: 10, y: 5)
    }

    // MARK: - Map Section
    private var mapSection: some View {
        MapReader { proxy in
            Map(position: $cameraPosition) {
                UserAnnotation()
                
                if trackingManager.isTracking, let route {
                    MapPolyline(route.polyline)
                        .stroke(Color.blue.opacity(0.8), lineWidth: 6)
                }
                
                if let selectedPlace {
                    let coordinate = selectedPlace.placemark.coordinate
                    
                    MapCircle(center: coordinate, radius: selectedRadius)
                        .foregroundStyle(Color.blue.opacity(0.15))
                        .stroke(Color.blue, lineWidth: 2)
                    
                    Marker(selectedPlace.name ?? "Destination", coordinate: coordinate)
                        .tint(.red)
                }
            }
            .mapStyle(.standard(elevation: .realistic))
            .mapControls {
                MapCompass()
                MapUserLocationButton()
            }
            .onTapGesture { point in
                guard let coordinate = proxy.convert(point, from: .local) else { return }
                selectMapCoordinate(coordinate)
            }
        }
    }

    // MARK: - Bottom Sheet Content
    private var sheetContent: some View {
        VStack(spacing: 0) {
            // Drag indicator is provided automatically by presentationDetents
            
            if selectedTab == 0 {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        searchSection
                        
                        if let selectedPlace {
                            VStack(spacing: 16) {
                                destinationCard(place: selectedPlace)
                                radiusSection
                                trackingControls
                            }
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                        } else if searchResults.isEmpty {
                            // Empty state guidance
                            VStack(spacing: 12) {
                                Image(systemName: "magnifyingglass.circle.fill")
                                    .font(.system(size: 40))
                                    .foregroundStyle(.tertiary)
                                Text("Search for a place or tap on the map to set a destination.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.top, 40)
                        }
                    }
                    .padding(20)
                }
            } else {
                historyView
            }
        }
        .animation(.easeInOut, value: selectedPlace)
        .animation(.easeInOut, value: searchResults)
    }

    // MARK: - Search Section
    private var searchSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 18, weight: .medium))

                TextField("Search places...", text: $searchCompleter.searchQuery)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.search)
                    .onSubmit { performSearch() }

                if !searchCompleter.searchQuery.isEmpty {
                    Button(action: {
                        searchCompleter.searchQuery = ""
                        searchCompleter.completions = []
                        searchResults = []
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(14)
            .background(Color(uiColor: .tertiarySystemFill))
            .clipShape(RoundedRectangle(cornerRadius: 16))

            if !searchCompleter.completions.isEmpty {
                VStack(spacing: 1) {
                    ForEach(searchCompleter.completions, id: \.self) { completion in
                        Button(action: { selectCompletion(completion) }) {
                            HStack(spacing: 16) {
                                Image(systemName: "mappin.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundStyle(.blue)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(completion.title)
                                        .font(.body)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.primary)
                                    Text(completion.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 12)
                            .padding(.horizontal, 16)
                            .background(Color(uiColor: .secondarySystemGroupedBackground))
                        }
                        Divider().padding(.leading, 56)
                    }
                }
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            } else if !searchResults.isEmpty {
                VStack(spacing: 1) {
                    ForEach(searchResults, id: \.self) { place in
                        Button(action: { selectPlace(place) }) {
                            HStack(spacing: 16) {
                                Image(systemName: "mappin.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundStyle(.blue)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(place.name ?? "Unknown")
                                        .font(.body)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.primary)
                                    Text(place.placemark.title ?? "Address unavailable")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 12)
                            .padding(.horizontal, 16)
                            .background(Color(uiColor: .secondarySystemGroupedBackground))
                        }
                        Divider().padding(.leading, 56)
                    }
                }
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    // MARK: - Destination Card
    private func destinationCard(place: MKMapItem) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Destination")
                    .font(.caption)
                    .fontWeight(.bold)
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)
                Spacer()
                Button(action: {
                    Task {
                        await trackingManager.stopTracking()
                        await MainActor.run {
                            selectedPlace = nil
                            route = nil
                            searchCompleter.searchQuery = ""
                            searchCompleter.completions = []
                            searchResults = []
                            sheetDetent = .fraction(0.15)
                        }
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.tertiary)
                }
            }
            
            Text(place.name ?? "Selected location")
                .font(.title3)
                .fontWeight(.bold)
            
            Text(place.placemark.title ?? "Address unavailable")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            if let currentCoordinate {
                let dest = place.placemark.coordinate
                let distance = CLLocation(latitude: currentCoordinate.latitude, longitude: currentCoordinate.longitude)
                    .distance(from: CLLocation(latitude: dest.latitude, longitude: dest.longitude))
                
                HStack(spacing: 6) {
                    Image(systemName: "location.fill").foregroundStyle(.blue)
                    Text(formatDistance(distance)).fontWeight(.medium)
                    Text("away").foregroundStyle(.secondary)
                }
                .font(.subheadline)
                .padding(.top, 4)
            }
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Radius Controls
    private var radiusSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Notification Radius")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                Text(radiusText)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundStyle(.blue)
            }
            
            Slider(value: $selectedRadius, in: 100...2000, step: 50)
                .tint(.blue)
            
            HStack {
                Text("100 m")
                Spacer()
                Text("2 km")
            }
            .font(.caption2)
            .foregroundStyle(.tertiary)
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Tracking Controls
    private var trackingControls: some View {
        HStack(spacing: 12) {
            Button(action: {
                if !trackingManager.isTracking {
                    guard let destination = selectedPlace else { return }
                    let coordinate = destination.placemark.coordinate
                    Task {
                        await trackingManager.startTracking(
                            name: destination.name ?? "Location",
                            address: destination.placemark.title,
                            latitude: coordinate.latitude,
                            longitude: coordinate.longitude,
                            radius: selectedRadius
                        )
                        sheetDetent = .fraction(0.15)
                    }
                } else if trackingManager.isPaused {
                    Task { await trackingManager.resumeTracking() }
                } else {
                    Task { await trackingManager.pauseTracking() }
                }
            }) {
                HStack {
                    Image(systemName: !trackingManager.isTracking ? "bell.fill" : trackingManager.isPaused ? "play.fill" : "pause.fill")
                    Text(!trackingManager.isTracking ? "Start Tracking" : trackingManager.isPaused ? "Resume" : "Pause")
                        .fontWeight(.bold)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(!trackingManager.isTracking ? Color.blue : trackingManager.isPaused ? Color.green : Color.orange)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            
            if trackingManager.isTracking {
                Button(action: {
                    Task {
                        await trackingManager.stopTracking()
                        route = nil
                    }
                }) {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 54, height: 54)
                        .background(Color.red)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
        }
    }

    // MARK: - History
    private var historyView: some View {
        VStack(spacing: 20) {
            Text("History")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.top, 20)
            
            Spacer()
            
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 60))
                .foregroundStyle(.tertiary)
            
            Text("No recent destinations")
                .font(.headline)
            Text("Your completed tracking destinations will appear here.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Logic Helpers
    private func selectCompletion(_ completion: MKLocalSearchCompletion) {
        let request = MKLocalSearch.Request(completion: completion)
        MKLocalSearch(request: request).start { response, _ in
            DispatchQueue.main.async {
                if let place = response?.mapItems.first {
                    self.selectPlace(place)
                }
            }
        }
    }

    private func performSearch() {
        let query = searchCompleter.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        if let coordinate = currentCoordinate {
            request.region = MKCoordinateRegion(center: coordinate, latitudinalMeters: 5000, longitudinalMeters: 5000)
        }
        
        MKLocalSearch(request: request).start { response, _ in
            DispatchQueue.main.async {
                self.searchResults = response?.mapItems ?? []
                self.searchCompleter.completions = []
                if let first = self.searchResults.first {
                    self.cameraPosition = .region(MKCoordinateRegion(center: first.placemark.coordinate, latitudinalMeters: 3000, longitudinalMeters: 3000))
                }
                self.sheetDetent = .medium
            }
        }
    }

    private func selectPlace(_ place: MKMapItem) {
        selectedPlace = place
        searchResults = []
        searchCompleter.completions = []
        searchCompleter.searchQuery = place.name ?? ""
        zoomToSelectedPlace()
        calculateRoute(to: place)
    }

    private func selectMapCoordinate(_ coordinate: CLLocationCoordinate2D) {
        CLGeocoder().reverseGeocodeLocation(CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)) { placemarks, _ in
            guard let placemark = placemarks?.first else { return }
            let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
            mapItem.name = placemark.name ?? placemark.locality ?? "Selected location"
            
            DispatchQueue.main.async {
                self.selectedPlace = mapItem
                self.searchResults = []
                self.searchCompleter.completions = []
                self.searchCompleter.searchQuery = mapItem.name ?? ""
                self.zoomToSelectedPlace()
                self.calculateRoute(to: mapItem)
                self.sheetDetent = .medium
            }
        }
    }

    private func calculateRoute(to destination: MKMapItem) {
        guard let currentCoordinate else { return }
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: currentCoordinate))
        request.destination = destination
        request.transportType = .automobile
        
        MKDirections(request: request).calculate { response, _ in
            DispatchQueue.main.async { self.route = response?.routes.first }
        }
    }

    @State private var lastRouteUpdate: Date = .distantPast

    private func updateRoute() {
        guard trackingManager.isTracking, let selectedPlace else { return }
        let now = Date()
        // Throttle to 1 update every 10 seconds to prevent MKDirections spam crash
        guard now.timeIntervalSince(lastRouteUpdate) > 10 else { return }
        lastRouteUpdate = now
        calculateRoute(to: selectedPlace)
    }

    private func zoomToSelectedPlace() {
        guard let selectedPlace else { return }
        let meters = max(selectedRadius * 3, 1000)
        cameraPosition = .region(MKCoordinateRegion(center: selectedPlace.placemark.coordinate, latitudinalMeters: meters, longitudinalMeters: meters))
    }

    private func centerHomeMapIfPossible() {
        guard selectedTab == 0, let coordinate = currentCoordinate else { return }
        let meters: CLLocationDistance = 1500
        cameraPosition = .region(MKCoordinateRegion(center: coordinate, latitudinalMeters: meters, longitudinalMeters: meters))
        shouldCenterHomeMap = false
    }

    private func checkDistance() {
        guard trackingManager.isTracking, !trackingManager.isPaused,
              let destLat = trackingManager.destinationLatitude,
              let destLon = trackingManager.destinationLongitude,
              let userLat = locationManager.latitude,
              let userLon = locationManager.longitude else { return }
              
        let destLoc = CLLocation(latitude: destLat, longitude: destLon)
        let userLoc = CLLocation(latitude: userLat, longitude: userLon)
        
        if userLoc.distance(from: destLoc) <= trackingManager.radius {
            Task {
                await trackingManager.destinationReached()
            }
        }
    }

    private var currentCoordinate: CLLocationCoordinate2D? {
        guard let lat = locationManager.latitude, let lon = locationManager.longitude else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    private var radiusText: String {
        selectedRadius >= 1000 ? "\(String(format: "%.1f", selectedRadius / 1000)) km" : "\(Int(selectedRadius)) m"
    }

    private func formatDistance(_ distance: CLLocationDistance) -> String {
        distance >= 1000 ? String(format: "%.1f km", distance / 1000) : "\(Int(distance)) m"
    }
}
