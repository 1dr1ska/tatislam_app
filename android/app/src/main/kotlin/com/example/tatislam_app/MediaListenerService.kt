package com.example.tatislam_app

import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification

/// Watches the system for REMOVAL of our media notification. On Android 13+
/// the swipe gesture is controlled by the OS and may not reach the Dart
/// handler; this listener detects the removal regardless and — while audio is
/// still playing — asks Dart to restore the notification (fresh foreground
/// cycle), so the player effectively cannot be dismissed during playback.
class MediaListenerService : NotificationListenerService() {
  override fun onNotificationRemoved(sbn: StatusBarNotification) {
    super.onNotificationRemoved(sbn)
    if (sbn.packageName != packageName) return
    if (NotificationMediaBridge.playing) {
      NotificationMediaBridge.requestRestoreNotification()
    }
  }
}