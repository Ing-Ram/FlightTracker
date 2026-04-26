//
//  FlightService.swift
//  FlightTracker
//
//  Created by chad ingram on 4/24/26.
//

import Foundation

struct AviationStackErrorResponse: Decodable {
    let error: AviationStackError
}

struct AviationStackError: Decodable {
    let message: String
}

enum FlightServiceError: LocalizedError {
    case missingAPIKey
    case invalidURL
    case apiError(String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "The AviationStack API key is missing from the app configuration."
        case .invalidURL:
            return "The flight lookup URL is invalid."
        case let .apiError(message):
            return message
        case .invalidResponse:
            return "The flight service returned an unexpected response."
        }
    }
}

final class FlightService {
    private let apiKey = (
        Bundle.main.object(forInfoDictionaryKey: "AviationStackAPIKey") as? String ?? ""
    )
    .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
    private let cache = FlightResponseCache()

    func fetchFlights(flightNumber: String, date: String) async throws -> [Flight] {
        let normalizedFlightNumber = flightNumber
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()

        do {
            let flights = try await requestFlights(
                flightNumber: normalizedFlightNumber,
                date: date
            )

            if flights.isEmpty {
                return try await requestFlights(
                    flightNumber: normalizedFlightNumber,
                    date: nil
                )
            }

            return flights
        } catch let FlightServiceError.apiError(message)
            where message.localizedCaseInsensitiveContains("subscription plan does not support this API function") {
            return try await requestFlights(
                flightNumber: normalizedFlightNumber,
                date: nil
            )
        }
    }

    private func requestFlights(flightNumber: String, date: String?) async throws -> [Flight] {
        guard !apiKey.isEmpty else {
            throw FlightServiceError.missingAPIKey
        }

        let cacheKey = cache.cacheKey(for: flightNumber, date: date)

        if let cachedFlights = cache.cachedFlights(for: cacheKey) {
            return cachedFlights
        }

        var urlString = "https://api.aviationstack.com/v1/flights?access_key=\(apiKey)&flight_iata=\(flightNumber)"

        if let date {
            urlString += "&flight_date=\(date)"
        }

        guard let url = URL(string: urlString) else {
            throw FlightServiceError.invalidURL
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)

            if let decoded = try? JSONDecoder().decode(FlightResponse.self, from: data) {
                cache.store(decoded.data, for: cacheKey)
                return decoded.data
            }

            if let apiError = try? JSONDecoder().decode(AviationStackErrorResponse.self, from: data) {
                throw FlightServiceError.apiError(apiError.error.message)
            }
        } catch {
            if let cachedFlights = cache.fallbackFlights(for: cacheKey) {
                return cachedFlights
            }

            throw error
        }

        throw FlightServiceError.invalidResponse
    }
}

private final class FlightResponseCache {
    private struct CacheEntry: Codable {
        let timestamp: Date
        let flights: [Flight]
    }

    private let defaults = UserDefaults.standard
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()
    private let freshCacheLifetime: TimeInterval = 15 * 60
    private let fallbackCacheLifetime: TimeInterval = 24 * 60 * 60
    private let keyPrefix = "flight_cache_"

    func cacheKey(for flightNumber: String, date: String?) -> String {
        let suffix = date ?? "any-date"
        return "\(keyPrefix)\(flightNumber)_\(suffix)"
    }

    func cachedFlights(for key: String) -> [Flight]? {
        guard let entry = loadEntry(for: key) else {
            return nil
        }

        guard Date().timeIntervalSince(entry.timestamp) <= freshCacheLifetime else {
            return nil
        }

        return entry.flights
    }

    func fallbackFlights(for key: String) -> [Flight]? {
        guard let entry = loadEntry(for: key) else {
            return nil
        }

        guard Date().timeIntervalSince(entry.timestamp) <= fallbackCacheLifetime else {
            return nil
        }

        return entry.flights
    }

    func store(_ flights: [Flight], for key: String) {
        let entry = CacheEntry(timestamp: Date(), flights: flights)

        guard let data = try? encoder.encode(entry) else {
            return
        }

        defaults.set(data, forKey: key)
    }

    private func loadEntry(for key: String) -> CacheEntry? {
        guard let data = defaults.data(forKey: key) else {
            return nil
        }

        return try? decoder.decode(CacheEntry.self, from: data)
    }
}
