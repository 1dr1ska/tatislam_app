import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tatislam_app/core/services/media_optimization_service.dart';
import 'package:tatislam_app/core/services/supabase_service.dart';
import 'package:tatislam_app/core/storage/media_storage_repository.dart';
import 'package:tatislam_app/core/storage/storage_paths.dart';
import 'package:tatislam_app/core/storage/storage_providers.dart';
import 'package:tatislam_app/features/publications/data/publication_providers.dart';
import 'package:tatislam_app/features/publications/domain/entities/content_block.dart';
import 'package:tatislam_app/features/publications/domain/entities/video_source_type.dart';
import 'package:tatislam_app/features/publications/domain/repositories/publication_repository.dart';
import 'package:tatislam_app/features/publications/presentation/providers/publication_state_providers.dart';

import 'publication_save_payload.dart';

/// Thrown by [PublicationSaveJob] when the admin cancels a running job
/// between steps/files. The job rolls back its partial work and the queue
/// marks the job as canceled instead of failed.
class PublicationSaveJobCanceled implements Exception {
  const PublicationSaveJobCanceled();
}

/// Executes one save pipeline (metadata → file uploads → sections → blocks)
/// for a [PublicationSavePayload], fully independent of any editor screen.
///
/// Reports progress through [report]; stops (with rollback) as soon as
/// [isCanceled] returns true between steps/files. On failure it deletes every
/// file uploaded during this attempt and any created row, so a failed save
/// never leaves orphaned objects behind.
class PublicationSaveJob {
  static Future<void> run(
    Ref ref,
    PublicationSavePayload payload,
    void Function(int stepIndex, int fileIndex) report,
    bool Function() isCanceled,
  ) async {
    final repository = ref.read(publicationRepositoryProvider);
    final storage = ref.read(mediaStorageRepositoryProvider);

    final uploadedPaths = <String>{};
    final replacedPaths = <String>{};
    String? createdPublicationId;

    try {
      if (payload.isPhoto) {
        await _runPhoto(
          payload,
          repository,
          storage,
          report,
          isCanceled,
          uploadedPaths,
          (id) {
            createdPublicationId = id;
          },
        );
      } else {
        await _runArticle(
          payload,
          repository,
          storage,
          report,
          isCanceled,
          uploadedPaths,
          replacedPaths,
          (id) {
            createdPublicationId = id;
          },
        );
      }

      // Fully committed — refresh the admin list and the detail cache.
      ref.invalidate(publicationRepositoryProvider);
      ref.read(publicationListVersionProvider.notifier).state++;

      // Push-уведомление при ПЕРВОЙ публикации. Вызываем Edge Function для
      // любого сохранения со статусом published (создание сразу опубликованным
      // или переход черновик → опубликовано). Повторные вызовы безопасны:
      // Edge Function идемпотентна (claim по publication_id) и при повторе
      // просто вернёт duplicate.
      if (payload.status == 'published') {
        final publicationId = createdPublicationId ?? payload.publicationId;
        if (publicationId != null) {
          unawaited(_notifyNewPublication(publicationId));
        }
      }
    } catch (e) {
      // Roll back a partially created publication and clean up every file
      // uploaded during this attempt, so nothing orphaned is left behind.
      try {
        if (uploadedPaths.isNotEmpty) {
          try {
            await storage.delete(uploadedPaths.toList());
          } catch (_) {
            // Best-effort cleanup; ignore storage errors.
          }
        }
        if (createdPublicationId != null) {
          try {
            await repository.deletePublication(createdPublicationId!);
          } catch (_) {
            // The row may already have been cleaned by cascades; ignore.
          }
        }
      } catch (_) {
        // Entire rollback failed — leave objects for manual cleanup.
      }
      rethrow;
    }
  }

  /// Fire-and-forget: просит Edge Function `notify-new-publication` разослать
  /// push о первой публикации. Ошибка никогда не блокирует сохранение.
  static Future<void> _notifyNewPublication(String publicationId) async {
    try {
      await SupabaseService.client.functions.invoke(
        'notify-new-publication',
        body: {'publication_id': publicationId},
      );
    } catch (e) {
      debugPrint('PublicationSaveJob: push notify skipped ($publicationId): $e');
    }
  }

