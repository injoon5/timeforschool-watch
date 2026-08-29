import Foundation
import os

/// Network access to the timefor.school API.
///
/// Requests fail fast rather than waiting for connectivity: every screen has a
/// cached snapshot to fall back on, so a hanging request would only delay the
/// UI it is meant to improve.
actor SchoolAPI {
    static let shared = SchoolAPI()

    private let session: URLSession
    private let logger = Logger(subsystem: "school.timefor", category: "network")

    init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 10
        configuration.timeoutIntervalForResource = 20
        configuration.waitsForConnectivity = false
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.httpAdditionalHeaders = ["Accept": "application/json"]
        session = URLSession(configuration: configuration)
    }

    func week(for identity: SchoolIdentity) async throws -> SchoolWeek {
        guard let url = SchoolEndpoint.timetable(identity) else { throw SchoolAPIError.badURL }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let response: TimetableResponse = try await get(url, decoder: decoder)
        return response.makeWeek()
    }

    /// Fetches every meal served in `from...to`.
    ///
    /// - Returns: an empty array when the upstream reports no menu for the
    ///   range, which is the normal answer over vacations and weekends.
    func meals(for identity: SchoolIdentity, from: SchoolDate, to: SchoolDate) async throws -> [Meal] {
        guard let url = SchoolEndpoint.meals(identity, from: from, to: to) else { throw SchoolAPIError.badURL }
        do {
            let payload: [MealDTO] = try await get(url, decoder: JSONDecoder())
            return payload.compactMap { $0.makeMeal() }
        } catch SchoolAPIError.empty {
            return []
        }
    }

    private func get<T: Decodable>(_ url: URL, decoder: JSONDecoder) async throws -> T {
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse else { throw SchoolAPIError.transport }

        guard (200..<300).contains(http.statusCode) else {
            let envelope = try? JSONDecoder().decode(APIErrorEnvelope.self, from: data)
            if envelope?.isEmptyResult == true { throw SchoolAPIError.empty }
            logger.error("\(url.path, privacy: .public) failed: \(http.statusCode) \(envelope?.error.code ?? "-", privacy: .public)")
            throw SchoolAPIError.status(http.statusCode, code: envelope?.error.code)
        }

        return try decoder.decode(T.self, from: data)
    }
}

enum SchoolAPIError: Error {
    case badURL
    case transport
    /// The upstream has no data for the request — a valid, cacheable answer.
    case empty
    case status(Int, code: String?)
}
