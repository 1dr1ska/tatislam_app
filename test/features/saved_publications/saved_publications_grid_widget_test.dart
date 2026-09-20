import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tatislam_app/features/publications/domain/entities/publication.dart';
import 'package:tatislam_app/features/saved_publications/domain/entities/download_size_info.dart';
import 'package:tatislam_app/features/saved_publications/domain/entities/download_status.dart';
import 'package:tatislam_app/features/saved_publications/domain/entities/offline_publication_detail.dart';
import 'package:tatislam_app/features/saved_publications/domain/entities/saved_publication_record.dart';
import 'package:tatislam_app/features/saved_publications/domain/repositories/saved_publication_repository.dart';
import 'package:tatislam_app/features/saved_publications/presentation/providers/saved_publications_providers.dart';
import 'package:tatislam_app/features/publications/domain/entities/publication_detail.dart';

/// Fake repository that reports a single fully-saved publication.
class _SingleSavedRepo implements SavedPublicationRepository {
  @override
  Future<List<SavedPublicationRecord>> getSaved() async => [
        SavedPublicationRecord(
          publicationId: 'p1',
          savedAt: DateTime(2026, 1, 1),
          status: DownloadStatus.saved,
          totalBytes: 1234,
          publication: Publication(
            id: 'p1',
            title: 'Офлайн язма',
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

/// Mirrors how [MainScreen] uses the saved-publications providers: when the
/// saved-only filter is on, it lists [savedPublicationPublicationsProvider]
/// (offline data) and shows a download badge on each card.
class _SavedOnlyHarness extends ConsumerWidget {
  const _SavedOnlyHarness();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showSavedOnly = ref.watch(savedPublicationsFilterProvider);

    return Scaffold(
      body: Column(
        children: [
          IconButton(
            icon: Icon(
              showSavedOnly ? Icons.download_done : Icons.download_outlined,
            ),
            onPressed: () =>
                ref.read(toggleSavedPublicationsFilterProvider)(),
          ),
          Expanded(
            child: showSavedOnly
                ? ref.watch(savedPublicationPublicationsProvider).when(
                    loading: () => const CircularProgressIndicator(),
                    error: (e, s) => Text('error $e'),
                    data: (publications) => ListView(
                      children: [
                        for (final p in publications)
                          ListTile(
                            leading: const Icon(Icons.download_done),
                            title: Text(p.title),
                          ),
                      ],
                    ),
                  )
                : const Text('catalog'),
          ),
        ],
      ),
    );
  }
}

void main() {
  testWidgets('saved-only toggle shows the offline publications list',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          savedPublicationRepositoryProvider.overrideWithValue(
            _SingleSavedRepo(),
          ),
        ],
        child: const MaterialApp(home: _SavedOnlyHarness()),
      ),
    );

    // Default: catalog mode — no offline items, download_outlined icon.
    expect(find.byIcon(Icons.download_outlined), findsOneWidget);
    expect(find.text('catalog'), findsOneWidget);
    expect(find.text('Офлайн язма'), findsNothing);

    // Toggle the saved-only filter on.
    await tester.tap(find.byType(IconButton));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.download_done), findsWidgets);
    expect(find.text('Офлайн язма'), findsOneWidget);
    expect(find.text('catalog'), findsNothing);

    // Toggle back off returns to catalog.
    await tester.tap(find.byType(IconButton));
    await tester.pumpAndSettle();
    expect(find.text('catalog'), findsOneWidget);
    expect(find.text('Офлайн язма'), findsNothing);
  });
}