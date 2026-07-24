import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tatislam_app/features/publications/data/publication_providers.dart';
import 'package:tatislam_app/features/publications/domain/entities/publication_detail.dart';

/// Provider for getting publication detail
final publicationDetailProvider = FutureProvider.family<PublicationDetail?, String>((ref, publicationId) async {
  try {
    final repository = ref.watch(publicationRepositoryProvider);
    final detail = await repository.getPublicationDetail(publicationId);
    return detail;
  } catch (e) {
    // Handle not found or other errors
    debugPrint('Error loading publication detail: $e');
    return null;
  }
});