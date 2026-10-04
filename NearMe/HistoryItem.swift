import Foundation
import SwiftData
import MapKit

@Model
class HistoryItem: Identifiable, Hashable {
    @Attribute(.unique) var id: UUID
    var name: String
    var address: String?
    var latitude: Double
    var longitude: Double
    var date: Date
    
    init(id: UUID = UUID(), name: String, address: String? = nil, latitude: Double, longitude: Double, date: Date = Date()) {
        self.id = id
        self.name = name
        self.address = address
        self.latitude = latitude
        self.longitude = longitude
        self.date = date
    }
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
