package app.luminar.luminar

import android.app.Activity
import android.os.Build
import android.os.Bundle
import android.widget.Toast
import es.antonborri.home_widget.HomeWidgetBackgroundIntent

/**
 * Runs an app shortcut (res/xml/shortcuts.xml) without opening Luminar: hands
 * its luminar:// action to the same background path as the home-screen
 * widgets (lib/widget_entry.dart), says what it is doing, and closes.
 */
class ShortcutActivity : Activity() {
  override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    val uri = intent?.data
    if (uri != null && uri.scheme == "luminar") {
      HomeWidgetBackgroundIntent.getBroadcast(this, uri).send()
      val what =
          when (uri.host) {
            "toggle" -> "Switching lights…"
            "preset" -> "Lights: ${uri.getQueryParameter("name")}"
            else -> null
          }
      if (what != null) Toast.makeText(applicationContext, what, Toast.LENGTH_SHORT).show()
    }
    finish()
    if (Build.VERSION.SDK_INT >= 34) {
      overrideActivityTransition(OVERRIDE_TRANSITION_CLOSE, 0, 0)
    } else {
      @Suppress("DEPRECATION") overridePendingTransition(0, 0)
    }
  }
}
