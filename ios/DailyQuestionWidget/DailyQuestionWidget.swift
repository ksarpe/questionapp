import WidgetKit
import SwiftUI

/// App Group shared with the Runner app. Must match the group enabled on BOTH
/// targets in Xcode and `WidgetSyncService._appGroupId` on the Flutter side.
private let appGroupId = "group.com.aknsoftware.questionapp"

/// Brand "spark" orange (#F97316), used for the small label.
private let brandSpark = Color(red: 0xF9 / 255.0, green: 0x73 / 255.0, blue: 0x16 / 255.0)

// Shared-storage keys written by WidgetSyncService.
private let keyLabel = "widget_label"
private let keyQuestion = "widget_question"

// MARK: - Timeline model

struct DailyEntry: TimelineEntry {
    let date: Date
    let label: String
    let question: String
}

/// Reads the last values the app pushed into the App Group. Empty strings when
/// the app has never run (the view then shows a neutral brand placeholder).
private func loadEntry() -> DailyEntry {
    let defaults = UserDefaults(suiteName: appGroupId)
    return DailyEntry(
        date: Date(),
        label: defaults?.string(forKey: keyLabel) ?? "",
        question: defaults?.string(forKey: keyQuestion) ?? ""
    )
}

// MARK: - Provider

struct DailyProvider: TimelineProvider {
    func placeholder(in context: Context) -> DailyEntry {
        DailyEntry(date: Date(), label: "Pytanie dnia", question: "…")
    }

    func getSnapshot(in context: Context, completion: @escaping (DailyEntry) -> Void) {
        completion(loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DailyEntry>) -> Void) {
        let entry = loadEntry()
        // Re-render shortly after the next local midnight so the card rolls over
        // to a new day even if the app isn't opened. This only re-reads what the
        // app last wrote — there is no background network fetch (see the plan).
        let nextRefresh = Calendar.current.nextDate(
            after: Date(),
            matching: DateComponents(hour: 0, minute: 0, second: 30),
            matchingPolicy: .nextTime
        ) ?? Date().addingTimeInterval(6 * 60 * 60)
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }
}

// MARK: - View

struct DailyQuestionWidgetEntryView: View {
    var entry: DailyEntry

    private var hasQuestion: Bool {
        !entry.question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if hasQuestion && !entry.label.isEmpty {
                Text(entry.label.uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .kerning(0.8)
                    .foregroundColor(brandSpark)
                    .lineLimit(1)
            }
            Text(hasQuestion ? entry.question : "✦ Debatly")
                .font(.custom("Anton-Regular", size: 28))
                .foregroundColor(.white)
                .minimumScaleFactor(0.5)
                .lineLimit(6)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .widgetBackgroundCompat(Color.black)
        .widgetURL(URL(string: "questionapp://daily"))
    }
}

/// `containerBackground(_:for:)` is required on iOS 17+ but unavailable earlier,
/// so fall back to a plain background to keep one source building on iOS 14–16.
private extension View {
    @ViewBuilder
    func widgetBackgroundCompat(_ color: Color) -> some View {
        if #available(iOSApplicationExtension 17.0, *) {
            self.containerBackground(color, for: .widget)
        } else {
            self.background(color)
        }
    }
}

// MARK: - Widget

struct DailyQuestionWidget: Widget {
    let kind = "DailyQuestionWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DailyProvider()) { entry in
            DailyQuestionWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Debatly")
        .description("Pytanie dnia na ekranie głównym.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
