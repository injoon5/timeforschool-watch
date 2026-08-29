import Foundation

/// URL construction for the timefor.school API.
enum SchoolEndpoint {
    static let host = "api.timefor.school"

    static func timetable(_ identity: SchoolIdentity) -> URL? {
        url(path: "/timetable", identity: identity, extra: [:])
    }

    static func meals(_ identity: SchoolIdentity, from: SchoolDate, to: SchoolDate) -> URL? {
        url(path: "/lunch", identity: identity, extra: [
            "startdate": from.compactString,
            "enddate": to.compactString,
        ])
    }

    private static func url(path: String, identity: SchoolIdentity, extra: [String: String]) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = host
        components.path = path
        components.queryItems = [
            URLQueryItem(name: "schoolcode", value: identity.schoolCode),
            URLQueryItem(name: "grade", value: String(identity.grade)),
            URLQueryItem(name: "classno", value: String(identity.classNumber)),
        ] + extra.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
        return components.url
    }
}
