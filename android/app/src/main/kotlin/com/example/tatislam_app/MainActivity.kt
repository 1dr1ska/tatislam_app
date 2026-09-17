package com.example.tatislam_app

import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.ryanheise.audioservice.AudioServiceActivity

/// Shared state between the Activity and the MediaListenerService (both run in
/// the app's main process), plus the method-channel name Dart uses to keep the
/// «is playing» flag in sync.
object NotificationMediaBridge {
  const val channelName = "tatislam/notification"

  @Volatile var playing: Boolean = false
  @Volatile var flutterEngine: FlutterEngine? = null

  /// Asks the Dart isolate to restore (re-issue) the media notification using
  /// a fresh foreground cycle, because audio is still playing.
  fun requestRestoreNotification() {
    val engine = flutterEngine ?: return
    MethodChannel(engine.dartExecutor.binaryMessenger, channelName)
      .invokeMethod("restoreNotification", null)
  }
}

// Extends AudioServiceActivity (not plain FlutterActivity) so the app's
// FlutterEngine is shared with audio_service's background audio handler.
// This avoids a second engine and makes the media notification / lock screen
// controls talk to the exact same player the UI uses.
class MainActivity : AudioServiceActivity() {
  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    NotificationMediaBridge.flutterEngine = flutterEngine
    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NotificationMediaBridge.channelName)
      .setMethodCallHandler { call, result ->
        when (call.method) {
          "setPlaying" -> {
            NotificationMediaBridge.playing = call.argument<Boolean>("playing") ?: false
            result.success(null)
          }
          "restoreNotification" -> {
            NotificationMediaBridge.requestRestoreNotification()
            result.success(null)
          }
          else -> result.notImplemented()
        }
      }
  }
}
