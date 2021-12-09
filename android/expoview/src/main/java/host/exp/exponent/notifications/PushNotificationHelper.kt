package host.exp.exponent.notifications

import android.content.Context
import androidx.core.app.NotificationManagerCompat
import host.exp.exponent.ExponentManifest
import host.exp.exponent.di.NativeModuleDepsProvider
import host.exp.exponent.storage.ExponentSharedPreferences
import org.json.JSONArray
import org.json.JSONException
import org.json.JSONObject
import javax.inject.Inject

class PushNotificationHelper {
  fun removeNotifications(context: Context, unreadNotifications: JSONArray?) {
    if (unreadNotifications == null) {
      return
    }

    val notificationManager = NotificationManagerCompat.from(context)
    for (i in 0 until unreadNotifications.length()) {
      try {
        notificationManager.cancel(
          (unreadNotifications[i] as JSONObject).getString(
            NotificationConstants.NOTIFICATION_ID_KEY
          ).toInt()
        )
      } catch (e: JSONException) {
        e.printStackTrace()
      }
    }
  }

  companion object {
    val instance by lazy {
      PushNotificationHelper()
    }
  }
}
