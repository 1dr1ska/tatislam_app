import 'dart:typed_data';

import 'package:tatislam_app/features/publications/domain/entities/content_block.dart';

/// A file picked during editing, kept as raw bytes so the background save job
/// can upload it even after the editor screen has been closed.
class SelectedMediaFile {
  final Uint8List bytes;
  final String name;

  const SelectedMediaFile({required this.bytes, required this.name});
}

/// Immutable snapshot of everything required to create or update a publication
/// in the background upload queue.
///
/// Built by the editors at "Save" time and enqueued into the queue; the editors
/// can be closed immediately afterwards because the job no longer touches any
/// editor state.
class PublicationSavePayload {
  /// Null when creating a new publication, the existing id when editing.
  final String? publicationId;

  /// Photo publications use their own single-image flow.
  final bool isPhoto;

  final String title;
  final String? icon;
  final String type;
  final DateTime publishedAt;
  final String status;
  final String primarySectionId;
  final bool hasAdditionalSections;

  /// Section memberships to persist (primary + additional, computed at save).
  final List<String> sectionIds;

  // ── Block-based publications (article, etc.) ─────────────
  final List<ContentBlock> contentBlocks;

  /// Newly picked image files keyed by block id — an image block can hold
  /// several photos (album), so a list is uploaded per block.
  final Map<String, List<SelectedMediaFile>> newBlockImages;

  /// Newly picked audio files keyed by block id.
  final Map<String, SelectedMediaFile> newBlockAudios;

  /// Newly picked video files keyed by block id (uploaded videos).
  final Map<String, SelectedMediaFile> newBlockVideos;

  /// Newly picked files (pdf, docx, ...) for file blocks, keyed by block id.
  final Map<String, SelectedMediaFile> newBlockFiles;

  // ── Photo publications ──────────────────────────────────
  final SelectedMediaFile? newPhoto;

  /// Existing photo storage path; freed only after the DB references the new
  /// photo, so a failed save never leaves a publication without its image.
  final String? existingPhotoPath;

  const PublicationSavePayload({
    this.publicationId,
    required this.isPhoto,
    required this.title,
    this.icon,
    required this.type,
    required this.publishedAt,
    required this.status,
    required this.primarySectionId,
    required this.hasAdditionalSections,
    required this.sectionIds,
    this.contentBlocks = const [],
    this.newBlockImages = const {},
    this.newBlockAudios = const {},
    this.newBlockVideos = const {},
    this.newBlockFiles = const {},
    this.newPhoto,
    this.existingPhotoPath,
  });
}
