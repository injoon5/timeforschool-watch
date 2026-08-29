import SwiftUI
import WidgetKit

@main
struct TimeforSchoolWidgetBundle: WidgetBundle {
    var body: some Widget {
        NextLessonWidget()
        MealWidget()
    }
}
