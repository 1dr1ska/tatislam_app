import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tatislam_app/core/navigation/app_router.dart';
import 'package:tatislam_app/core/services/local_storage_service.dart';
import 'package:tatislam_app/core/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await LocalStorageService.initialize();

  // Initialize Supabase with proper configuration
  await Supabase.initialize(
    url: 'https://vboffcgpkdruvqgdfpbp.supabase.co',
    publishableKey: 'sb_publishable_suE8ON3T8O-J6g8dfLFuBQ_Ci0aT_48',
  );


  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'TatIslam',
      theme: AppTheme.lightTheme,
      routerConfig: router,
    );
  }
}
