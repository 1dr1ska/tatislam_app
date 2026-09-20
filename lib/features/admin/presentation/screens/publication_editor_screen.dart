import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';

import 'package:image_picker/image_picker.dart';
import 'package:tatislam_app/core/constants/app_colors.dart';
import 'package:tatislam_app/core/constants/app_localizations.dart' as loc;
import 'package:tatislam_app/features/admin/queue/publication_save_payload.dart';
import 'package:tatislam_app/features/admin/queue/queue_providers.dart';
import 'package:tatislam_app/core/constants/app_icons.dart';
import 'package:tatislam_app/core/storage/storage_providers.dart';
import 'package:tatislam_app/features/publications/data/publication_providers.dart';
import 'package:tatislam_app/features/publications/domain/entities/audio_source_type.dart';
import 'package:tatislam_app/features/publications/domain/entities/content_block.dart';
import 'package:tatislam_app/features/publications/domain/entities/publication_detail.dart';
import 'package:tatislam_app/features/publications/domain/entities/video_provider_type.dart';
import 'package:tatislam_app/features/publications/domain/entities/video_source_type.dart';
import 'package:tatislam_app/features/sections/data/section_providers.dart';
import 'package:tatislam_app/features/sections/domain/entities/section.dart';

/// Holds a selected file's raw bytes and original name, independently of
/// `dart:io` — works on both Android and Web.
class _SelectedFile {
  final Uint8List bytes;
  final String name;

  const _SelectedFile({required this.bytes, required this.name});
}

/// How a video block's content is provided. YouTube/RuTube are link-based
/// (an external URL); `upload` means a file picked from the device and pushed
/// to Storage. Only `upload` exposes the file-selection controls.
enum _VideoMode { youtube, rutube, upload }

class PublicationEditorScreen extends ConsumerStatefulWidget {
  final String? publicationId;

  const PublicationEditorScreen({super.key, this.publicationId});

  @override
  ConsumerState<PublicationEditorScreen> createState() =>
      _PublicationEditorScreenState();
}

