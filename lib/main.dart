import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tatislam_app/core/navigation/app_router.dart';
import 'package:tatislam_app/core/services/local_storage_service.dart';
import 'package:tatislam_app/core/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Start both initializations in parallel
  final supabaseFuture = Supabase.initialize(
    url: 'https://vboffcgpkdruvqgdfpbp.supabase.co',
    publishableKey: 'sb_publishable_suE8ON3T8O-J6g8dfLFuBQ_Ci0aT_48',
  );

  // Hive init is deferred to after first frame — not needed before UI
  // LocalStorageService.initialize() will be called in MyApp.initState

  await supabaseFuture;

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  @override
  void initState() {
    super.initState();
    // Defer Hive init to after first frame — not needed before UI paints
    WidgetsBinding.instance.addPostFrameCallback((_) {
      LocalStorageService.initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'TatIslam',
      theme: AppTheme.lightTheme,
      routerConfig: router,
    );
  }
}
