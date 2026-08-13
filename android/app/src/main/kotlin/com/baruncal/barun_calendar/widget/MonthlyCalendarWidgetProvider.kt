package com.baruncal.barun_calendar.widget

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews
import com.baruncal.barun_calendar.R
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * 위젯 공용: Flutter의 shared_preferences 플러그인이 쓰는 SharedPreferences 파일을
 * 그대로 읽는다(C-39 — Flutter 엔진을 기동하지 않고 네이티브가 캐시된 값만 렌더).
 * Flutter 쪽 [WidgetDataSync]가 "flutter.widget_*" 키로 값을 미리 써 두고,
 * MethodChannel로 즉시 갱신을 요청하면 각 Provider의 onUpdate가 다시 호출된다.
 */
internal object WidgetPrefs {
    const val PREFS_NAME = "FlutterSharedPreferences"

    fun read(context: Context, key: String, fallback: String): String {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        return prefs.getString("flutter.$key", null) ?: fallback
    }
}

/** 위젯 1/3: 오늘 날짜 + 음력/일진 요약. */
class MonthlyCalendarWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        val dateFormat = SimpleDateFormat("yyyy.MM.dd (E)", Locale.KOREAN)
        val today = dateFormat.format(Date())
        val lunarSummary = WidgetPrefs.read(context, "widget_lunar_summary", "동기화 대기 중 — 앱을 열어주세요")
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_monthly_calendar)
            views.setTextViewText(R.id.widget_today_text, today)
            views.setTextViewText(R.id.widget_lunar_summary_text, lunarSummary)
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}

/** 위젯 2/3: 다가오는 기념일(F8) 요약. */
class UpcomingAnniversaryWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        val summary = WidgetPrefs.read(context, "widget_next_anniversary", "다가오는 기일·생신이 없습니다")
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_upcoming_anniversary)
            views.setTextViewText(R.id.widget_anniversary_text, summary)
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}

/** 위젯 3/3(§7 W3): 이번 달 미니 캘린더(고정폭 텍스트 그리드, 오늘 "*"·휴일 "." 표시). */
class MonthMiniWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        val title = WidgetPrefs.read(context, "widget_month_mini_title", "이번 달")
        val grid = WidgetPrefs.read(context, "widget_month_mini_text", "동기화 대기 중 — 앱을 열어주세요")
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_month_mini)
            views.setTextViewText(R.id.widget_month_mini_title, title)
            views.setTextViewText(R.id.widget_month_mini_grid, grid)
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
