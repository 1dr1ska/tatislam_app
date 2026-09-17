import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tatislam_app/core/navigation/app_router.dart';
import 'package:tatislam_app/core/providers/text_scale_provider.dart';
import 'package:tatislam_app/core/services/local_storage_service.dart';
import 'package:tatislam_app/core/theme/app_theme.dart';
import 'package:tatislam_app/core/widgets/system_ui_listener.dart';
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
        // routing) above the Navigator.
        builder: (context, child) => InAppNotificationListener(
          child: child ?? const SizedBox.shrink(),
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
