import Foundation

/// Wire format of `GET /lunch` — NEIS field names, passed through verbatim.
struct MealDTO: Decodable, Sendable {
    var mealCode: String
    var servedOn: String
    var dishes: String
    var calorieInfo: String?

    private enum CodingKeys: String, CodingKey {
        case mealCode = "MMEAL_SC_CODE"
        case servedOn = "MLSV_YMD"
        case dishes = "DDISH_NM"
        case calorieInfo = "CAL_INFO"
    }

    func makeMeal() -> Meal? {
        guard let kind = MealKind(rawValue: mealCode), let day = SchoolDate(compact: servedOn) else {
            return nil
        }
        return Meal(
            kind: kind,
            day: day,
            dishes: MealTextCleaner.dishes(from: dishes),
            calories: MealTextCleaner.calories(from: calorieInfo)
        )
    }
}
