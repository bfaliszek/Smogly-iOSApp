import Foundation

// MARK: - Air Quality Response Models
// Based on the actual API response: {"date":"2025-07-12 10:13:18","lat":50.179211,"long":19.150425,"measurer":"SDS011","pm10":3.63,"pm25":2.05,"sensor":"Luftdaten"}

struct AirQualityResponse: Codable {
    let date: String
    let lat: Double
    let long: Double
    let measurer: String?
    let pm10: Double?
    let pm25: Double?
    let sensor: String?
    
    // Convert to our internal format
    func toAirQualityData() -> AirQualityData {
        let measurements = [
            pm25.map { Measurement(parameter: "PM2.5", value: $0, unit: "μg/m³", lastUpdated: date) },
            pm10.map { Measurement(parameter: "PM10", value: $0, unit: "μg/m³", lastUpdated: date) }
        ].compactMap { $0 }
        
        return AirQualityData(
            id: UUID().uuidString,
            location: Location(coordinates: [long, lat], type: "Point"),
            measurements: measurements,
            datasource: sensor ?? "Unknown",
            timestamp: date
        )
    }
}

struct AirQualityData: Codable, Identifiable {
    let id: String
    let location: Location
    let measurements: [Measurement]
    let datasource: String
    let timestamp: String
}

struct Location: Codable {
    let coordinates: [Double]
    let type: String
}

struct Measurement: Codable {
    let parameter: String
    let value: Double
    let unit: String
    let lastUpdated: String
}

// MARK: - Data Source Enum
enum DataSource: String, CaseIterable {
    case all = "ALL"
    case gios = "GIOS"
    case luftdaten = "LUFTDATEN"
    case looko2 = "LOOKO2"
    case awairKato = "AWAIR_KATO"
    case openaqLt = "OPENAQ_LT"
    case syngeos = "SYNGEOS"
    
    var displayName: String {
        switch self {
        case .all:
            return "All Sources"
        case .gios:
            return "GIOS"
        case .luftdaten:
            return "Luftdaten"
        case .looko2:
            return "LookO2"
        case .awairKato:
            return "Awair Kato"
        case .openaqLt:
            return "OpenAQ LT"
        case .syngeos:
            return "Syngeos"
        }
    }
}

// MARK: - Air Quality Index Helper
struct AirQualityIndex {
    static func getAQICategory(for pm25: Double) -> String {
        switch pm25 {
        case 0..<12:
            return "Good"
        case 12..<35.4:
            return "Moderate"
        case 35.4..<55.4:
            return "Unhealthy for Sensitive Groups"
        case 55.4..<150.4:
            return "Unhealthy"
        case 150.4..<250.4:
            return "Very Unhealthy"
        default:
            return "Hazardous"
        }
    }
    
    static func getAQIColor(for pm25: Double) -> String {
        switch pm25 {
        case 0..<12:
            return "green"
        case 12..<35.4:
            return "yellow"
        case 35.4..<55.4:
            return "orange"
        case 55.4..<150.4:
            return "red"
        case 150.4..<250.4:
            return "purple"
        default:
            return "maroon"
        }
    }
} 