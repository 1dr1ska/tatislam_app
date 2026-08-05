import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tatislam_app/core/navigation/app_router.dart';
import 'package:tatislam_app/core/providers/text_scale_provider.dart';
import 'package:tatislam_app/core/services/local_storage_service.dart';
import 'package:tatislam_app/core/theme/app_theme.dart';
import 'package:tatislam_app/core/widgets/system_ui_listener.dart';

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
