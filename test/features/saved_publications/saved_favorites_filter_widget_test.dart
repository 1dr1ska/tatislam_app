import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tatislam_app/features/favorites/data/datasources/favorites_local_data_source.dart';
import 'package:tatislam_app/features/favorites/data/favorites_providers.dart';
import 'package:tatislam_app/features/favorites/providers/favorites_provider.dart';
import 'package:tatislam_app/features/publications/domain/entities/publication.dart';
import 'package:tatislam_app/features/publications/domain/entities/publication_detail.dart';
import 'package:tatislam_app/features/publications/presentation/providers/publications_providers.dart';
import 'package:tatislam_app/features/saved_publications/domain/entities/download_size_info.dart';
import 'package:tatislam_app/features/saved_publications/domain/entities/download_status.dart';
import 'package:tatislam_app/features/saved_publications/domain/entities/offline_publication_detail.dart';
import 'package:tatislam_app/features/saved_publications/domain/entities/saved_publication_record.dart';
import 'package:tatislam_app/features/saved_publications/domain/repositories/saved_publication_repository.dart';
import 'package:tatislam_app/features/saved_publications/presentation/providers/saved_publications_providers.dart';

/// In-memory favorites store — avoids touching the real Hive box in tests.
class _FakeFavoritesLocalDataSource extends FavoritesLocalDataSource {
  final Set<String> ids;

  _FakeFavoritesLocalDataSource(this.ids);

  @override
  List<String> getFavoriteIds() => ids.toList();

  @override
  bool isFavorite(String publicationId) => ids.contains(publicationId);

  @override
  Future<void> addFavorite(String publicationId) async {
    ids.add(publicationId);
  }

  @override
  Future<void> removeFavorite(String publicationId) async {
    ids.remove(publicationId);
  }
}

/// Two saved publications: one favorite ('p1'), one not ('p2').
class _TwoSavedRepo implements SavedPublicationRepository {
  @override
  Future<List<SavedPublicationRecord>> getSaved() async => [
        for (final id in ['p1', 'p2'])
          SavedPublicationRecord(
            publicationId: id,
            savedAt: DateTime(2026, 1, 1),
            status: DownloadStatus.saved,
            totalBytes: 100,
            publication: Publication(
              id: id,
              title: 'Сохранённая $id',
              publishedAt: DateTime(2026, 1, 1),
              createdAt: DateTime(2026, 1, 1),
              updatedAt: DateTime(2026, 1, 1),
              type: 'article',
              primarySectionId: 'sec1',
            ),
            hasOnlineVideo: false,
          ),
      ];

  @override
  Future<SavedPublicationRecord?> getById(String publicationId) async => null;

  @override
  Future<bool> isFullySaved(String publicationId) async => false;

  @override
  Future<DownloadSizeInfo> computeSize(PublicationDetail detail) {
    throw UnimplementedError();
  }

  @override
  Future<OfflinePublicationDetail?> getOfflineDetail(String publicationId) async =>
      null;

  @override
  Future<void> save(
    String publicationId, {
    void Function(DownloadProgress progress)? onProgress,
    SavingCancelSignal? cancelSignal,
  }) async {}

  @override
  Future<void> remove(String publicationId) async {}
}

/// Replicates the combined-filter behaviour of `_buildSavedPublicationsGrid` in
/// `main_screen.dart`: the downloaded list, further restricted by the
/// favorites-only filter using the local (offline) favorite ids.
class _SavedFavoritesHarness extends ConsumerWidget {
  const _SavedFavoritesHarness();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showFavoritesOnly = ref.watch(favoritesFilterProvider);
    final publicationsAsync = ref.watch(savedPublicationPublicationsProvider);

    return Scaffold(
      body: Column(
        children: [
          Row(
            children: [
              // Fake "downloaded" toggle (always on in this harness).
              const Icon(Icons.download_done),
              // Favorites-only toggle.
              IconButton(
                icon: const Icon(Icons.star),
                onPressed: () =>
                    ref.read(toggleFavoritesFilterProvider)(),
              ),
            ],
          ),
          Expanded(
            child: publicationsAsync.when(
              loading: () => const CircularProgressIndicator(),
              error: (e, s) => Text('error $e'),
              data: (publications) {
                var items = publications;
                if (showFavoritesOnly) {
                  final favoriteIds = ref.watch(localFavoriteIdsProvider);
                  items = publications
                      .where((p) => favoriteIds.contains(p.id))
                      .toList();
                }
                return ListView(
                  children: [
                    for (final p in items) ListTile(title: Text(p.title)),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

void main() {
  testWidgets(
      'saved-only list also honors the favorites filter, and reacts to toggles',
      (tester) async {
    // p1 starts as a favorite.
    final favorites = _FakeFavoritesLocalDataSource({'p1'});

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          savedPublicationRepositoryProvider.overrideWithValue(_TwoSavedRepo()),
          favoritesLocalDataSourceProvider.overrideWithValue(favorites),
        ],
        child: const MaterialApp(home: _SavedFavoritesHarness()),
      ),
    );
    await tester.pumpAndSettle();

    // Favorites filter OFF → both saved items shown.
    expect(find.text('Сохранённая p1'), findsOneWidget);
    expect(find.text('Сохранённая p2'), findsOneWidget);

    // Turn the favorites filter ON → only the favorite remains.
    await tester.tap(find.byIcon(Icons.star));
    await tester.pumpAndSettle();
    expect(find.text('Сохранённая p1'), findsOneWidget);
    expect(find.text('Сохранённая p2'), findsNothing);

    // Remove p1 from favorites via the provider path the star uses → the item
    // disappears from the combined list.
    await tester.runAsync(() async {
      final container = ProviderScope.containerOf(
        tester.element(find.byType(_SavedFavoritesHarness)),
      );
      final result = await container.read(toggleFavoriteProvider)('p1');
      expect(result, isFalse);
    });
    await tester.pumpAndSettle();

    expect(find.text('Сохранённая p1'), findsNothing);
    expect(find.text('Сохранённая p2'), findsNothing);

    // Toggle favorites filter OFF again → p2 (still saved) is back.
    await tester.tap(find.byIcon(Icons.star));
    await tester.pumpAndSettle();
    expect(find.text('Сохранённая p2'), findsOneWidget);
  });
}