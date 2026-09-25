package app.luminar.luminar

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import androidx.core.content.ContextCompat
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Luminar's home-screen widgets. Taps run Dart in the background
 * (lib/widget_entry.dart); Dart saves the status ("on", "off", "busy",
 * "unavailable") under "status" and asks for a redraw.
 */
object LuminarWidgets {
  private fun tap(context: Context, uri: String) =
      HomeWidgetBackgroundIntent.getBroadcast(context, Uri.parse(uri))

  /** Draws the on/off button, which both widgets have. */
  fun bindToggle(context: Context, views: RemoteViews, prefs: SharedPreferences) {
    val status = prefs.getString("status", "off")
    val (background, label) =
        when (status) {
          "on" -> R.drawable.widget_on_bg to "On"
          "busy" -> R.drawable.widget_busy_bg to "…"
          "unavailable" -> R.drawable.widget_off_bg to "Retry"
          else -> R.drawable.widget_off_bg to "Off"
        }
    val ink =
        ContextCompat.getColor(
            context,
            if (status == "on") R.color.widget_on_text else R.color.widget_text,
        )
    views.setInt(R.id.toggle, "setBackgroundResource", background)
    views.setTextViewText(R.id.toggle_label, label)
    views.setTextColor(R.id.toggle_label, ink)
    views.setInt(R.id.toggle_icon, "setColorFilter", ink)
    views.setOnClickPendingIntent(R.id.toggle, tap(context, "luminar://toggle"))
  }

  fun bindPresets(context: Context, views: RemoteViews) {
    for ((id, name) in
        listOf(
            R.id.preset_relax to "Relax",
            R.id.preset_read to "Read",
            R.id.preset_daylight to "Daylight",
            R.id.preset_night to "Night",
        )) {
      views.setOnClickPendingIntent(id, tap(context, "luminar://preset?name=$name"))
    }
  }
}

/** 1×1: all lights on or off. */
class LightsToggleWidget : HomeWidgetProvider() {
  override fun onUpdate(
      context: Context,
      appWidgetManager: AppWidgetManager,
      appWidgetIds: IntArray,
      widgetData: SharedPreferences,
  ) {
    for (id in appWidgetIds) {
      val views = RemoteViews(context.packageName, R.layout.widget_toggle)
      LuminarWidgets.bindToggle(context, views, widgetData)
      appWidgetManager.updateAppWidget(id, views)
    }
  }
}

/** 4×1: on/off plus the four presets. */
class LightsPresetsWidget : HomeWidgetProvider() {
  override fun onUpdate(
      context: Context,
      appWidgetManager: AppWidgetManager,
      appWidgetIds: IntArray,
      widgetData: SharedPreferences,
  ) {
    for (id in appWidgetIds) {
      val views = RemoteViews(context.packageName, R.layout.widget_presets)
      LuminarWidgets.bindToggle(context, views, widgetData)
      LuminarWidgets.bindPresets(context, views)
      appWidgetManager.updateAppWidget(id, views)
    }
  }
}
