import Foundation
import os

/// JSON snapshot persistence shared by the app and its widgets.
///
/// Reads are synchronous by design: the snapshots are a few kilobytes, and
/// loading them inline at launch means the first frame already has content
/// instead of flashing an empty list. Writes are atomic so a widget can never
/// observe a half-written file.
enum SnapshotStorage {
    static let appGroup = "group.school.timefor.watch"

    private static let logger = Logger(subsystem: "school.timefor.watch", category: "cache")

    private static let directory: URL = {
        let base = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)
            ?? FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let folder = base.appending(path: "Snapshots", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }()

    private static let decoder = JSONDecoder()
    private static let encoder = JSONEncoder()

    static func load<T: Decodable>(_ type: T.Type, from file: SnapshotFile) -> T? {
        guard let data = try? Data(contentsOf: url(for: file), options: .mappedIfSafe) else { return nil }
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            logger.error("Discarding unreadable \(file.rawValue, privacy: .public) snapshot")
            try? FileManager.default.removeItem(at: url(for: file))
            return nil
        }
    }

    static func save(_ value: some Encodable, to file: SnapshotFile) {
        do {
            let data = try encoder.encode(value)
            try data.write(to: url(for: file), options: .atomic)
        } catch {
            logger.error("Failed to write \(file.rawValue, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }

    private static func url(for file: SnapshotFile) -> URL {
        directory.appending(path: file.rawValue + ".json", directoryHint: .notDirectory)
    }
}

enum SnapshotFile: String, Sendable {
    case timetable
    case meals
}
