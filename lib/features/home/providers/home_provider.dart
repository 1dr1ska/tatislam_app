import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tatislam_app/features/publications/domain/entities/publication.dart';
import 'package:tatislam_app/features/publications/data/publication_providers.dart';

/// Provider for HomeScreen - provides latest publications
final homePublicationsProvider = FutureProvider<List<Publication>>((ref) async {
  try {
    debugPrint('🏠 HomePublicationsProvider: Loading publications for home screen...');
    final getPublications = ref.watch(getPublicationsProvider);
    final result = await getPublications();
    debugPrint('✅ HomePublicationsProvider: Successfully loaded ${result.length} publications');
    return result;
  } catch (e, stackTrace) {
    debugPrint('❌ HomePublicationsProvider ERROR: $e');
    debugPrint('📍 Stack trace: $stackTrace');
    rethrow;
  }
});

/// Provider for refreshing home publications
final refreshHomePublicationsProvider = Provider<Future<void> Function()>((ref) {
  final getPublications = ref.watch(getPublicationsProvider);

  return () async {
    await getPublications();
    ref.invalidate(homePublicationsProvider);
  };
});