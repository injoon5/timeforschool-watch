import Foundation
import Observation
import WidgetKit

/// Whether the app has a timetable to draw yet.
enum TimetableAvailability: Sendable {
    case loading
    case loaded
    /// Nothing cached and the network could not supply anything either.
    case unavailable
}

/// View-facing state for the whole app.
///
/// The cached snapshots are read synchronously in `init`, so the first frame
/// the wearer sees already has their timetable in it. Network work happens
/// afterwards and only replaces state when it actually returns something.
@MainActor
@Observable
final class SchoolStore {
    private(set) var week: SchoolWeek
    private(set) var meals: MealSnapshot?
    private(set) var availability: TimetableAvailability

    /// Days that actually serve lunch or dinner, used to skip weekends and
    /// holidays when a meal page rolls over. Derived once per snapshot rather
    /// than on every render — the meals screen reads it once a minute.
    private(set) var servedDays: Set<SchoolDate>

    private let repository: SchoolRepository
    private var refreshTask: Task<Void, Never>?
    /// Fetch stamps of what is currently on screen, so a refresh can tell a
    /// genuinely new snapshot from the cache it already had.
    private var timetableFetchedAt: Date?
    private var mealsFetchedAt: Date?

    init(repository: SchoolRepository = .shared) {
        self.repository = repository
        let timetable = SchoolRepository.cachedTimetable()
        let mealCache = SchoolRepository.cachedMeals()

        week = timetable?.week ?? .empty
        meals = mealCache
        servedDays = mealCache?.servedDays() ?? []
        availability = timetable == nil ? .loading : .loaded
        timetableFetchedAt = timetable?.fetchedAt
        mealsFetchedAt = mealCache?.fetchedAt
    }

    func meal(_ kind: MealKind, on day: SchoolDate) -> Meal? {
        meals?.meal(kind: kind, on: day)
    }

    /// Brings both snapshots up to date. Safe to call on every appearance:
    /// the repository no-ops when the cache is still fresh.
    func refresh() {
        guard refreshTask == nil else { return }
        refreshTask = Task { [repository] in
            async let timetable = repository.timetable()
            async let mealWindow = repository.meals()
            let (freshWeek, freshMeals) = await (timetable, mealWindow)

            var changed = false
            if let freshWeek, freshWeek.fetchedAt != timetableFetchedAt {
                week = freshWeek.week
                timetableFetchedAt = freshWeek.fetchedAt
                changed = true
            }
            if let freshMeals, freshMeals.fetchedAt != mealsFetchedAt {
                meals = freshMeals
                servedDays = freshMeals.servedDays()
                mealsFetchedAt = freshMeals.fetchedAt
                changed = true
            }
            availability = week.days.isEmpty ? .unavailable : .loaded

            // Reload the complication and Smart Stack only when something
            // actually arrived — widget reloads are a metered budget, and most
            // launches are answered entirely from cache.
            if changed {
                WidgetCenter.shared.reloadAllTimelines()
            }

            refreshTask = nil
        }
    }
}
