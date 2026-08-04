import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tatislam_app/features/publications/data/publication_providers.dart';
import 'package:tatislam_app/features/publications/domain/entities/publication_detail.dart';

/// Provider for getting publication detail — network-only.
final publicationDetailProvider =
    FutureProvider.family<PublicationDetail?, String>((
      ref,
      publicationId,
    ) async {
      try {
        final repository = ref.watch(publicationRepositoryProvider);
        final detail = await repository.getPublicationDetail(publicationId);
        return detail;
      } catch (_) {
        return null;
      }
    });
