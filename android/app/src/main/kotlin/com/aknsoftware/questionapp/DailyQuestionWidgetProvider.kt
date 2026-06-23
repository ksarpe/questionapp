package com.aknsoftware.questionapp

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Home-screen widget that surfaces today's free daily question in the app's
 * "sticker" brand style (black card, white Anton text).
 *
 * It is deliberately dumb: the Flutter side (WidgetSyncService) writes the
 * already-localized strings into shared storage and this provider only renders
 * them, so there is no business logic or localization to maintain natively. The
 * daily question is always free to read, so nothing premium is ever exposed.
 */
class DailyQuestionWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.daily_question_widget).apply {
                val label = widgetData.getString("widget_label", null)
                val question = widgetData.getString("widget_question", null)

                if (question.isNullOrBlank()) {
                    // No data yet (widget added before the app first ran): show a
                    // neutral brand placeholder rather than an empty card.
                    setViewVisibility(R.id.widget_label, View.GONE)
                    setTextViewText(R.id.widget_question, "✦ Debatly")
                } else {
                    setViewVisibility(R.id.widget_label, View.VISIBLE)
                    setTextViewText(R.id.widget_label, label.orEmpty())
                    setTextViewText(R.id.widget_question, question)
                }

                // Tapping anywhere opens the app, which lands on the daily.
                val pendingIntent =
                    HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)
                setOnClickPendingIntent(R.id.widget_root, pendingIntent)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
