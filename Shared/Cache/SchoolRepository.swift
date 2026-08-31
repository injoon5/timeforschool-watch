import Foundation
import os

/// Single source of truth for timetable and meal data.
///
/// Cache reads are exposed synchronously so launch and widget code can render
/// immediately. Refresh calls return the fresh snapshot when possible, falling
/// back to the cached value, and concurrent refreshes share one network call.
actor SchoolRepository {
    static let shared = SchoolRepository()

    private let api: SchoolAPI
    private let identity: SchoolIdentity
    private let logger = Logger(subsystem: "school.timefor.watch", category: "repository")

    private var timetableRefresh: Task<TimetableSnapshot?, Never>?
    private var mealRefresh: Task<MealSnapshot?, Never>?

    init(api: SchoolAPI = .shared, identity: SchoolIdentity = .default) {
        self.api = api
        self.identity = identity
    }

    // MARK: - Cache reads

    /// Synchronous cache read for launch-time rendering.
    nonisolated static func cachedTimetable() -> TimetableSnapshot? {
        SnapshotStorage.load(TimetableSnapshot.self, from: .timetable)
    }

    nonisolated static func cachedMeals() -> MealSnapshot? {
        SnapshotStorage.load(MealSnapshot.self, from: .meals)
    }

    /// The cached timetable, but only while it is still worth trusting without
    /// asking the network.
    ///
    /// Widget timelines use this to take the fast path: a fresh cache means the
    /// extension can answer entirely from disk and never open a connection.
    nonisolated static func freshTimetable(now: Date = .now) -> TimetableSnapshot? {
        guard let cached = cachedTimetable(),
              !cached.isStale(now: now),
              cached.identity == .default
        else { return nil }
        return cached
    }

    nonisolated static func freshMeals(now: Date = .now) -> MealSnapshot? {
        guard let cached = cachedMeals(),
              !cached.isStale(now: now),
              cached.identity == .default
        else { return nil }
        return cached
    }

    // MARK: - Refresh

    /// Refreshes the timetable when the cached copy has aged out.
    ///
    /// - Returns: the newest snapshot available, cached or fresh, or `nil` when
    ///   nothing has ever been downloaded.
    @discardableResult
    func timetable(force: Bool = false, now: Date = .now) async -> TimetableSnapshot? {
        let cached = Self.cachedTimetable()
        guard force || cached.map({ $0.isStale(now: now) || $0.identity != identity }) ?? true else {
            return cached
        }
        if let existing = timetableRefresh { return await existing.value ?? cached }

        let task = Task<TimetableSnapshot?, Never> { [api, identity, logger] in
            do {
                let week = try await api.week(for: identity)
                let snapshot = TimetableSnapshot(identity: identity, week: week, fetchedAt: .now)
                SnapshotStorage.save(snapshot, to: .timetable)
                return snapshot
            } catch {
                logger.notice("Timetable refresh failed, keeping cache: \(error.localizedDescription, privacy: .public)")
                return nil
            }
        }
        timetableRefresh = task
        let fresh = await task.value
        timetableRefresh = nil
        return fresh ?? cached
    }

    /// Refreshes the rolling meal window when the cached copy no longer reaches
    /// far enough ahead.
    @discardableResult
    func meals(force: Bool = false, now: Date = .now) async -> MealSnapshot? {
        let cached = Self.cachedMeals()
        guard force || cached.map({ $0.isStale(now: now) || $0.identity != identity }) ?? true else {
            return cached
        }
        if let existing = mealRefresh { return await existing.value ?? cached }

        let start = SchoolDate(now)
        let end = start.adding(days: MealSnapshot.lookahead)
        let task = Task<MealSnapshot?, Never> { [api, identity, logger] in
            do {
                let meals = try await api.meals(for: identity, from: start, to: end)
                let snapshot = MealSnapshot(
                    identity: identity,
                    meals: meals,
                    windowStart: start,
                    windowEnd: end,
                    fetchedAt: .now
                )
                SnapshotStorage.save(snapshot, to: .meals)
                return snapshot
            } catch {
                logger.notice("Meal refresh failed, keeping cache: \(error.localizedDescription, privacy: .public)")
                return nil
            }
        }
        mealRefresh = task
        let fresh = await task.value
        mealRefresh = nil
        return fresh ?? cached
    }
}
