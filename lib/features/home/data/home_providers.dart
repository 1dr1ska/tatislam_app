import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:tatislam_app/features/home/data/repositories/home_layout_preference_repository_impl.dart';
import 'package:tatislam_app/features/home/domain/repositories/home_layout_preference_repository.dart';
import 'package:tatislam_app/features/home/domain/entities/home_layout_mode.dart';

final homeLayoutPreferenceRepositoryProvider = Provider<HomeLayoutPreferenceRepository>((ref) {
  return HomeLayoutPreferenceRepositoryImpl();
});

/// Provider for home layout mode
final homeLayoutModeProvider = StateProvider<HomeLayoutMode>((ref) {
  final repository = ref.watch(homeLayoutPreferenceRepositoryProvider);
  return repository.getLayoutMode();
});
