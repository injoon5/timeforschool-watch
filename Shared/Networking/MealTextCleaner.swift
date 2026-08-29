import Foundation

/// Normalises the free-text meal fields NEIS returns.
///
/// Dish names arrive newline- or `<br/>`-separated and carry allergen markers:
/// a trailing `y` on this school's feed, and sometimes the standard numeric
/// form (`"쌀밥(1.5.6)"`). Both are stripped so the watch shows just the food.
enum MealTextCleaner {
    static func dishes(from raw: String) -> [String] {
        raw
            .replacingOccurrences(of: "<br/>", with: "\n")
            .replacingOccurrences(of: "<br>", with: "\n")
            .split(whereSeparator: \.isNewline)
            .compactMap { clean(String($0)) }
    }

    /// Strips allergen markers from a single dish name.
    static func clean(_ dish: String) -> String? {
        var name = Substring(dish).trimmed()
        name = stripAllergenNumbers(name)
        // Trailing "y" markers, possibly repeated and separated by spaces.
        while let last = name.last, last == "y" || last == "Y" {
            name = name.dropLast().trimmed()
        }
        return name.isEmpty ? nil : String(name)
    }

    /// Removes a trailing `(1.5.6)` style allergen list.
    private static func stripAllergenNumbers(_ name: Substring) -> Substring {
        guard name.last == ")", let open = name.lastIndex(of: "(") else { return name }
        let body = name[name.index(after: open)..<name.index(before: name.endIndex)]
        guard !body.isEmpty, body.allSatisfy({ $0.isNumber || $0 == "." || $0 == "," || $0 == " " }) else {
            return name
        }
        return name[name.startIndex..<open].trimmed()
    }

    /// Parses `"1233.1 Kcal"`.
    static func calories(from raw: String?) -> Double? {
        guard let raw else { return nil }
        let digits = raw.prefix { $0.isNumber || $0 == "." }
        return Double(digits)
    }
}

private extension Substring {
    func trimmed() -> Substring {
        var slice = self
        while let first = slice.first, first.isWhitespace { slice = slice.dropFirst() }
        while let last = slice.last, last.isWhitespace { slice = slice.dropLast() }
        return slice
    }
}