  // ---------------------------------------------------------------
  // Block-based publications (article, etc.)
  // ---------------------------------------------------------------

  static Future<void> _runArticle(
    PublicationSavePayload payload,
    PublicationRepository repository,
    MediaStorageRepository storage,
    void Function(int stepIndex, int fileIndex) report,
    bool Function() isCanceled,
    Set<String> uploadedPaths,
    Set<String> replacedPaths,
    void Function(String id) setCreatedPublicationId,
  ) async {
    final optimizationService = const MediaOptimizationService();
    final totalFiles = payload.contentBlocks.fold(0, (count, block) {
      if (block is ImageContentBlock &&
          payload.newBlockImages.containsKey(block.id)) {
        return count + payload.newBlockImages[block.id]!.length;
      }
      if (block is AudioContentBlock &&
          payload.newBlockAudios.containsKey(block.id)) {
        return count + 1;
      }
      if (block is VideoContentBlock &&
          payload.newBlockVideos.containsKey(block.id)) {
        return count + 1;
      }
      if (block is FileContentBlock &&
          payload.newBlockFiles.containsKey(block.id)) {
        return count + 1;
      }
      return count;
    });

    _checkCancel(isCanceled);

    // Step 0 — obtain the publication id (needed for the upload paths).
    //
    // A brand-new publication's row is created up-front JUST to get its id;
    // it carries no blocks yet and is rolled back by `run` on any failure. An
    // existing publication's metadata is NOT touched here — it is updated only
    // after every file has uploaded, so an upload error can never half-apply
    // a publication (the "errored but the publication was saved anyway" bug).
    report(0, 0);
    final publicationId = payload.publicationId;
    final String effectiveId;
    if (publicationId == null) {
      final publication = await repository.createPublication(
        title: payload.title,
        icon: payload.icon,
        type: payload.type,
        publishedAt: payload.publishedAt,
        status: payload.status,
        primarySectionId: payload.primarySectionId,
        hasAdditionalSections: payload.hasAdditionalSections,
      );
      setCreatedPublicationId(publication.id);
      effectiveId = publication.id;
    } else {
      effectiveId = publicationId;
    }
    _checkCancel(isCanceled);

    // Step 1 — upload new block files sequentially, swapping file paths in.
    report(1, 0);
    final updatedBlocks = <ContentBlock>[];
    var fileIndex = 0;
    for (final block in payload.contentBlocks) {
      if (block is ImageContentBlock) {
        final files = payload.newBlockImages[block.id];
        if (files != null && files.isNotEmpty) {
          // Upload every newly picked photo and append its Storage key to the
          // block's kept paths (album order: existing photos first, then the
          // new ones, in the order they were picked).
          final newKeys = <String>[];
          for (final file in files) {
            final s3Key = await _uploadBlockImage(
              effectiveId,
              block,
              file,
              storage,
              optimizationService,
            );
            uploadedPaths.add(s3Key);
            newKeys.add(s3Key);
            fileIndex++;
            report(1, fileIndex);
          }
          updatedBlocks.add(
            block.copyWith(imagePaths: [...block.imagePaths, ...newKeys]),
          );
        } else {
          updatedBlocks.add(block);
        }
      } else if (block is AudioContentBlock) {
        final file = payload.newBlockAudios[block.id];
        if (file != null) {
          final s3Key = await _uploadBlockAudio(
            effectiveId,
            block,
            file,
            storage,
          );
          uploadedPaths.add(s3Key);
          if ((block.audioPath ?? '').isNotEmpty && block.audioPath != s3Key) {
            replacedPaths.add(block.audioPath!);
          }
          fileIndex++;
          report(1, fileIndex);
          updatedBlocks.add(block.copyWith(audioPath: s3Key));
        } else {
          updatedBlocks.add(block);
        }
      } else if (block is VideoContentBlock) {
        final file = payload.newBlockVideos[block.id];
        if (file != null) {
          final s3Key = await _uploadBlockVideo(
            effectiveId,
            block,
            file,
            storage,
          );
          uploadedPaths.add(s3Key);
          if (block.videoPath != null &&
              block.videoPath!.isNotEmpty &&
              block.videoPath != s3Key) {
            replacedPaths.add(block.videoPath!);
          }
          fileIndex++;
          report(1, fileIndex);
          updatedBlocks.add(
            block.copyWith(
              source: VideoSourceType.upload,
              url: '',
              videoPath: s3Key,
              videoName: file.name,
              videoSize: file.bytes.length,
              videoMime: _mimeFor(file.name),
            ),
          );
        } else {
          updatedBlocks.add(block);
        }
      } else if (block is FileContentBlock) {
        final file = payload.newBlockFiles[block.id];
        if (file != null) {
          final s3Key = await _uploadBlockFile(
            effectiveId,
            block,
            file,
            storage,
          );
          uploadedPaths.add(s3Key);
          if (block.path.isNotEmpty && block.path != s3Key) {
            replacedPaths.add(block.path);
          }
          fileIndex++;
          report(1, fileIndex);
          updatedBlocks.add(
            block.copyWith(
              path: s3Key,
              name: file.name,
              size: file.bytes.length,
              mimeType: _mimeFor(file.name),
            ),
          );
        } else {
          updatedBlocks.add(block);
        }
      } else {
        updatedBlocks.add(block);
      }
      _checkCancel(isCanceled);
    }

    // Step 2 — persist the metadata (update only; for creates the row was made
    // up-front). This happens AFTER the uploads succeeded so that on any error
    // not a single byte of a publication's state is written to the DB.
    report(2, totalFiles);
    if (publicationId != null) {
      await repository.updatePublication(
        id: effectiveId,
        title: payload.title,
        icon: payload.icon,
        publishedAt: payload.publishedAt,
        type: payload.type,
        status: payload.status,
        primarySectionId: payload.primarySectionId,
        hasAdditionalSections: payload.hasAdditionalSections,
      );
    }
    _checkCancel(isCanceled);

    // Step 3 — section memberships.
    await repository.setSections(effectiveId, payload.sectionIds);
    _checkCancel(isCanceled);

    // Step 4 — commit the blocks. After this point the new files are
    // referenced by the DB and must not be rolled back.
    report(3, totalFiles);
    await repository.replaceBlocks(effectiveId, updatedBlocks);
    uploadedPaths.clear();

    // Free replaced files only now, when nothing references them anymore.
    if (replacedPaths.isNotEmpty) {
      try {
        await storage.delete(replacedPaths.toList());
      } catch (_) {
        // Best-effort cleanup; ignore storage errors.
      }
    }
  }

