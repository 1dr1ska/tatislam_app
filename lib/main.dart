import 'package:audio_service/audio_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tatislam_app/core/navigation/app_router.dart';
import 'package:tatislam_app/core/providers/text_scale_provider.dart';
import 'package:tatislam_app/core/services/local_storage_service.dart';
import 'package:tatislam_app/core/theme/app_theme.dart';
import 'package:tatislam_app/core/widgets/system_ui_listener.dart';
import 'package:tatislam_app/features/audio/data/audio_artwork_file.dart';
import 'package:tatislam_app/features/audio/data/background_audio_handler.dart';
import 'package:tatislam_app/features/audio/presentation/widgets/mini_player.dart';
import 'package:tatislam_app/features/notifications/presentation/in_app_notification_banner.dart';
import 'package:tatislam_app/features/notifications/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize both Supabase and Hive before the first frame.
  await Future.wait([
    Supabase.initialize(
      url: 'https://vboffcgpkdruvqgdfpbp.supabase.co',
      publishableKey: 'sb_publishable_suE8ON3T8O-J6g8dfLFuBQ_Ci0aT_48',
    ),
    LocalStorageService.initialize(),
  ]);

  // Push notifications are supported only on Android/iOS. On web and desktop
  // (and when the Firebase native config is missing) the app still works —
  // FCM setup is simply skipped.
  if (NotificationService.instance.isSupported) {
    try {
      await Firebase.initializeApp();
      await NotificationService.instance.initialize();
    } catch (e) {
      debugPrint('Firebase push notifications initialization skipped: $e');
    }
  }

  // Background audio + system media notification. On Android the app gets a
  // media notification with a seek timeline + Play/Pause; on iOS the lock
  // screen and Control Center gain the same controls. The shared
  // AudioPlayerService reports into BackgroundAudioHandler, which advertises
  // ONLY play/pause and seeking — no fake prev/next, no stop button, no
  // rewind/forward circles.
  // Web/desktop are untouched: they keep the existing plain just_audio flow.
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS)) {
    // Notification «фон»: the mountains background is exposed as a local
    // file:// artwork so the media notification looks branded.
    await AudioArtworkFile.prepare();
    try {
      await AudioService.init<BackgroundAudioHandler>(
        builder: () => BackgroundAudioHandler.instance,
        config: AudioServiceConfig(
          androidResumeOnClick: true,
          androidNotificationChannelId:
              'com.example.tatislam_app.channel.audio',
          androidNotificationChannelName: 'Воспроизведение аудио',
          androidNotificationChannelDescription:
              'Управление аудиоплеером TatIslam',
          androidNotificationClickStartsActivity: true,
          // «Не закрываемо во время воспроизведения»: foreground-service +
          // ongoing уведомление (Android 14/15 не дают смахнуть такое).
          // ПАРАМЕТРЫ МУТУАЛЬНО ИСКЛЮЧАЮЩИЕСЯ в audio_service: если включён
          // androidNotificationOngoing, то androidStopForegroundOnPause должен
          // быть true (иначе AudioServiceConfig бросает assert и приложение
          // зависает на сплэше).
          androidNotificationOngoing: true,
          androidStopForegroundOnPause: true,
          preloadArtwork: true,
          artDownscaleWidth: 512,
          artDownscaleHeight: 512,
        ),
      );
      BackgroundAudioHandler.enable();
    } catch (e) {
      // AudioService init must never block the app launch: on any platform
      // config problem we keep the app alive without the media notification.
      debugPrint('AudioService.init skipped: $e');
    }
  }

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final textScale = ref.watch(textScaleProvider);
    return SystemUiListener(
      child: MaterialApp.router(
        title: 'TatIslam',
        theme: AppTheme.lightThemeWithScale(textScale),
        routerConfig: router,
        scaffoldMessengerKey: appScaffoldMessengerKey,
        // Mounts the push-notification wiring (foreground banner + tap
        // routing) above the Navigator, and the global Mini Player overlay at
        // the very bottom (audio keeps playing across every screen).
        builder: (context, child) => MiniPlayerOverlay(
          child: InAppNotificationListener(
            child: child ?? const SizedBox.shrink(),
          ),
        ),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('ru', 'RU'),
          Locale('tt', 'RU'),
          Locale('en', 'US'),
        ],
      ),
    );
  }
}
