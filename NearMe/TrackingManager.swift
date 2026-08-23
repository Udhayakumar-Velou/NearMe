import Foundation
import CoreLocation
import Combine
import UserNotifications

@MainActor
final class TrackingManager: ObservableObject {

    // MARK: - Published State

    @Published var isTracking = false
    @Published var isPaused = false

    @Published var destinationName: String?
    @Published var destinationAddress: String?

    @Published var destinationLatitude: Double?
    @Published var destinationLongitude: Double?

    @Published var radius: CLLocationDistance = 500

    @Published var trackingMessage = "Not tracking"

    // MARK: - Private Properties

    private let monitorName = "NearMeTrackingMonitor"
    private let conditionIdentifier = "NearMeDestination"

    private var monitor: CLMonitor?

    // MARK: - Start Tracking

    func startTracking(
        name: String,
        address: String?,
        latitude: Double,
        longitude: Double,
        radius: CLLocationDistance
    ) async {

        destinationName = name
        destinationAddress = address

        destinationLatitude = latitude
        destinationLongitude = longitude

        self.radius = radius

        isTracking = true
        isPaused = false
        trackingMessage = "Starting tracking..."

        // Ask for notification permission
        await requestNotificationPermission()

        // Create the Core Location monitor
        let newMonitor = await CLMonitor(monitorName)

        monitor = newMonitor

        // Destination coordinate
        let coordinate = CLLocationCoordinate2D(
            latitude: latitude,
            longitude: longitude
        )

        // Create the notification area
        let condition = CLMonitor.CircularGeographicCondition(
            center: coordinate,
            radius: radius
        )

        // Remove an existing condition if necessary
        let existingIdentifiers = await newMonitor.identifiers

        if existingIdentifiers.contains(conditionIdentifier) {
            await newMonitor.remove(conditionIdentifier)
        }

        // Add the new geographic condition
        await newMonitor.add(
            condition,
            identifier: conditionIdentifier,
            assuming: .unsatisfied
        )

        trackingMessage =
            "You'll be notified within \(formattedRadius(radius))"

        // Start listening for location events
        Task {
            await monitorEvents(newMonitor)
        }
    }

    // MARK: - Monitor Events

    private func monitorEvents(_ monitor: CLMonitor) async {

        do {

            for try await event in await monitor.events {

                guard event.identifier == conditionIdentifier else {
                    continue
                }

                switch event.state {

                case .satisfied:

                    await destinationReached()

                case .unsatisfied:

                    trackingMessage = "Tracking active"

                case .unknown:

                    trackingMessage = "Waiting for location..."

                case .unmonitored:

                    trackingMessage = "Tracking stopped"
                    isTracking = false

                @unknown default:

                    break
                }
            }

        } catch {

            trackingMessage =
                "Tracking error: \(error.localizedDescription)"
        }
    }

    // MARK: - Destination Reached

    private func destinationReached() async {

        guard isTracking else {
            return
        }

        let name = destinationName ?? "your destination"

        await sendNotification(
            title: "You're near \(name)",
            body: "You are within \(formattedRadius(radius)) of your destination."
        )

        trackingMessage = "Destination reached"
        isTracking = false

        // Stop monitoring after arrival
        if let monitor {
            await monitor.remove(conditionIdentifier)
        }
    }

    // MARK: - Pause Tracking

    func pauseTracking() async {

        guard isTracking else {
            return
        }

        isPaused = true
        trackingMessage = "Tracking paused"

        if let monitor {

            let identifiers = await monitor.identifiers

            if identifiers.contains(conditionIdentifier) {
                await monitor.remove(conditionIdentifier)
            }
        }
    }

    // MARK: - Resume Tracking

    func resumeTracking() async {

        guard
            let latitude = destinationLatitude,
            let longitude = destinationLongitude
        else {
            return
        }

        let coordinate = CLLocationCoordinate2D(
            latitude: latitude,
            longitude: longitude
        )

        let condition = CLMonitor.CircularGeographicCondition(
            center: coordinate,
            radius: radius
        )

        // Create monitor if necessary
        if monitor == nil {
            monitor = await CLMonitor(monitorName)
        }

        guard let monitor else {
            return
        }

        // Remove old condition
        let identifiers = await monitor.identifiers

        if identifiers.contains(conditionIdentifier) {
            await monitor.remove(conditionIdentifier)
        }

        // Add condition again
        await monitor.add(
            condition,
            identifier: conditionIdentifier,
            assuming: .unsatisfied
        )

        isPaused = false
        isTracking = true
        trackingMessage = "Tracking active"

        Task {
            await monitorEvents(monitor)
        }
    }

    // MARK: - Stop Tracking

    func stopTracking() async {

        if let monitor {

            let identifiers = await monitor.identifiers

            if identifiers.contains(conditionIdentifier) {
                await monitor.remove(conditionIdentifier)
            }
        }

        isTracking = false
        isPaused = false

        trackingMessage = "Not tracking"
    }

    // MARK: - Notification Permission

    private func requestNotificationPermission() async {

        let center = UNUserNotificationCenter.current()

        do {

            let granted = try await center.requestAuthorization(
                options: [
                    .alert,
                    .sound,
                    .badge
                ]
            )

            if !granted {

                trackingMessage =
                    "Notifications are disabled"
            }

        } catch {

            print(
                "Notification permission error: \(error.localizedDescription)"
            )
        }
    }

    // MARK: - Send Notification

    private func sendNotification(
        title: String,
        body: String
    ) async {

        let content = UNMutableNotificationContent()

        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "NearMe-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        do {

            try await UNUserNotificationCenter
                .current()
                .add(request)

        } catch {

            print(
                "Notification error: \(error.localizedDescription)"
            )
        }
    }

    // MARK: - Format Radius

    private func formattedRadius(
        _ radius: CLLocationDistance
    ) -> String {

        if radius >= 1000 {

            let kilometers = radius / 1000

            if kilometers.truncatingRemainder(dividingBy: 1) == 0 {
                return "\(Int(kilometers)) km"
            }

            return String(
                format: "%.1f km",
                kilometers
            )

        } else {

            return "\(Int(radius)) m"
        }
    }
}
