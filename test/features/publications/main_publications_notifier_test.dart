import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tatislam_app/features/favorites/providers/favorites_provider.dart';
import 'package:tatislam_app/features/publications/data/publication_providers.dart';
import 'package:tatislam_app/features/publications/domain/entities/publication.dart';
import 'package:tatislam_app/features/publications/presentation/providers/publications_providers.dart';

Publication _publication(String id, {String sectionId = 'section-a'}) {
  final now = DateTime(2026, 1, 1);
  return Publication(
    id: id,
    title: 'Publication $id',
    publishedAt: now,
    createdAt: now,
    updatedAt: now,
    type: 'article',
    primarySectionId: sectionId,
  );
}

Future<PublicationsPage> _waitForPage(ProviderContainer container) async {
  final completer = Completer<PublicationsPage>();
  container.listen(mainPublicationsProvider, (previous, next) {
    if (next.hasValue && !completer.isCompleted) {
      completer.complete(next.requireValue);
    }
  }, fireImmediately: true);
  return completer.future;
}

void main() {
  test(
    'favorites are one finite page and never request the global feed',
    () async {
      var remoteCalls = 0;
      final favorites = [_publication('one'), _publication('two')];
      final container = ProviderContainer(
        overrides: [
          favoritesProvider.overrideWith((ref) async => favorites),
          getPublicationsWithFiltersProvider.overrideWithValue(({
            String? sectionId,
            String? searchQuery,
            String? type,
            int limit = 20,
            int offset = 0,
            bool includeAllStatuses = false,
          }) async {
            remoteCalls++;
            return <Publication>[];
          }),
        ],
      );
      addTearDown(container.dispose);

      container.read(favoritesFilterProvider.notifier).state = true;
      final page = await _waitForPage(container);

      expect(page.items, favorites);
      expect(page.hasMore, isFalse);
      expect(remoteCalls, 0);

      await container.read(mainPublicationsProvider.notifier).loadMore();
      expect(remoteCalls, 0);
    },
  );

  test(
    'a stale first-page response cannot overwrite a newer refresh',
    () async {
      final first = Completer<List<Publication>>();
      final second = Completer<List<Publication>>();
      var calls = 0;
      final container = ProviderContainer(
        overrides: [
          getPublicationsWithFiltersProvider.overrideWithValue(({
            String? sectionId,
            String? searchQuery,
            String? type,
            int limit = 20,
            int offset = 0,
            bool includeAllStatuses = false,
          }) {
            calls++;
            return calls == 1 ? first.future : second.future;
          }),
        ],
      );
      addTearDown(container.dispose);

      container.read(mainPublicationsProvider);
      await Future<void>.delayed(Duration.zero);
      expect(calls, 1);

      final refresh = container
          .read(mainPublicationsProvider.notifier)
          .refresh();
      await Future<void>.delayed(Duration.zero);
      expect(calls, 2);

      second.complete([_publication('new')]);
      await refresh;
      first.complete([_publication('old')]);
      await Future<void>.delayed(Duration.zero);

      expect(
        container.read(mainPublicationsProvider).requireValue.items.single.id,
        'new',
      );
    },
  );

  test('a failed next page clears the footer loading state', () async {
    final firstPage = List.generate(
      kMainPageSize,
      (index) => _publication('$index'),
    );
    var calls = 0;
    final container = ProviderContainer(
      overrides: [
        getPublicationsWithFiltersProvider.overrideWithValue(({
          String? sectionId,
          String? searchQuery,
          String? type,
          int limit = 20,
          int offset = 0,
          bool includeAllStatuses = false,
        }) async {
          calls++;
          if (calls == 1) return firstPage;
          throw StateError('network unavailable');
        }),
      ],
    );
    addTearDown(container.dispose);

    await _waitForPage(container);
    await container.read(mainPublicationsProvider.notifier).loadMore();
    final page = container.read(mainPublicationsProvider).requireValue;

    expect(page.isLoadingMore, isFalse);
    expect(page.loadMoreError, isA<StateError>());
    expect(page.items, firstPage);
  });
}
