package com.baruncal.barun_calendar

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Intent
import com.baruncal.barun_calendar.widget.MonthMiniWidgetProvider
import com.baruncal.barun_calendar.widget.MonthlyCalendarWidgetProvider
import com.baruncal.barun_calendar.widget.UpcomingAnniversaryWidgetProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Flutter가 위젯 요약값을 SharedPreferences에 써 둔 뒤 즉시 갱신을 원할 때
 * "com.baruncal.barun_calendar/widget"#refresh 로 이 채널을 호출한다(C-39,
 * §7 — 위젯은 Flutter 엔진 없이 캐시된 값만 읽으므로 갱신은 브로드캐스트로 트리거한다).
 */
class MainActivity : FlutterActivity() {
    private val channelName = "com.baruncal.barun_calendar/widget"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            if (call.method == "refresh") {
                refreshAllWidgets()
                result.success(null)
            } else {
                result.notImplemented()
            }
        }
    }

    private fun refreshAllWidgets() {
        val manager = AppWidgetManager.getInstance(this)
        for (providerClass in listOf(
            MonthlyCalendarWidgetProvider::class.java,
            UpcomingAnniversaryWidgetProvider::class.java,
            MonthMiniWidgetProvider::class.java,
        )) {
            val component = ComponentName(this, providerClass)
            val ids = manager.getAppWidgetIds(component)
            if (ids.isNotEmpty()) {
                val intent = Intent(this, providerClass).apply {
                    action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
                }
                sendBroadcast(intent)
            }
        }
    }
}
