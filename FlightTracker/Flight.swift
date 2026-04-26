import Foundation

struct FlightResponse: Codable {
    let data: [Flight]
}

struct Flight: Codable, Identifiable {
    var id = UUID()
    let flight_date: String?
    let airline: Airline?
    let flight: FlightInfo
    let departure: Airport
    let arrival: Airport
    let flight_status: String

    enum CodingKeys: String, CodingKey {
        case flight_date
        case airline
        case flight
        case departure
        case arrival
        case flight_status
    }
}

struct Airline: Codable {
    let name: String?
    let iata: String?
}

struct FlightInfo: Codable {
    let number: String?
    let iata: String?
}

struct Airport: Codable {
    let airport: String?
    let iata: String?
    let timezone: String?
    let delay: Int?
    let scheduled: String?
}
