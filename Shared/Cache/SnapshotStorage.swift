import Foundation
import Synchronization
import os

/// JSON snapshot persistence shared by the app and its widgets.
///
/// Reads are synchronous by design: the snapshots are a few kilobytes, and
/// loading them inline at launch means the first frame already has content
/// instead of flashing an empty list. Writes are atomic so a widget can never
/// observe a half-written file.
///
/// Decoded values are memoised per process and validated against the file's
/// modification date. A widget refresh reads the same snapshot several times —
/// once to decide whether it is stale, again to build the timeline — and on a
/// watch that is disk I/O and a `JSONDecoder` pass worth skipping.
enum SnapshotStorage {
    static let appGroup = "group.school.timefor.watch"

    private static let logger = Logger(subsystem: "school.timefor.watch", category: "cache")

    /// One decoded snapshot and the file stamp it was decoded from.
    private struct Memo {
        var modifiedAt: Date
        var value: any Sendable
    }

    private static let memos = Mutex<[SnapshotFile: Memo]>([:])

    private static let directory: URL = {
        let base = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)
            ?? FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let folder = base.appending(path: "Snapshots", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }()

    private static let decoder = JSONDecoder()
    private static let encoder = JSONEncoder()

    static func load<T: Decodable & Sendable>(_ type: T.Type, from file: SnapshotFile) -> T? {
        let url = url(for: file)
        let modifiedAt = try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate

        if let modifiedAt, let memo = memos.withLock({ $0[file] }),
           memo.modifiedAt == modifiedAt, let value = memo.value as? T {
            return value
        }

        guard let data = try? Data(contentsOf: url, options: .mappedIfSafe) else { return nil }
        do {
            let value = try decoder.decode(T.self, from: data)
            if let modifiedAt {
                memos.withLock { $0[file] = Memo(modifiedAt: modifiedAt, value: value) }
            }
            return value
        } catch {
            logger.error("Discarding unreadable \(file.rawValue, privacy: .public) snapshot")
            memos.withLock { $0[file] = nil }
            try? FileManager.default.removeItem(at: url)
            return nil
        }
    }

    static func save(_ value: some Encodable, to file: SnapshotFile) {
        do {
            let data = try encoder.encode(value)
            try data.write(to: url(for: file), options: .atomic)
            // The written file carries a new modification date, so the memo
            // would miss anyway; dropping it keeps stale bytes from being
            // handed back if the clock ever hands out the same stamp twice.
            memos.withLock { $0[file] = nil }
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
