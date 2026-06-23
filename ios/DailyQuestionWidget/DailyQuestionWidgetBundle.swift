import WidgetKit
import SwiftUI

/// Entry point for the widget extension. A single widget for now; add more to
/// the bundle here if the app grows more home-screen surfaces.
@main
struct DailyQuestionWidgetBundle: WidgetBundle {
    var body: some Widget {
        DailyQuestionWidget()
    }
}