  static Future<String> _uploadBlockImage(
    String effectiveId,
    ImageContentBlock block,
    SelectedMediaFile file,
    MediaStorageRepository storage,
    MediaOptimizationService optimizationService,
  ) async {
    _enforceSizeLimit('изображения', file.bytes.length, _maxImageBytes);
    try {
      // Optimize before upload (resize to 1920px max, JPEG quality 90).
      final result = await optimizationService.optimizeImage(
        originalBytes: file.bytes,
        originalFileName: file.name,
      );
      final extension = _safeExtension(result.fileName);
      final path = StoragePaths.blockImage(
        effectiveId,
        extension,
        blockId: block.id,
      );
      return await storage.upload(path, result.bytes);
    } catch (e) {
      if (e is PublicationSaveJobCanceled) rethrow;
      throw Exception('Ошибка загрузки изображения: $e');
    }
  }

  static Future<String> _uploadBlockAudio(
    String effectiveId,
    AudioContentBlock block,
    SelectedMediaFile file,
    MediaStorageRepository storage,
  ) async {
    _enforceSizeLimit('аудио', file.bytes.length, _maxAudioBytes);
    try {
      final extension = _safeExtension(file.name);
      final path = StoragePaths.blockAudio(
        effectiveId,
        extension,
        blockId: block.id,
      );
      return await storage.upload(path, file.bytes);
    } catch (e) {
      if (e is PublicationSaveJobCanceled) rethrow;
      throw Exception('Ошибка загрузки аудио: $e');
    }
  }