class _PublicationEditorScreenState
    extends ConsumerState<PublicationEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _dateController = TextEditingController();
  final _uuid = const Uuid();

  late Future<PublicationDetail?> _publicationFuture;
  late Future<List<Section>> _sectionsFuture;

  String? _selectedIcon;
  String? _primarySectionId;
  List<ContentBlock> _contentBlocks = [];
  Set<String> _selectedSectionIds = {};
  bool _hasAdditionalSections = false;
  String _status = 'published';
  DateTime? _publishedAt;

  // Map to store selected image files for each content block (an image block
  // can hold several photos, so each entry is a list).
  final Map<String, List<_SelectedFile>> _selectedBlockImageFiles = {};

  // Map to store selected audio files for each content block
  final Map<String, _SelectedFile> _selectedBlockAudioFiles = {};

  // Map to store selected video files for video blocks (upload to Storage).
  final Map<String, _SelectedFile> _selectedBlockVideoFiles = {};

  // Map to store selected files for file blocks (pdf, docx, ...).
  final Map<String, _SelectedFile> _selectedBlockFiles = {};

  // Track which blocks are expanded/collapsed
  final Set<String> _collapsedBlockIds = {};

  bool _hasUnsavedChanges = false;
  bool _iconValidationAttempted = false;
  bool _sectionValidationAttempted = false;
  String _initialStatus = 'draft';

  @override
  void initState() {
    super.initState();
    _sectionsFuture = _loadSections();
    if (widget.publicationId != null) {
      _publicationFuture = _loadPublication(widget.publicationId!);
    } else {
      _publicationFuture = Future.value(null);
      _hasUnsavedChanges = false;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  Future<List<Section>> _loadSections() async {
    final repository = ref.read(sectionRepositoryProvider);
    return repository.getSections(includeHidden: true);
  }

  Future<PublicationDetail?> _loadPublication(String id) async {
    try {
      final repository = ref.read(publicationRepositoryProvider);
      final detail = await repository.getPublicationDetail(id);

      _titleController.text = detail.publication.title;
      _selectedIcon = detail.publication.icon;
      _primarySectionId = detail.publication.primarySectionId;
      _contentBlocks = List.from(detail.blocks);
      _selectedSectionIds = Set.from(detail.sectionIds);
      _hasAdditionalSections = detail.publication.hasAdditionalSections;
      _status = detail.publication.status ?? 'published';
      _publishedAt = detail.publication.publishedAt;
      _dateController.text = _formatDate(_publishedAt!);

      // Save initial state for change detection
      _initialStatus = _status;

      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          setState(() {});
        });
      }

      return detail;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${loc.AppLocalizations.admin.publicationLoadErrorDetail}$e',
            ),
          ),
        );
      }
      return null;
    }
  }

  // Size caps mirror the `upload-media` Edge Function's per-folder limits, so
  // a file that the server would reject outright is caught here with a clear
  // message instead of failing deep inside the background save pipeline.
  static const int _maxBlockImageBytes = 20 * 1024 * 1024;
  static const int _maxBlockAudioBytes = 200 * 1024 * 1024;
  static const int _maxBlockVideoBytes = 100 * 1024 * 1024;
  static const int _maxBlockFileBytes = 100 * 1024 * 1024;

  void _showFileError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  /// Turns a file-picker result into a staged [_SelectedFile], validating that
  /// bytes were actually read and the size is within the server limit. On an
  /// unusable file it shows a message and returns null (nothing is staged).
  _SelectedFile? _validatedPickedFile(FilePickerResult? result, int maxBytes) {
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      _showFileError('Не удалось прочитать файл “${file.name}”. Выберите другой файл.');
      return null;
    }
    if (bytes.length > maxBytes) {
      final sizeMb = (bytes.length / (1024 * 1024)).toStringAsFixed(1);
      final maxMb = (maxBytes / (1024 * 1024)).round();
      _showFileError(
        'Файл “${file.name}” слишком большой ($sizeMb МБ). Максимум — $maxMb МБ.',
      );
      return null;
    }
    return _SelectedFile(bytes: bytes, name: file.name);
  }

  Future<void> _pickBlockImage(String blockId) async {
    try {
      final picker = ImagePicker();
      final pickedFiles = await picker.pickMultiImage(
        imageQuality: 95,
        // Albums: allow picking several photos at once (the platform gallery
        // picker supports multi-select).
        limit: 20,
      );

      if (pickedFiles.isNotEmpty) {
        final files = <_SelectedFile>[];
        for (final picked in pickedFiles) {
          final bytes = await picked.readAsBytes();
          if (bytes.length > _maxBlockImageBytes) {
            _showFileError(
              'Фото “${picked.name}” слишком большое '
              '(${(bytes.length / (1024 * 1024)).toStringAsFixed(1)} МБ). '
              'Максимум — ${(_maxBlockImageBytes / (1024 * 1024)).round()} МБ.',
            );
            continue;
          }
          final name = picked.name;
          files.add(_SelectedFile(bytes: bytes, name: name));
        }
        if (files.isNotEmpty) {
          setState(() {
            // Append to the block's staged photos so a publication can build
            // an album in several passes.
            final existing = _selectedBlockImageFiles[blockId];
            if (existing != null) {
              existing.addAll(files);
            } else {
              _selectedBlockImageFiles[blockId] = files;
            }
            _hasUnsavedChanges = true;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${loc.AppLocalizations.admin.imageSelectionError}$e',
            ),
          ),
        );
      }
    }
  }

  Future<void> _pickBlockAudio(String blockId) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      withData: true,
    );
    final file = _validatedPickedFile(result, _maxBlockAudioBytes);
    if (file == null) return;
    setState(() {
      _selectedBlockAudioFiles[blockId] = file;
      _hasUnsavedChanges = true;
    });
  }

  Future<void> _pickBlockVideo(String blockId) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      withData: true,
    );
    final file = _validatedPickedFile(result, _maxBlockVideoBytes);
    if (file == null) return;
    setState(() {
      _selectedBlockVideoFiles[blockId] = file;
      _hasUnsavedChanges = true;
    });
  }

  Future<void> _pickBlockFile(String blockId) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      withData: true,
    );
    final file = _validatedPickedFile(result, _maxBlockFileBytes);
    if (file == null) return;
    setState(() {
      _selectedBlockFiles[blockId] = file;
      _hasUnsavedChanges = true;
    });
  }

  /// Auto-fills date when first publishing if no date is set.
  /// Does NOT modify already-published publications.
  void _ensureDateOnPublish() {
    if (_status == 'published' &&
        _publishedAt == null &&
        _initialStatus != 'published') {
      final now = DateTime.now();
      _publishedAt = now;
      _dateController.text = _formatDate(now);
    }
  }

  /// Removes content blocks that have no meaningful data.
  /// Operates on [_contentBlocks] in-place.
  void _removeEmptyBlocks() {
    _contentBlocks.removeWhere((block) {
      return switch (block) {
        TextContentBlock() => block.text.trim().isEmpty,
        ImageContentBlock() =>
          block.imagePaths.every((path) => path.isEmpty) &&
              !_selectedBlockImageFiles.containsKey(block.id),
        VideoContentBlock() =>
          block.url.trim().isEmpty &&
              (block.videoPath == null || block.videoPath!.trim().isEmpty) &&
              !_selectedBlockVideoFiles.containsKey(block.id),
        AudioContentBlock() =>
          (block.audioPath == null || block.audioPath!.trim().isEmpty) &&
              (block.audioUrl == null || block.audioUrl!.trim().isEmpty) &&
              !_selectedBlockAudioFiles.containsKey(block.id),
        FileContentBlock() =>
          block.path.trim().isEmpty &&
              !_selectedBlockFiles.containsKey(block.id),
      };
    });
  }

  /// Validates the form, snapshots it into a [PublicationSavePayload] and puts
  /// it into the background upload queue. The editor closes immediately; the
  /// publication is saved and uploaded by the queue in the background.
  Future<void> _savePublication() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Icon is required
    if (_selectedIcon == null || (_selectedIcon?.isEmpty ?? true)) {
      setState(() {
        _iconValidationAttempted = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc.AppLocalizations.admin.selectPublicationIcon),
        ),
      );
      return;
    }

    // Primary section is required
    if (_primarySectionId == null || _primarySectionId!.isEmpty) {
      setState(() {
        _sectionValidationAttempted = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            loc.AppLocalizations.admin.selectPrimarySectionRequired,
          ),
        ),
      );
      return;
    }

    // Auto-set date if publishing for the first time
    _ensureDateOnPublish();

    // Remove empty blocks before building the payload
    _removeEmptyBlocks();

    final payload = _buildSavePayload();
    final queue = ref.read(publicationUploadQueueProvider);
    if (!queue.enqueue(payload)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc.AppLocalizations.admin.uploadsAlreadyQueued),
        ),
      );
      return;
    }

    setState(() {
      _hasUnsavedChanges = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc.AppLocalizations.admin.uploadsQueuedMessage),
        ),
      );
      context.pop(true);
    }
  }

  /// Snapshots the current form state (including picked file bytes) into an
  /// immutable [PublicationSavePayload] for the background queue.
  PublicationSavePayload _buildSavePayload() {
    final images = <String, List<SelectedMediaFile>>{};
    for (final entry in _selectedBlockImageFiles.entries) {
      images[entry.key] = entry.value
          .map(
            (file) => SelectedMediaFile(bytes: file.bytes, name: file.name),
          )
          .toList();
    }
    final audios = <String, SelectedMediaFile>{};
    for (final entry in _selectedBlockAudioFiles.entries) {
      final file = entry.value;
      audios[entry.key] = SelectedMediaFile(bytes: file.bytes, name: file.name);
    }
    final videos = <String, SelectedMediaFile>{};
    for (final entry in _selectedBlockVideoFiles.entries) {
      final file = entry.value;
      videos[entry.key] = SelectedMediaFile(bytes: file.bytes, name: file.name);
    }
    final files = <String, SelectedMediaFile>{};
    for (final entry in _selectedBlockFiles.entries) {
      final file = entry.value;
      files[entry.key] = SelectedMediaFile(bytes: file.bytes, name: file.name);
    }
    return PublicationSavePayload(
      publicationId: widget.publicationId,
      isPhoto: false,
      title: _titleController.text.trim(),
      icon: _selectedIcon,
      type: 'article',
      publishedAt: _publishedAt ?? DateTime.now(),
      status: _status,
      primarySectionId: _primarySectionId ?? '',
      hasAdditionalSections: _hasAdditionalSections,
      sectionIds: _sectionIdsToSave(),
      contentBlocks: _contentBlocks.toList(),
      newBlockImages: images,
      newBlockAudios: audios,
      newBlockVideos: videos,
      newBlockFiles: files,
    );
  }

  /// Section memberships to persist. When additional sections are disabled,
  /// the publication is shown only in its primary section.
  List<String> _sectionIdsToSave() {
    if (!_hasAdditionalSections) {
      final primary = _primarySectionId;
      return primary == null || primary.isEmpty ? const [] : [primary];
    }
    return _selectedSectionIds.toList();
  }

  /// Removes storage files that were replaced during this save. Called after
  /// the DB successfully saved the new blocks, so old files are freed only
  /// once nothing references them anymore.

  void _moveBlockUp(int index) {
    if (index > 0) {
      setState(() {
        final block = _contentBlocks.removeAt(index);
        _contentBlocks.insert(index - 1, block);
        _updateOrderIndices();
      });
      _markUnsaved();
    }
  }

  void _moveBlockDown(int index) {
    if (index < _contentBlocks.length - 1) {
      setState(() {
        final block = _contentBlocks.removeAt(index);
        _contentBlocks.insert(index + 1, block);
        _updateOrderIndices();
      });
      _markUnsaved();
    }
  }

  void _removeBlock(int index) {
    setState(() {
      _contentBlocks.removeAt(index);
    });
    _markUnsaved();
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _pickDate() async {
    final now = _publishedAt ?? DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date != null && mounted) {
      final time = TimeOfDay.fromDateTime(now);
      final timePicked = await showTimePicker(
        context: context,
        initialTime: time,
      );
      if (timePicked != null && mounted) {
        setState(() {
          _publishedAt = DateTime(
            date.year,
            date.month,
            date.day,
            timePicked.hour,
            timePicked.minute,
          );
          _dateController.text = _formatDate(_publishedAt!);
          _hasUnsavedChanges = true;
        });
      }
    }
  }

  void _updateOrderIndices() {
    for (int i = 0; i < _contentBlocks.length; i++) {
      final block = _contentBlocks[i];
      switch (block) {
        case TextContentBlock():
          _contentBlocks[i] = block.copyWith(orderIndex: i);
          break;
        case ImageContentBlock():
          _contentBlocks[i] = block.copyWith(orderIndex: i);
          break;
        case VideoContentBlock():
          _contentBlocks[i] = block.copyWith(orderIndex: i);
          break;
        case AudioContentBlock():
          _contentBlocks[i] = block.copyWith(orderIndex: i);
          break;
        case FileContentBlock():
          _contentBlocks[i] = block.copyWith(orderIndex: i);
          break;
      }
    }
  }

  /// Shows exit confirmation dialog if there are unsaved changes.
  /// If no changes, exits immediately.
  Future<bool> _onWillPop() async {
    if (!_hasUnsavedChanges) return true;

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(loc.AppLocalizations.admin.unsavedChanges),
        content: Text(loc.AppLocalizations.admin.unsavedChangesMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'cancel'),
            child: Text(loc.AppLocalizations.admin.cancelAction),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'discard'),
            child: Text(loc.AppLocalizations.admin.leaveWithoutSaving),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, 'save'),
            child: Text(loc.AppLocalizations.admin.saveAction),
          ),
        ],
      ),
    );

    if (result == 'save') {
      await _savePublication();
      // _savePublication already handles navigation after success
      return false;
    } else if (result == 'discard') {
      return true;
    }
    return false; // cancel
  }

  void _onBackPressed() async {
    final canPop = await _onWillPop();
    if (canPop && mounted) {
      context.pop();
    }
  }

  void _markUnsaved() {
    if (!_hasUnsavedChanges) {
      setState(() {
        _hasUnsavedChanges = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        _onBackPressed();
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: AppColors.secondary,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _onBackPressed,
          ),
          title: Text(
            widget.publicationId == null
                ? loc.AppLocalizations.admin.newPublicationTitle
                : loc.AppLocalizations.admin.editPublicationTitle,
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _savePublication,
            ),
          ],
          bottom: _buildStatusBar(),
        ),
        body: Column(
          children: [
            Expanded(
              child: FutureBuilder<PublicationDetail?>(
                future: _publicationFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  return Form(
                    key: _formKey,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Metadata Card
                          _buildSectionCard(
                            title: loc.AppLocalizations.admin.metadata,
                            icon: Icons.info_outline,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                TextFormField(
                                  controller: _titleController,
                                  decoration: InputDecoration(
                                    labelText:
                                        loc.AppLocalizations.admin.titleField,
                                    border: const OutlineInputBorder(),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return loc
                                          .AppLocalizations
                                          .admin
                                          .enterTitle;
                                    }
                                    return null;
                                  },
                                  onChanged: (value) {
                                    _markUnsaved();
                                  },
                                ),
                                const SizedBox(height: 12),
                                _buildIconSelector(),
                                const SizedBox(height: 12),
                                // Primary section (radio)
                                FutureBuilder<List<Section>>(
                                  future: _sectionsFuture,
                                  builder: (context, snapshot) {
                                    if (snapshot.connectionState ==
                                        ConnectionState.waiting) {
                                      return const Padding(
                                        padding: EdgeInsets.symmetric(
                                          vertical: 8,
                                        ),
                                        child: LinearProgressIndicator(),
                                      );
                                    }

                                    if (snapshot.hasError) {
                                      return Text(
                                        loc.AppLocalizations.admin
                                            .sectionLoadError(
                                              '${snapshot.error}',
                                            ),
                                      );
                                    }

                                    if (!snapshot.hasData ||
                                        snapshot.data!.isEmpty) {
                                      return Text(
                                        loc
                                            .AppLocalizations
                                            .admin
                                            .noSectionsAvailable,
                                      );
                                    }

                                    final sections = snapshot.data!;
                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          loc
                                              .AppLocalizations
                                              .admin
                                              .primarySection,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        ...sections.map((section) {
                                          final isPrimary =
                                              _primarySectionId == section.id;
                                          return ListTile(
                                            title: Text(
                                              section.name,
                                              style: const TextStyle(
                                                fontSize: 14,
                                              ),
                                            ),
                                            leading: Icon(
                                              isPrimary
                                                  ? Icons.radio_button_checked
                                                  : Icons.radio_button_off,
                                              color: isPrimary
                                                  ? Colors.blue
                                                  : AppColors.textLight,
                                              size: 20,
                                            ),
                                            onTap: () {
                                              setState(() {
                                                _primarySectionId = section.id;
                                                _selectedSectionIds.add(
                                                  section.id,
                                                );
                                                _sectionValidationAttempted =
                                                    false;
                                              });
                                              _markUnsaved();
                                            },
                                            contentPadding: EdgeInsets.zero,
                                            dense: true,
                                            visualDensity:
                                                VisualDensity.compact,
                                          );
                                        }),
                                        if (_sectionValidationAttempted &&
                                            (_primarySectionId == null ||
                                                _primarySectionId!
                                                    .isEmpty)) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            loc
                                                .AppLocalizations
                                                .admin
                                                .selectPrimarySection,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.red[700],
                                            ),
                                          ),
                                        ],
                                      ],
                                    );
                                  },
                                ),
                                const SizedBox(height: 12),
                                // Additional sections toggle
                                SwitchListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(
                                    loc
                                        .AppLocalizations
                                        .admin
                                        .enableAdditionalSections,
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                  subtitle: Text(
                                    loc
                                        .AppLocalizations
                                        .admin
                                        .enableAdditionalSectionsHint,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  value: _hasAdditionalSections,
                                  onChanged: (value) {
                                    setState(() {
                                      _hasAdditionalSections = value;
                                    });
                                    _markUnsaved();
                                  },
                                ),
                                if (_hasAdditionalSections) ...[
                                  const SizedBox(height: 8),
                                  FutureBuilder<List<Section>>(
                                    future: _sectionsFuture,
                                    builder: (context, snapshot) {
                                      if (snapshot.connectionState ==
                                          ConnectionState.waiting) {
                                        return const Padding(
                                          padding: EdgeInsets.symmetric(
                                            vertical: 8,
                                          ),
                                          child: LinearProgressIndicator(),
                                        );
                                      }

                                      if (snapshot.hasError) {
                                        return Text(
                                          loc.AppLocalizations.admin
                                              .sectionLoadError(
                                                '${snapshot.error}',
                                              ),
                                        );
                                      }

                                      if (!snapshot.hasData ||
                                          snapshot.data!.isEmpty) {
                                        return Text(
                                          loc
                                              .AppLocalizations
                                              .admin
                                              .noSectionsAvailable,
                                        );
                                      }

                                      final sections = snapshot.data!;
                                      return Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const SizedBox(height: 4),
                                          Wrap(
                                            spacing: 6.0,
                                            runSpacing: 6.0,
                                            children: sections.map((section) {
                                              final isPrimary =
                                                  section.id ==
                                                  _primarySectionId;
                                              return FilterChip(
                                                label: Text(
                                                  section.name,
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                  ),
                                                ),
                                                selected: _selectedSectionIds
                                                    .contains(section.id),
                                                onSelected: isPrimary
                                                    ? null
                                                    : (selected) {
                                                        setState(() {
                                                          if (selected) {
                                                            _selectedSectionIds
                                                                .add(
                                                                  section.id,
                                                                );
                                                          } else {
                                                            _selectedSectionIds
                                                                .remove(
                                                                  section.id,
                                                                );
                                                          }
                                                        });
                                                        _markUnsaved();
                                                      },
                                              );
                                            }).toList(),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ],
                                const SizedBox(height: 12),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Content Blocks
                          _buildSectionCard(
                            title: loc.AppLocalizations.admin.contentBlocks,
                            icon: Icons.view_stream,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Blocks list
                                if (_contentBlocks.isEmpty)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    child: Center(
                                      child: Text(
                                        loc
                                            .AppLocalizations
                                            .admin
                                            .addFirstBlock,
                                        style: const TextStyle(
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ),
                                  )
                                else
                                  ListView.builder(
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    itemCount: _contentBlocks.length,
                                    itemBuilder: (context, index) {
                                      final block = _contentBlocks[index];
                                      return _buildContentBlockWidget(
                                        block,
                                        index,
                                      );
                                    },
                                  ),
                                const SizedBox(height: 8),
                                const Divider(),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 2,
                                  ),
                                  child: Text(
                                    loc.AppLocalizations.admin.addBlock,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                _buildAddBlockButtons(),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Bottom bar of the AppBar holding the publication status + publish date.
  PreferredSize _buildStatusBar() {
    final showDate = _status == 'published' || widget.publicationId != null;

    return PreferredSize(
      preferredSize: const Size.fromHeight(56),
      child: Container(
        color: AppColors.secondary,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          children: [
            // Status — a full-height tappable pill with a readable tap target.
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _status,
                    isDense: true,
                    isExpanded: true,
                    dropdownColor: Colors.white,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                    iconEnabledColor: Colors.white,
                    items: [
                      DropdownMenuItem(
                        value: 'draft',
                        child: Text(
                          loc.AppLocalizations.admin.statusDraft,
                          style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'published',
                        child: Text(
                          loc.AppLocalizations.admin.statusPublished,
                          style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _status = value;
                          if (value == 'published' &&
                              _publishedAt == null &&
                              _initialStatus != 'published') {
                            final now = DateTime.now();
                            _publishedAt = now;
                            _dateController.text = _formatDate(now);
                          }
                        });
                        _markUnsaved();
                      }
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Date — a bigger, easy-to-tap clickable button.
            if (showDate)
              GestureDetector(
                onTap: _pickDate,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.calendar_today,
                        size: 16,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _dateController.text.isNotEmpty
                            ? _dateController.text
                            : loc.AppLocalizations.admin.publishDate,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: AppColors.secondary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildAddBlockButtons() {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        _buildAddBlockChip(
          icon: Icons.text_fields,
          label: loc.AppLocalizations.admin.textBlock,
          color: Colors.blue,
          onPressed: () {
            setState(() {
              _contentBlocks.add(
                TextContentBlock(
                  id: _uuid.v4(),
                  publicationId: widget.publicationId ?? '',
                  orderIndex: _contentBlocks.length,
                  text: '',
                ),
              );
            });
            _markUnsaved();
          },
        ),
        _buildAddBlockChip(
          icon: Icons.image,
          label: loc.AppLocalizations.admin.imageBlock,
          color: Colors.green,
          onPressed: () {
            setState(() {
              _contentBlocks.add(
                ImageContentBlock(
                  id: _uuid.v4(),
                  publicationId: widget.publicationId ?? '',
                  orderIndex: _contentBlocks.length,
                  imagePaths: [],
                ),
              );
            });
            _markUnsaved();
          },
        ),
        _buildAddBlockChip(
          icon: Icons.video_library,
          label: loc.AppLocalizations.admin.videoBlock,
          color: Colors.purple,
          onPressed: () {
            setState(() {
              _contentBlocks.add(
                VideoContentBlock(
                  id: _uuid.v4(),
                  publicationId: widget.publicationId ?? '',
                  orderIndex: _contentBlocks.length,
                  url: '',
                  provider: VideoProviderType.rutube,
                ),
              );
            });
            _markUnsaved();
          },
        ),
        _buildAddBlockChip(
          icon: Icons.audiotrack,
          label: loc.AppLocalizations.admin.audioBlock,
          color: Colors.orange,
          onPressed: () {
            setState(() {
              _contentBlocks.add(
                AudioContentBlock(
                  id: _uuid.v4(),
                  publicationId: widget.publicationId ?? '',
                  orderIndex: _contentBlocks.length,
                  source: AudioSourceType.upload,
                  audioPath: null,
                ),
              );
            });
            _markUnsaved();
          },
        ),
        _buildAddBlockChip(
          icon: Icons.insert_drive_file,
          label: 'Файл',
          color: Colors.teal,
          onPressed: () {
            setState(() {
              _contentBlocks.add(
                FileContentBlock(
                  id: _uuid.v4(),
                  publicationId: widget.publicationId ?? '',
                  orderIndex: _contentBlocks.length,
                  path: '',
                  name: '',
                ),
              );
            });
            _markUnsaved();
          },
        ),
      ],
    );
  }

  Widget _buildAddBlockChip({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return ActionChip(
      avatar: Icon(icon, size: 16, color: color),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      onPressed: onPressed,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Widget _buildIconSelector() {
    final showError =
        _iconValidationAttempted &&
        (_selectedIcon == null || _selectedIcon!.isEmpty);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          loc.AppLocalizations.admin.iconField,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: AppIcons.paths.entries.map((entry) {
            final iconId = entry.key;
            final iconPath = entry.value;
            final isSelected = _selectedIcon == iconId;

            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedIcon = iconId;
                  _iconValidationAttempted = false;
                });
                _markUnsaved();
              },
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? Colors.blue : Colors.grey.shade300,
                    width: isSelected ? 2 : 1,
                  ),
                  color: isSelected
                      ? Colors.blue.withValues(alpha: 0.08)
                      : Colors.transparent,
                ),
                child: Center(
                  child: Image.asset(
                    iconPath,
                    width: 32,
                    height: 32,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        if (showError) ...[
          const SizedBox(height: 4),
          Text(
            loc.AppLocalizations.admin.selectIcon,
            style: TextStyle(fontSize: 12, color: Colors.red[700]),
          ),
        ],
      ],
    );
  }

  Widget _buildContentBlockWidget(ContentBlock block, int index) {
    switch (block) {
      case TextContentBlock():
        return _buildTextBlockWidget(block, index);
      case ImageContentBlock():
        return _buildImageBlockWidget(block, index);
      case VideoContentBlock():
        return _buildVideoBlockWidget(block, index);
      case AudioContentBlock():
        return _buildAudioBlockWidget(block, index);
      case FileContentBlock():
        return _buildFileBlockWidget(block, index);
    }
  }

  Widget _buildBlockHeader({
    required String title,
    required IconData icon,
    required Color iconColor,
    required int index,
    required bool isCollapsed,
    required VoidCallback onToggleCollapse,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
      ),
      child: Row(
        children: [
          // Reorder buttons - compact horizontal
          SizedBox(
            width: 24,
            height: 24,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(4),
                onTap: index > 0 ? () => _moveBlockUp(index) : null,
                child: Icon(
                  Icons.keyboard_arrow_up,
                  size: 18,
                  color: index > 0
                      ? AppColors.textSecondary
                      : Colors.grey.shade300,
                ),
              ),
            ),
          ),
          SizedBox(
            width: 24,
            height: 24,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(4),
                onTap: index < _contentBlocks.length - 1
                    ? () => _moveBlockDown(index)
                    : null,
                child: Icon(
                  Icons.keyboard_arrow_down,
                  size: 18,
                  color: index < _contentBlocks.length - 1
                      ? AppColors.textSecondary
                      : Colors.grey.shade300,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Collapse toggle
          SizedBox(
            width: 32,
            height: 32,
            child: IconButton(
              icon: Icon(
                isCollapsed
                    ? Icons.keyboard_arrow_down
                    : Icons.keyboard_arrow_up,
                size: 18,
                color: AppColors.textSecondary,
              ),
              onPressed: onToggleCollapse,
              padding: EdgeInsets.zero,
              splashRadius: 16,
            ),
          ),
          // Delete button
          SizedBox(
            width: 32,
            height: 32,
            child: IconButton(
              icon: const Icon(
                Icons.delete_outline,
                size: 18,
                color: Colors.red,
              ),
              onPressed: () => _removeBlock(index),
              padding: EdgeInsets.zero,
              splashRadius: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextBlockWidget(TextContentBlock block, int index) {
    final isCollapsed = _collapsedBlockIds.contains(block.id);

    return Card(
      key: Key(block.id),
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBlockHeader(
            title: loc.AppLocalizations.admin.textBlockLabel,
            icon: Icons.text_fields,
            iconColor: Colors.blue,
            index: index,
            isCollapsed: isCollapsed,
            onToggleCollapse: () {
              setState(() {
                if (isCollapsed) {
                  _collapsedBlockIds.remove(block.id);
                } else {
                  _collapsedBlockIds.add(block.id);
                }
              });
            },
          ),
          if (!isCollapsed)
            Padding(
              padding: const EdgeInsets.all(10),
              child: TextFormField(
                initialValue: block.text,
                decoration: InputDecoration(
                  hintText: loc.AppLocalizations.admin.enterTextHint,
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
                maxLines: 5,
                minLines: 2,
                onChanged: (value) {
                  setState(() {
                    _contentBlocks[index] = block.copyWith(text: value);
                  });
                  _markUnsaved();
                },
              ),
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Image block: multi-photo thumbnails preview
  // ---------------------------------------------------------------------------

  /// Compact grid of thumbnails: kept remote photos first, then the newly
  /// picked (not yet uploaded) files. Each thumbnail has its own remove
  /// button, so an album can be fine-tuned photo by photo.
  Widget _buildImageThumbnails(
    ImageContentBlock block,
    List<_SelectedFile> stagedFiles,
  ) {
    final mediaStorage = ref.read(mediaStorageRepositoryProvider);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        for (var i = 0; i < block.imagePaths.length; i++)
          _buildImageThumbnail(
            child: Image.network(
              mediaStorage.publicUrlFor(block.imagePaths[i]),
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  const Center(child: Icon(Icons.broken_image, size: 28)),
            ),
            onRemove: () => _removeRemoteImage(block, i),
          ),
        for (var i = 0; i < stagedFiles.length; i++)
          _buildImageThumbnail(
            child: Image.memory(
              stagedFiles[i].bytes,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  const Center(child: Icon(Icons.broken_image, size: 28)),
            ),
            onRemove: () => _removeStagedImage(block.id, i),
          ),
      ],
    );
  }

  /// A fixed-size rounded thumbnail with a small remove button in the corner.
  Widget _buildImageThumbnail({
    required Widget child,
    required VoidCallback onRemove,
  }) {
    return SizedBox(
      width: 88,
      height: 88,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Stack(
          children: [
            Positioned.fill(child: child),
            Positioned(
              top: 4,
              right: 4,
              child: Material(
                color: Colors.black54,
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onRemove,
                  child: Ink(
                    width: 22,
                    height: 22,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: const Icon(
                        Icons.close,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Removes a kept remote photo from the block. The save job persists the
  /// shortened list, and [PublicationRepositoryImpl.replaceBlocks] frees the
  /// dropped Storage path once nothing references it.
  void _removeRemoteImage(ImageContentBlock block, int pathIndex) {
    final paths = block.imagePaths.toList();
    if (pathIndex < 0 || pathIndex >= paths.length) return;
    paths.removeAt(pathIndex);
    setState(() {
      final idx = _contentBlocks.indexWhere((b) => b.id == block.id);
      if (idx != -1) {
        _contentBlocks[idx] = block.copyWith(imagePaths: paths);
      }
    });
    _markUnsaved();
  }

  /// Removes a newly picked (not yet uploaded) file from the block's staged
  /// list.
  void _removeStagedImage(String blockId, int stagedIndex) {
    setState(() {
      final staged = _selectedBlockImageFiles[blockId];
      if (staged != null &&
          stagedIndex >= 0 &&
          stagedIndex < staged.length) {
        staged.removeAt(stagedIndex);
        if (staged.isEmpty) _selectedBlockImageFiles.remove(blockId);
      }
    });
    _markUnsaved();
  }

  /// Clears the whole image block: staged files and kept remote paths.
  void _clearBlockImages(ImageContentBlock block) {
    setState(() {
      _selectedBlockImageFiles.remove(block.id);
      final idx = _contentBlocks.indexWhere((b) => b.id == block.id);
      if (idx != -1) {
        _contentBlocks[idx] = block.copyWith(imagePaths: const <String>[]);
      }
    });
    _markUnsaved();
  }

  Widget _buildImageBlockWidget(ImageContentBlock block, int index) {
    final isCollapsed = _collapsedBlockIds.contains(block.id);
    final stagedFiles =
        _selectedBlockImageFiles[block.id] ?? const <_SelectedFile>[];
    final hasPhotos = block.imagePaths.isNotEmpty || stagedFiles.isNotEmpty;

    return Card(
      key: Key(block.id),
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBlockHeader(
            title: loc.AppLocalizations.admin.imageBlock,
            icon: Icons.image,
            iconColor: Colors.green,
            index: index,
            isCollapsed: isCollapsed,
            onToggleCollapse: () {
              setState(() {
                if (isCollapsed) {
                  _collapsedBlockIds.remove(block.id);
                } else {
                  _collapsedBlockIds.add(block.id);
                }
              });
            },
          ),
          if (!isCollapsed)
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image selection area
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        // Thumbnails: kept remote photos + newly picked files,
                        // each with its own remove button.
                        if (hasPhotos)
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: _buildImageThumbnails(block, stagedFiles),
                          )
                        else
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Center(
                              child: Icon(
                                Icons.add_photo_alternate_outlined,
                                size: 40,
                                color: Colors.grey.shade400,
                              ),
                            ),
                          ),
                        // Select / Add / Remove-all buttons
                        Padding(
                          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              TextButton.icon(
                                onPressed: () => _pickBlockImage(block.id),
                                icon: const Icon(
                                  Icons.add_photo_alternate,
                                  size: 16,
                                ),
                                label: Text(
                                  hasPhotos
                                      ? loc.AppLocalizations.admin.addImage
                                      : loc.AppLocalizations.admin.selectImage,
                                  style: const TextStyle(fontSize: 12),
                                ),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 4,
                                  ),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                              if (hasPhotos) ...[
                                const SizedBox(width: 8),
                                TextButton.icon(
                                  onPressed: () => _clearBlockImages(block),
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    size: 16,
                                    color: Colors.red,
                                  ),
                                  label: Text(
                                    loc.AppLocalizations.admin.deleteAllImages,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.red,
                                    ),
                                  ),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 4,
                                    ),
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Resolves the current input mode of a video block. Uploaded videos always
  /// map to [VideoMode.upload]; external ones follow their provider.
  _VideoMode _videoModeOf(VideoContentBlock block) {
    if (block.source == VideoSourceType.upload) return _VideoMode.upload;
    return switch (block.provider) {
      VideoProviderType.youtube => _VideoMode.youtube,
      VideoProviderType.rutube => _VideoMode.rutube,
      // `vk`/`direct` are not offered in the editor; default to YouTube.
      _ => _VideoMode.youtube,
    };
  }

  Widget _buildVideoBlockWidget(VideoContentBlock block, int index) {
    final isCollapsed = _collapsedBlockIds.contains(block.id);
    final mode = _videoModeOf(block);

    return Card(
      key: Key(block.id),
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBlockHeader(
            title: loc.AppLocalizations.admin.videoBlock,
            icon: Icons.video_library,
            iconColor: Colors.purple,
            index: index,
            isCollapsed: isCollapsed,
            onToggleCollapse: () {
              setState(() {
                if (isCollapsed) {
                  _collapsedBlockIds.remove(block.id);
                } else {
                  _collapsedBlockIds.add(block.id);
                }
              });
            },
          ),
          if (!isCollapsed)
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<_VideoMode>(
                    initialValue: mode,
                    decoration: InputDecoration(
                      labelText: loc.AppLocalizations.admin.platformField,
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: _VideoMode.youtube,
                        child: Text(loc.AppLocalizations.admin.youtubeLabel),
                      ),
                      DropdownMenuItem(
                        value: _VideoMode.rutube,
                        child: Text(loc.AppLocalizations.admin.rutubeLabel),
                      ),
                      DropdownMenuItem(
                        value: _VideoMode.upload,
                        child: Text(
                          loc.AppLocalizations.admin.videoUploadLabel,
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      final next = value;
                      if (next == null) return;
                      setState(() {
                        _contentBlocks[index] = switch (next) {
                          _VideoMode.youtube || _VideoMode.rutube =>
                            VideoContentBlock(
                              id: block.id,
                              publicationId: block.publicationId,
                              orderIndex: block.orderIndex,
                              source: VideoSourceType.external,
                              url: block.url,
                              provider: next == _VideoMode.youtube
                                  ? VideoProviderType.youtube
                                  : VideoProviderType.rutube,
                              // A link replaces any previously uploaded file.
                              videoPath: null,
                              videoName: null,
                              videoMime: null,
                              videoSize: null,
                            ),
                          _VideoMode.upload => block.copyWith(
                            source: VideoSourceType.upload,
                            url: '',
                          ),
                        };
                      });
                      _markUnsaved();
                    },
                  ),
                  if (mode != _VideoMode.upload) ...[
                    const SizedBox(height: 10),
                    TextFormField(
                      initialValue: block.url,
                      decoration: InputDecoration(
                        labelText: loc.AppLocalizations.admin.videoUrlField,
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _contentBlocks[index] = block.copyWith(url: value);
                        });
                        _markUnsaved();
                      },
                    ),
                  ],
                  // Only the "upload" mode exposes the file picker.
                  if (mode == _VideoMode.upload) ...[
                    const SizedBox(height: 10),
                    _buildVideoUploadArea(block),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVideoUploadArea(VideoContentBlock block) {
    final selected = _selectedBlockVideoFiles[block.id];
    final hasExisting = block.source == VideoSourceType.upload &&
        (block.videoPath ?? '').isNotEmpty;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        OutlinedButton(
          onPressed: () => _pickBlockVideo(block.id),
          child: Text(
            selected == null && !hasExisting ? 'Загрузить видео' : 'Заменить видео',
          ),
        ),
        if (selected != null)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(selected.name, overflow: TextOverflow.ellipsis),
            ),
          )
        else if (hasExisting)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(
                block.videoName ?? block.videoPath!,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFileBlockWidget(FileContentBlock block, int index) {
    final isCollapsed = _collapsedBlockIds.contains(block.id);
    final selected = _selectedBlockFiles[block.id];

    return Card(
      key: Key(block.id),
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBlockHeader(
            title: 'Файл',
            icon: Icons.insert_drive_file,
            iconColor: Colors.teal,
            index: index,
            isCollapsed: isCollapsed,
            onToggleCollapse: () {
              setState(() {
                if (isCollapsed) {
                  _collapsedBlockIds.remove(block.id);
                } else {
                  _collapsedBlockIds.add(block.id);
                }
              });
            },
          ),
          if (!isCollapsed)
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      OutlinedButton(
                        onPressed: () => _pickBlockFile(block.id),
                        child: Text(
                          selected == null && block.path.isEmpty
                              ? 'Выбрать файл'
                              : 'Заменить файл',
                        ),
                      ),
                      if (selected != null)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Text(
                              selected.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                      else if (block.path.isNotEmpty)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Text(
                              block.name.isEmpty ? block.path : block.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAudioBlockWidget(AudioContentBlock block, int index) {
    final isCollapsed = _collapsedBlockIds.contains(block.id);
    final selectedAudioFile = _selectedBlockAudioFiles[block.id];

    return Card(
      key: Key(block.id),
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBlockHeader(
            title: loc.AppLocalizations.admin.audioBlock,
            icon: Icons.audiotrack,
            iconColor: Colors.orange,
            index: index,
            isCollapsed: isCollapsed,
            onToggleCollapse: () {
              setState(() {
                if (isCollapsed) {
                  _collapsedBlockIds.remove(block.id);
                } else {
                  _collapsedBlockIds.add(block.id);
                }
              });
            },
          ),
          if (!isCollapsed)
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Audio file selection
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        if (selectedAudioFile != null) ...[
                          Row(
                            children: [
                              const Icon(
                                Icons.audiotrack,
                                size: 20,
                                color: Colors.orange,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  selectedAudioFile.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 12,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const Icon(
                                Icons.check_circle,
                                color: Colors.green,
                                size: 18,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                        ] else if (block.audioPath?.isNotEmpty ?? false) ...[
                          Row(
                            children: [
                              const Icon(
                                Icons.audiotrack,
                                size: 20,
                                color: Colors.orange,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  block.audioPath!.split('/').last,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 12,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const Icon(
                                Icons.check_circle,
                                color: Colors.green,
                                size: 18,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                        ],
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            TextButton.icon(
                              onPressed: () => _pickBlockAudio(block.id),
                              icon: const Icon(Icons.upload_file, size: 16),
                              label: Text(
                                selectedAudioFile != null ||
                                        (block.audioPath?.isNotEmpty ?? false)
                                    ? loc.AppLocalizations.admin.replaceFile
                                    : loc.AppLocalizations.admin.selectFile,
                                style: const TextStyle(fontSize: 12),
                              ),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                            if (selectedAudioFile != null ||
                                (block.audioPath?.isNotEmpty ?? false)) ...[
                              const SizedBox(width: 8),
                              TextButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _selectedBlockAudioFiles.remove(block.id);
                                    final idx = _contentBlocks.indexWhere(
                                      (b) => b.id == block.id,
                                    );
                                    if (idx != -1) {
                                      _contentBlocks[idx] = block.copyWith(
                                        audioPath: null,
                                      );
                                    }
                                  });
                                  _markUnsaved();
                                },
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: 16,
                                  color: Colors.red,
                                ),
                                label: Text(
                                  loc.AppLocalizations.admin.deleteAction,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.red,
                                  ),
                                ),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 4,
                                  ),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
