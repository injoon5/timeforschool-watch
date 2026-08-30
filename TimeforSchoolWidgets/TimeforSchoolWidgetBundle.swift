import SwiftUI
import WidgetKit

@main
struct TimeforSchoolWidgetBundle: WidgetBundle {
    var body: some Widget {
        NextLessonComplication()
        NextLessonWidget()
        MealWidget()
        MealComplication()
    }
}