  static Future<String> _uploadBlockVideo(
    String effectiveId,
    VideoContentBlock block,
    SelectedMediaFile file,
    MediaStorageRepository storage,
  ) async {
    _enforceSizeLimit('видео', file.bytes.length, _maxVideoBytes);
    try {
      final extension = _safeExtension(file.name);
      final path = StoragePaths.blockVideo(
        effectiveId,
        extension,
        blockId: block.id,
      );
      return await storage.upload(
        path,
        file.bytes,
        contentType: _mimeFor(file.name),
      );
    } catch (e) {
      if (e is PublicationSaveJobCanceled) rethrow;
      throw Exception('Ошибка загрузки видео: $e');
    }
  }

  static Future<String> _uploadBlockFile(
    String effectiveId,
    FileContentBlock block,
    SelectedMediaFile file,
    MediaStorageRepository storage,
  ) async {
    _enforceSizeLimit('файла', file.bytes.length, _maxFileBytes);
    try {
      final extension = _safeExtension(file.name);
      final path = StoragePaths.blockFile(
        effectiveId,
        extension,
        blockId: block.id,
      );
      return await storage.upload(
        path,
        file.bytes,
        contentType: _mimeFor(file.name),
      );
    } catch (e) {
      if (e is PublicationSaveJobCanceled) rethrow;
      throw Exception('Ошибка загрузки файла: $e');
    }
  }

  /// Best-effort MIME type by file extension (used as the upload Content-Type).
  static String _mimeFor(String fileName) {
    final ext = _safeExtension(fileName);
    return switch (ext) {
      'mp4' => 'video/mp4',
      'webm' => 'video/webm',
      'mov' => 'video/quicktime',
      'mkv' => 'video/x-matroska',
      'pdf' => 'application/pdf',
      'doc' => 'application/msword',
      'docx' =>
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'xls' => 'application/vnd.ms-excel',
      'xlsx' =>
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'ppt' => 'application/vnd.ms-powerpoint',
      'pptx' =>
        'application/vnd.openxmlformats-officedocument.presentationml.presentation',
      'txt' => 'text/plain',
      'zip' => 'application/zip',
      _ => 'application/octet-stream',
    };
  }

  /// Max sizes mirror the per-folder limits enforced by the `upload-media`
  /// Edge Function, so a file that would be rejected right there is instead
  /// caught locally with a clear Russian message before any network call.
  static const int _maxImageBytes = 20 * 1024 * 1024;
  static const int _maxAudioBytes = 200 * 1024 * 1024;
  static const int _maxVideoBytes = 100 * 1024 * 1024;
  static const int _maxFileBytes = 100 * 1024 * 1024;

  /// Throws a clear, actionable error when a picked file exceeds [maxBytes].
  static void _enforceSizeLimit(String kind, int size, int maxBytes) {
    if (size <= maxBytes) return;
    final sizeMb = (size / (1024 * 1024)).toStringAsFixed(1);
    final maxMb = (maxBytes / (1024 * 1024)).round();
    throw Exception(
      'Размер $kind превышает лимит ($sizeMb МБ). '
      'Максимальный размер — $maxMb МБ.',
    );
  }

  /// Returns a clean, lowercased file extension (without the dot) for [fileName],
  /// or `'bin'` when the name has no usable extension. Handles no-dot, multi-dot
  /// and names with unsafe characters so they can never produce a malformed or
  /// empty Storage path (a bare trailing dot would be rejected downstream).
  static String _safeExtension(String fileName) {
    final dot = fileName.lastIndexOf('.');
    if (dot > 0 && dot < fileName.length - 1) {
      var ext = fileName.substring(dot + 1).trim().toLowerCase();
      ext = ext.replaceAll(RegExp('[^a-z0-9_-]'), '');
      if (ext.isNotEmpty) return ext;
    }
    return 'bin';
  }

  // ---------------------------------------------------------------
  // Photo publications
  // ---------------------------------------------------------------

