import Foundation

/// The API's error shape, returned with a 4xx status instead of a payload.
///
/// `NEIS_DATA_NOT_FOUND` is not really a failure: the upstream simply has no
/// menu for the requested range — during vacation, or before the next month is
/// published — so the app treats it as an empty, cacheable result.
struct APIErrorEnvelope: Decodable, Sendable {
    struct Payload: Decodable, Sendable {
        var code: String
        var message: String
    }

    var ok: Bool
    var error: Payload

    static let noData = "NEIS_DATA_NOT_FOUND"

    var isEmptyResult: Bool { error.code == Self.noData }
}
