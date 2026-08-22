import 'package:tatislam_app/core/storage/media_storage_repository.dart';
import 'package:tatislam_app/features/publications/data/datasources/publication_remote_data_source.dart';
import 'package:tatislam_app/features/publications/data/models/publication_model.dart';
import 'package:tatislam_app/features/publications/domain/entities/audio_source_type.dart';
import 'package:tatislam_app/features/publications/domain/entities/content_block.dart';
import 'package:tatislam_app/features/publications/domain/entities/publication.dart';
import 'package:tatislam_app/features/publications/domain/entities/publication_detail.dart';
import 'package:tatislam_app/features/publications/domain/repositories/publication_repository.dart';

class PublicationRepositoryImpl implements PublicationRepository {
  final PublicationRemoteDataSource _remote;
  final MediaStorageRepository _storage;

  PublicationRepositoryImpl(this._remote, this._storage);

  @override
  Future<List<Publication>> getPublications({
    String? sectionId,
    String? searchQuery,
    String? type,
    int limit = 20,
    int offset = 0,
    bool includeAllStatuses = false,
  }) async {
    final models = await _remote.getPublications(
      sectionId: sectionId,
      searchQuery: searchQuery,
      type: type,
      limit: limit,
      offset: offset,
      includeAllStatuses: includeAllStatuses,
    );
    return models.map((m) => m.toEntity()).toList();
  }

  @override
  Future<List<Publication>> getPublicationsByIds(List<String> ids) async {
    final models = await _remote.getPublicationsByIds(ids);
    return models.map((m) => m.toEntity()).toList();
  }

  @override
  Future<PublicationDetail> getPublicationDetail(String id) async {
    final row = await _remote.getPublicationDetail(id);
    return PublicationDetail(
      publication: row.publication.toEntity(),
      blocks: row.blocks,
      sectionIds: row.sectionIds,
    );
  }

  @override
  Future<Publication> createPublication({
    required String title,
    String? icon,
    required DateTime publishedAt,
    required String type,
    String? status,
    required String primarySectionId,
    String? photoPath,
    bool hasAdditionalSections = false,
  }) async {
    final now = DateTime.now();
    final model = PublicationModel(
      id: '',
      title: title,
      icon: icon,
      publishedAt: publishedAt,
      createdAt: now,
      updatedAt: now,
      type: type,
      status: status,
      primarySectionId: primarySectionId,
      photoPath: photoPath,
      hasAdditionalSections: hasAdditionalSections,
    );
    final created = await _remote.createPublication(model);
    return created.toEntity();
  }

  @override
  Future<Publication> updatePublication({
    required String id,
    required String title,
    String? icon,
    required DateTime publishedAt,
    required String type,
    String? status,
    required String primarySectionId,
    String? photoPath,
    bool? hasAdditionalSections,
  }) async {
    final previous = await _remote.getPublicationDetail(id);
    final now = DateTime.now();
    final model = PublicationModel(
      id: id,
      title: title,
      icon: icon,
      publishedAt: publishedAt,
      createdAt: previous.publication.createdAt,
      updatedAt: now,
      type: type,
      status: status ?? previous.publication.status,
      primarySectionId: primarySectionId,
      photoPath: photoPath ?? previous.publication.photoPath,
      hasAdditionalSections:
          hasAdditionalSections ?? previous.publication.hasAdditionalSections,
    );
    final updated = await _remote.updatePublication(id, model);
    return updated.toEntity();
  }

  @override
  Future<void> deletePublication(String id) async {
    final detail = await _remote.getPublicationDetail(id);
    await _remote.deletePublication(id);
    await _storage.delete([
      ..._storagePathsIn(detail.blocks),
      ?detail.publication.photoPath,
    ]);
  }

  @override
  Future<void> replaceBlocks(
    String publicationId,
    List<ContentBlock> blocks,
  ) async {
    final previous = await _remote.getPublicationDetail(publicationId);
    await _remote.replaceBlocks(publicationId, blocks);

    final keptPaths = _storagePathsIn(blocks).toSet();
    final removedPaths = _storagePathsIn(
      previous.blocks,
    ).where((path) => !keptPaths.contains(path)).toList();
    if (removedPaths.isNotEmpty) {
      await _storage.delete(removedPaths);
    }
  }

  @override
  Future<void> setSections(String publicationId, List<String> sectionIds) {
    return _remote.setSections(publicationId, sectionIds);
  }

  /// Storage paths (image blocks + uploaded audio blocks) referenced by
  /// [blocks], used to keep cleanup on delete/replace exhaustive.
  Iterable<String> _storagePathsIn(List<ContentBlock> blocks) {
    return blocks.expand((block) {
      switch (block) {
        case ImageContentBlock(imagePath: final path):
          return [path];
        case AudioContentBlock(
          source: AudioSourceType.upload,
          audioPath: final path?,
        ):
          return [path];
        default:
          return const <String>[];
      }
    });
  }
}
