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
    private(set) var mealAvailability: MealAvailability

    /// Published dates for each meal service, used to skip weekends, holidays,
    /// and lunch-only/dinner-only days. `nil` means nothing has loaded yet;
    /// a non-optional empty value is a known no-menu response.
    private(set) var mealCalendar: MealServiceCalendar?

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
        mealCalendar = mealCache?.serviceCalendar()
        availability = timetable == nil ? .loading : .loaded
        mealAvailability = mealCache == nil ? .loading : .loaded
        timetableFetchedAt = timetable?.fetchedAt
        mealsFetchedAt = mealCache?.fetchedAt
    }

    /// What one meal page knows: a menu, or which kind of nothing it has.
    func content(for page: MealPresentation) -> MealContent {
        MealContent.resolve(presentation: page, snapshot: meals, availability: mealAvailability)
    }

    /// Brings both snapshots up to date. Safe to call on every appearance:
    /// the repository no-ops when the cache is still fresh.
    func refresh() {
        guard refreshTask == nil else { return }
        refreshTask = Task { [repository] in
            // Each request publishes as soon as it lands. Awaiting both before
            // touching any state would hold a timetable that arrived in a
            // second behind a meal request still running out its timeout.
            async let timetable = refreshTimetable(using: repository)
            async let meals = refreshMeals(using: repository)
            let (timetableChanged, mealsChanged) = await (timetable, meals)

            // Reload the complication and Smart Stack only when something
            // actually arrived — widget reloads are a metered budget, and most
            // launches are answered entirely from cache. One reload covers
            // both kinds, so it waits until both requests have settled.
            if timetableChanged || mealsChanged {
                WidgetCenter.shared.reloadAllTimelines()
            }

            refreshTask = nil
        }
    }

    /// - Returns: `true` when a genuinely newer snapshot replaced what was on
    ///   screen, which is what earns a widget reload.
    private func refreshTimetable(using repository: SchoolRepository) async -> Bool {
        let fresh = await repository.timetable()
        defer { availability = week.days.isEmpty ? .unavailable : .loaded }
        guard let fresh, fresh.fetchedAt != timetableFetchedAt else { return false }
        week = fresh.week
        timetableFetchedAt = fresh.fetchedAt
        return true
    }

    private func refreshMeals(using repository: SchoolRepository) async -> Bool {
        let fresh = await repository.meals()
        defer { mealAvailability = meals == nil ? .unavailable : .loaded }
        guard let fresh, fresh.fetchedAt != mealsFetchedAt else { return false }
        meals = fresh
        mealCalendar = fresh.serviceCalendar()
        mealsFetchedAt = fresh.fetchedAt
        return true
    }
}