  static Future<void> _runPhoto(
    PublicationSavePayload payload,
    PublicationRepository repository,
    MediaStorageRepository storage,
    void Function(int stepIndex, int fileIndex) report,
    bool Function() isCanceled,
    Set<String> uploadedPaths,
    void Function(String id) setCreatedPublicationId,
  ) async {
    final optimizationService = const MediaOptimizationService();
    final isCreate = payload.publicationId == null;

    if (isCreate) {
      // Step 0 — create the row to obtain its id.
      _checkCancel(isCanceled);
      report(0, 0);
      final publication = await repository.createPublication(
        title: payload.title,
        type: payload.type,
        publishedAt: payload.publishedAt,
        status: payload.status,
        primarySectionId: payload.primarySectionId,
        hasAdditionalSections: payload.hasAdditionalSections,
      );
      setCreatedPublicationId(publication.id);
      _checkCancel(isCanceled);

      // Step 1 — upload the photo into a path keyed by the publication id.
      report(1, 0);
      final newPath = await _uploadPhoto(
        publication.id,
        payload,
        storage,
        optimizationService,
        uploadedPaths,
      );
      report(1, newPath.isEmpty ? 0 : 1);

      await repository.updatePublication(
        id: publication.id,
        title: payload.title,
        type: payload.type,
        publishedAt: payload.publishedAt,
        status: payload.status,
        primarySectionId: payload.primarySectionId,
        photoPath: newPath.isEmpty
            ? (payload.existingPhotoPath ?? '')
            : newPath,
        hasAdditionalSections: payload.hasAdditionalSections,
      );
      if (newPath.isNotEmpty) {
        uploadedPaths.remove(newPath); // committed by the DB now
      }
      _checkCancel(isCanceled);

      // Step 2 — sections.
      report(2, payload.newPhoto == null ? 0 : 1);
      await repository.setSections(publication.id, payload.sectionIds);
    } else {
      // Update: upload the new photo first (the old one stays intact), point
      // the DB at the new file, and only then free the old one.
      _checkCancel(isCanceled);
      report(0, 0);
      final newPath = await _uploadPhoto(
        payload.publicationId!,
        payload,
        storage,
        optimizationService,
        uploadedPaths,
      );
      report(0, newPath.isEmpty ? 0 : 1);
      _checkCancel(isCanceled);

      report(1, 0);
      await repository.updatePublication(
        id: payload.publicationId!,
        title: payload.title,
        type: payload.type,
        publishedAt: payload.publishedAt,
        status: payload.status,
        primarySectionId: payload.primarySectionId,
        photoPath: newPath.isNotEmpty
            ? newPath
            : (payload.existingPhotoPath ?? ''),
        hasAdditionalSections: payload.hasAdditionalSections,
      );
      if (newPath.isNotEmpty) {
        uploadedPaths.remove(newPath);
      }

      if (newPath.isNotEmpty &&
          payload.existingPhotoPath != null &&
          payload.existingPhotoPath!.isNotEmpty &&
          payload.existingPhotoPath != newPath) {
        try {
          await storage.delete([payload.existingPhotoPath!]);
        } catch (_) {
          // Best-effort cleanup; ignore storage errors.
        }
      }
      _checkCancel(isCanceled);

      // Step 2 — sections.
      report(2, payload.newPhoto == null ? 0 : 1);
      await repository.setSections(payload.publicationId!, payload.sectionIds);
    }
  }

  static Future<String> _uploadPhoto(
    String publicationId,
    PublicationSavePayload payload,
    MediaStorageRepository storage,
    MediaOptimizationService optimizationService,
    Set<String> uploadedPaths,
  ) async {
    final file = payload.newPhoto;
    if (file == null) {
      return '';
    }
    try {
      final result = await optimizationService.optimizeImage(
        originalBytes: file.bytes,
        originalFileName: file.name,
      );
      final extension = result.fileName.split('.').last;
      final path = StoragePaths.photo(publicationId, extension);
      final s3Key = await storage.upload(path, result.bytes);
      uploadedPaths.add(s3Key);
      return s3Key;
    } catch (e) {
      if (e is PublicationSaveJobCanceled) rethrow;
      throw Exception('Не удалось загрузить фотографию: $e');
    }
  }

  static void _checkCancel(bool Function() isCanceled) {
    if (isCanceled()) {
      throw const PublicationSaveJobCanceled();
    }
  }
}
