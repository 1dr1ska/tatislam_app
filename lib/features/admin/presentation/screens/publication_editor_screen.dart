import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';

import 'package:image_picker/image_picker.dart';
import 'package:tatislam_app/core/constants/app_colors.dart';
import 'package:tatislam_app/core/services/media_optimization_service.dart';
import 'package:tatislam_app/core/constants/app_icons.dart';
import 'package:tatislam_app/core/storage/storage_paths.dart';
import 'package:tatislam_app/core/storage/storage_providers.dart';
import 'package:tatislam_app/features/publications/data/publication_providers.dart';
import 'package:tatislam_app/features/publications/domain/entities/audio_source_type.dart';
import 'package:tatislam_app/features/publications/domain/entities/content_block.dart';
import 'package:tatislam_app/features/publications/domain/entities/publication_detail.dart';
import 'package:tatislam_app/features/publications/domain/entities/video_provider_type.dart';
import 'package:tatislam_app/features/sections/data/section_providers.dart';
import 'package:tatislam_app/features/sections/domain/entities/section.dart';

/// Tracks the current step of the save process for UI feedback.
enum _SaveStep {
  idle,
  savingMetadata,
  uploadingFiles,
  savingSections,
  savingBlocks,
  done,
  error,
}

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
  String _status = 'draft';
  DateTime? _publishedAt;

  // Map to store selected image files for each content block
  final Map<String, File> _selectedBlockImageFiles = {};

  // Map to store selected audio files for each content block
  final Map<String, File> _selectedBlockAudioFiles = {};

  // Track which blocks are expanded/collapsed
  final Set<String> _collapsedBlockIds = {};

  bool _isSaving = false;
  _SaveStep _currentSaveStep = _SaveStep.idle;
  int _uploadedFileCount = 0;
  int _totalFileCount = 0;
  bool _hasUnsavedChanges = false;
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
      _status = detail.publication.status ?? 'draft';
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
          SnackBar(content: Text('Ошибка загрузки публикации: $e')),
        );
      }
      return null;
    }
  }

  Future<void> _pickBlockImage(String blockId) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 95,
      );

      if (pickedFile != null) {
        // Verify the file is accessible
        final file = File(pickedFile.path);
        if (!await file.exists()) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Ошибка: файл не найден')),
            );
          }
          return;
        }
        setState(() {
          _selectedBlockImageFiles[blockId] = file;
          _hasUnsavedChanges = true;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка выбора изображения: $e')),
        );
      }
    }
  }

  Future<void> _pickBlockAudio(String blockId) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _selectedBlockAudioFiles[blockId] = File(result.files.single.path!);
        _hasUnsavedChanges = true;
      });
    }
  }

  Future<String> _uploadBlockImage(
      String blockId, String currentImagePath) async {
    final selectedImageFile = _selectedBlockImageFiles[blockId];

    if (selectedImageFile == null) {
      return currentImagePath;
    }

    try {
      final storageRepository = ref.read(mediaStorageRepositoryProvider);

      // Optimize image before upload (resize to 1920px max, JPEG quality 90)
      final rawBytes = await selectedImageFile.readAsBytes();
      final optimizationService = const MediaOptimizationService();
      final result = await optimizationService.optimizeImage(
        originalBytes: rawBytes,
        originalFileName: selectedImageFile.path.split('/').last,
      );

      final bytes = result.bytes;
      final extension = result.fileName.split('.').last;

      final path = StoragePaths.blockImage(
          widget.publicationId ?? _uuid.v4(), extension,
          blockId: blockId);

      final s3Key = await storageRepository.upload(path, bytes);

      if (currentImagePath.isNotEmpty && currentImagePath != s3Key) {
        try {
          await storageRepository.delete([currentImagePath]);
        } catch (e) {
          // Ignore delete errors
        }
      }

      return s3Key;
    } catch (e) {
      throw Exception('Ошибка загрузки изображения: $e');
    }
  }

  Future<String> _uploadBlockAudio(
      String blockId, String currentAudioPath) async {
    final selectedAudioFile = _selectedBlockAudioFiles[blockId];

    if (selectedAudioFile == null) {
      return currentAudioPath;
    }

    try {
      final storageRepository = ref.read(mediaStorageRepositoryProvider);
      final extension = selectedAudioFile.path.split('.').last;
      final path = StoragePaths.blockAudio(
          widget.publicationId ?? _uuid.v4(), extension,
          blockId: blockId);

      final bytes = await selectedAudioFile.readAsBytes();
      final s3Key = await storageRepository.upload(path, bytes);

      if (currentAudioPath.isNotEmpty && currentAudioPath != s3Key) {
        try {
          await storageRepository.delete([currentAudioPath]);
        } catch (e) {
          // Ignore delete errors
        }
      }

      return s3Key;
    } catch (e) {
      throw Exception('Ошибка загрузки аудио: $e');
    }
  }

  Future<List<ContentBlock>> _updateBlocksWithImagePaths(
      String publicationId) async {
    final updatedBlocks = <ContentBlock>[];

    _totalFileCount = 0;
    for (final block in _contentBlocks) {
      if (block is ImageContentBlock &&
          _selectedBlockImageFiles.containsKey(block.id)) {
        _totalFileCount++;
      } else if (block is AudioContentBlock &&
          _selectedBlockAudioFiles.containsKey(block.id)) {
        _totalFileCount++;
      }
    }
    _uploadedFileCount = 0;

    for (final block in _contentBlocks) {
      if (block is ImageContentBlock) {
        final imagePath =
            await _uploadBlockImage(block.id, block.imagePath);
        final updatedBlock = block.copyWith(imagePaths: [imagePath]);
        updatedBlocks.add(updatedBlock);
        _uploadedFileCount++;
        _updateSaveStep();
      } else if (block is AudioContentBlock) {
        final audioPath =
            await _uploadBlockAudio(block.id, block.audioPath ?? '');
        final updatedBlock = block.copyWith(audioPath: audioPath);
        updatedBlocks.add(updatedBlock);
        _uploadedFileCount++;
        _updateSaveStep();
      } else {
        updatedBlocks.add(block);
      }
    }

    return updatedBlocks;
  }

  void _updateSaveStep() {
    setState(() {
      // Trigger rebuild to show updated progress
    });
  }

  String _saveStepLabel() {
    switch (_currentSaveStep) {
      case _SaveStep.idle:
        return '';
      case _SaveStep.savingMetadata:
        return 'Сохранение данных...';
      case _SaveStep.uploadingFiles:
        if (_totalFileCount > 0) {
          return 'Загрузка файлов $_uploadedFileCount/$_totalFileCount...';
        }
        return 'Загрузка файлов...';
      case _SaveStep.savingSections:
        return 'Сохранение разделов...';
      case _SaveStep.savingBlocks:
        return 'Сохранение блоков...';
      case _SaveStep.done:
        return 'Сохранено';
      case _SaveStep.error:
        return 'Ошибка сохранения';
    }
  }

  /// Auto-fills date when first publishing if no date is set.
  /// Does NOT modify already-published publications.
  void _ensureDateOnPublish() {
    if (_status == 'published' && _publishedAt == null && _initialStatus != 'published') {
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
        ImageContentBlock() => block.imagePaths.every((p) => p.isEmpty),
        VideoContentBlock() => block.url.trim().isEmpty,
        AudioContentBlock() =>
          (block.audioPath == null || block.audioPath!.trim().isEmpty) &&
          (block.audioUrl == null || block.audioUrl!.trim().isEmpty),
      };
    });
  }

  Future<void> _savePublication() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Auto-set date if publishing for the first time
    _ensureDateOnPublish();

    // Remove empty blocks before saving
    _removeEmptyBlocks();

    setState(() {
      _isSaving = true;
      _currentSaveStep = _SaveStep.savingMetadata;
    });

    try {
      final title = _titleController.text.trim();
      final repository = ref.read(publicationRepositoryProvider);

      if (widget.publicationId == null) {
        // Create new publication
        final publication = await repository.createPublication(
          title: title,
          description: '',
          icon: _selectedIcon,
          type: 'article',
          publishedAt: _publishedAt ?? DateTime.now(),
          status: _status,
          primarySectionId: _primarySectionId ?? '',
        );

        setState(() {
          _currentSaveStep = _SaveStep.uploadingFiles;
        });

        final updatedBlocks =
            await _updateBlocksWithImagePaths(publication.id);

        setState(() {
          _currentSaveStep = _SaveStep.savingSections;
        });

        await repository.setSections(
            publication.id, _selectedSectionIds.toList());

        setState(() {
          _currentSaveStep = _SaveStep.savingBlocks;
        });

        await repository.replaceBlocks(publication.id, updatedBlocks);

        setState(() {
          _currentSaveStep = _SaveStep.done;
        });

        if (mounted) {
          final messenger = ScaffoldMessenger.of(context);
          await Future.delayed(const Duration(milliseconds: 500));
          messenger.showSnackBar(
            const SnackBar(content: Text('Публикация создана')),
          );
          ref.invalidate(publicationRepositoryProvider);
          if (mounted) context.pop(true);
        }
      } else {
        // Update existing publication
        final publication = await repository.updatePublication(
          id: widget.publicationId!,
          title: title,
          description: '',
          icon: _selectedIcon,
          publishedAt: _publishedAt ?? DateTime.now(),
          type: 'article',
          status: _status,
          primarySectionId: _primarySectionId ?? '',
        );

        setState(() {
          _currentSaveStep = _SaveStep.uploadingFiles;
        });

        final updatedBlocks =
            await _updateBlocksWithImagePaths(publication.id);

        setState(() {
          _currentSaveStep = _SaveStep.savingSections;
        });

        await repository.setSections(
            widget.publicationId!, _selectedSectionIds.toList());

        setState(() {
          _currentSaveStep = _SaveStep.savingBlocks;
        });

        await repository.replaceBlocks(
            widget.publicationId!, updatedBlocks);

        setState(() {
          _hasUnsavedChanges = false;
          _currentSaveStep = _SaveStep.done;
        });

        if (mounted) {
          final messenger = ScaffoldMessenger.of(context);
          await Future.delayed(const Duration(milliseconds: 500));
          messenger.showSnackBar(
            const SnackBar(content: Text('Публикация обновлена')),
          );
          ref.invalidate(publicationRepositoryProvider);
          if (mounted) context.pop(true);
        }
      }
    } catch (e) {
      setState(() {
        _currentSaveStep = _SaveStep.error;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка сохранения: $e')),
        );
      }
    } finally {
      setState(() {
        _isSaving = false;
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() {
              _currentSaveStep = _SaveStep.idle;
            });
          }
        });
      });
    }
  }

  void _moveBlockUp(int index) {
    if (index > 0) {
      setState(() {
        final block = _contentBlocks.removeAt(index);
        _contentBlocks.insert(index - 1, block);
        _updateOrderIndices();
      });
    }
  }

  void _moveBlockDown(int index) {
    if (index < _contentBlocks.length - 1) {
      setState(() {
        final block = _contentBlocks.removeAt(index);
        _contentBlocks.insert(index + 1, block);
        _updateOrderIndices();
      });
    }
  }

  void _removeBlock(int index) {
    setState(() {
      _contentBlocks.removeAt(index);
    });
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
      }
    }
  }

  /// Shows exit confirmation dialog if there are unsaved changes.
  /// If no changes, exits immediately.
  Future<bool> _onWillPop() async {
    if (!_hasUnsavedChanges || _isSaving) return true;

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Несохранённые изменения'),
        content: const Text('У вас есть несохранённые изменения. Что вы хотите сделать?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'cancel'),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'discard'),
            child: const Text('Выйти без сохранения'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, 'save'),
            child: const Text('Сохранить'),
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
              widget.publicationId == null ? 'Новая публикация' : 'Редактировать публикацию'),
          actions: [
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _isSaving ? null : _savePublication,
            ),
          ],
        ),
        body: Column(
          children: [
            if (_currentSaveStep != _SaveStep.idle)
              _buildSaveProgressIndicator(),
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
                            title: 'Метаданные',
                            icon: Icons.info_outline,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                TextFormField(
                                  controller: _titleController,
                                  decoration: const InputDecoration(
                                    labelText: 'Заголовок',
                                    border: OutlineInputBorder(),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Введите заголовок';
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
                                        padding: EdgeInsets.symmetric(vertical: 8),
                                        child: LinearProgressIndicator(),
                                      );
                                    }

                                    if (snapshot.hasError) {
                                      return Text(
                                          'Ошибка загрузки разделов: ${snapshot.error}');
                                    }

                                    if (!snapshot.hasData ||
                                        snapshot.data!.isEmpty) {
                                      return const Text(
                                          'Нет доступных разделов');
                                    }

                                    final sections = snapshot.data!;
                                    return Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Основной раздел (обязательно)',
                                          style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold),
                                        ),
                                        const SizedBox(height: 4),
                                        ...sections.map((section) {
                                          final isPrimary = _primarySectionId == section.id;
                                          return ListTile(
                                            title: Text(section.name, style: const TextStyle(fontSize: 14)),
                                            leading: Icon(
                                              isPrimary
                                                  ? Icons.radio_button_checked
                                                  : Icons.radio_button_off,
                                              color: isPrimary ? Colors.blue : AppColors.textLight,
                                              size: 20,
                                            ),
                                            onTap: () {
                                              setState(() {
                                                _primarySectionId = section.id;
                                                _selectedSectionIds.add(section.id);
                                              });
                                              _markUnsaved();
                                            },
                                            contentPadding: EdgeInsets.zero,
                                            dense: true,
                                            visualDensity: VisualDensity.compact,
                                          );
                                        }),
                                      ],
                                    );
                                  },
                                ),
                                const SizedBox(height: 12),
                                // Additional sections (multi-select)
                                FutureBuilder<List<Section>>(
                                  future: _sectionsFuture,
                                  builder: (context, snapshot) {
                                    if (snapshot.connectionState ==
                                        ConnectionState.waiting) {
                                      return const Padding(
                                        padding: EdgeInsets.symmetric(vertical: 8),
                                        child: LinearProgressIndicator(),
                                      );
                                    }

                                    if (snapshot.hasError) {
                                      return Text(
                                          'Ошибка загрузки разделов: ${snapshot.error}');
                                    }

                                    if (!snapshot.hasData ||
                                        snapshot.data!.isEmpty) {
                                      return const Text(
                                          'Нет доступных разделов');
                                    }

                                    final sections = snapshot.data!;
                                    return Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Дополнительные разделы',
                                          style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold),
                                        ),
                                        const SizedBox(height: 8),
                                        Wrap(
                                          spacing: 6.0,
                                          runSpacing: 6.0,
                                          children: sections.map((section) {
                                            final isPrimary = section.id == _primarySectionId;
                                            return FilterChip(
                                              label: Text(section.name, style: const TextStyle(fontSize: 12)),
                                              selected: _selectedSectionIds
                                                  .contains(section.id),
                                              onSelected: isPrimary
                                                  ? null
                                                  : (selected) {
                                                      setState(() {
                                                        if (selected) {
                                                          _selectedSectionIds
                                                              .add(section.id);
                                                        } else {
                                                          _selectedSectionIds
                                                              .remove(section.id);
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
                                const SizedBox(height: 12),
                                DropdownButtonFormField<String>(
                                  initialValue: _status,
                                  decoration: const InputDecoration(
                                    labelText: 'Статус',
                                    border: OutlineInputBorder(),
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                        value: 'draft',
                                        child: Text('Черновик')),
                                    DropdownMenuItem(
                                        value: 'published',
                                        child: Text('Опубликовано')),
                                  ],
                                  onChanged: (value) {
                                    if (value != null) {
                                      setState(() {
                                        _status = value;
                                        // Auto-set date when first publishing
                                        if (value == 'published' && _publishedAt == null && _initialStatus != 'published') {
                                          final now = DateTime.now();
                                          _publishedAt = now;
                                          _dateController.text = _formatDate(now);
                                        }
                                      });
                                      _markUnsaved();
                                    }
                                  },
                                ),
                                // Date field — hidden for new drafts, shown for published or when editing
                                if (_status == 'published' || widget.publicationId != null) ...[
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: _dateController,
                                    decoration: const InputDecoration(
                                      labelText: 'Дата публикации',
                                      border: OutlineInputBorder(),
                                      suffixIcon: Icon(Icons.calendar_today),
                                    ),
                                    readOnly: true,
                                    onTap: _pickDate,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Content Blocks
                          _buildSectionCard(
                            title: 'Блоки контента',
                            icon: Icons.view_stream,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Blocks list
                                if (_contentBlocks.isEmpty)
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 16),
                                    child: Center(
                                      child: Text(
                                        'Добавьте первый блок контента',
                                        style: TextStyle(color: Colors.grey),
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
                                          block, index);
                                    },
                                  ),
                                const SizedBox(height: 8),
                                const Divider(),
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 2),
                                  child: Text(
                                    'Добавить блок',
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
          label: 'Текст',
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
          label: 'Изображение',
          color: Colors.green,
          onPressed: () {
            setState(() {
              _contentBlocks.add(
                ImageContentBlock.single(
                  id: _uuid.v4(),
                  publicationId: widget.publicationId ?? '',
                  orderIndex: _contentBlocks.length,
                  imagePath: '',
                  caption: '',
                ),
              );
            });
            _markUnsaved();
          },
        ),
        _buildAddBlockChip(
          icon: Icons.video_library,
          label: 'Видео',
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
                  caption: '',
                ),
              );
            });
            _markUnsaved();
          },
        ),
        _buildAddBlockChip(
          icon: Icons.audiotrack,
          label: 'Аудио',
          color: Colors.orange,
          onPressed: () {
            setState(() {
              _contentBlocks.add(
                AudioContentBlock(
                  id: _uuid.v4(),
                  publicationId: widget.publicationId ?? '',
                  orderIndex: _contentBlocks.length,
                  source: AudioSourceType.upload,
                  audioPath: '',
                  caption: '',
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Иконка',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
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
                });
                _markUnsaved();
              },
              child: Container(
                width: 48,
                height: 48,
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
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      iconPath,
                      width: 24,
                      height: 24,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 1),
                    Text(
                      iconId,
                      style: TextStyle(
                        fontSize: 8,
                        color: isSelected ? Colors.blue : Colors.grey,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSaveProgressIndicator() {
    final label = _saveStepLabel();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: _currentSaveStep == _SaveStep.error
          ? Colors.red.shade50
          : _currentSaveStep == _SaveStep.done
              ? Colors.green.shade50
              : Colors.blue.shade50,
      child: Row(
        children: [
          if (_currentSaveStep == _SaveStep.done)
            const Icon(Icons.check_circle, color: Colors.green, size: 18)
          else if (_currentSaveStep == _SaveStep.error)
            const Icon(Icons.error, color: Colors.red, size: 18)
          else
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: _currentSaveStep == _SaveStep.error
                    ? Colors.red.shade800
                    : _currentSaveStep == _SaveStep.done
                        ? Colors.green.shade800
                        : Colors.blue.shade800,
              ),
            ),
          ),
        ],
      ),
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
                  color: index > 0 ? AppColors.textSecondary : Colors.grey.shade300,
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
                onTap: index < _contentBlocks.length - 1 ? () => _moveBlockDown(index) : null,
                child: Icon(
                  Icons.keyboard_arrow_down,
                  size: 18,
                  color: index < _contentBlocks.length - 1 ? AppColors.textSecondary : Colors.grey.shade300,
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
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Collapse toggle
          SizedBox(
            width: 32,
            height: 32,
            child: IconButton(
              icon: Icon(
                isCollapsed ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
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
              icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
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
            title: 'Текстовый блок',
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
                decoration: const InputDecoration(
                  hintText: 'Введите текст...',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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

  Widget _buildImageBlockWidget(ImageContentBlock block, int index) {
    final isCollapsed = _collapsedBlockIds.contains(block.id);
    final hasLocalFile = _selectedBlockImageFiles.containsKey(block.id);
    final localFile = hasLocalFile ? _selectedBlockImageFiles[block.id] : null;

    return Card(
      key: Key(block.id),
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBlockHeader(
            title: 'Изображение',
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
                        // Preview
                        if (hasLocalFile || block.imagePath.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                constraints: const BoxConstraints(maxHeight: 200),
                                width: double.infinity,
                                color: Colors.grey.shade100,
                                child: hasLocalFile
                                    ? Image.file(
                                        localFile!,
                                        fit: BoxFit.contain,
                                        errorBuilder: (context, error, stackTrace) =>
                                            const Center(child: Icon(Icons.broken_image, size: 32)),
                                      )
                                    : Image.network(
                                        ref
                                            .read(mediaStorageRepositoryProvider)
                                            .publicUrlFor(block.imagePath),
                                        fit: BoxFit.contain,
                                        errorBuilder: (context, error, stackTrace) =>
                                            const Center(child: Icon(Icons.broken_image, size: 32)),
                                      ),
                              ),
                            ),
                          )
                        else
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Center(
                              child: Icon(Icons.add_photo_alternate_outlined, size: 40, color: Colors.grey.shade400),
                            ),
                          ),
                        // Select / Replace / Remove buttons
                        Padding(
                          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              TextButton.icon(
                                onPressed: () => _pickBlockImage(block.id),
                                icon: Icon(
                                  hasLocalFile || block.imagePath.isNotEmpty
                                      ? Icons.swap_horiz
                                      : Icons.add_photo_alternate,
                                  size: 16,
                                ),
                                label: Text(
                                  hasLocalFile || block.imagePath.isNotEmpty
                                      ? 'Заменить'
                                      : 'Выбрать',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                              if (hasLocalFile || block.imagePath.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                TextButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      _selectedBlockImageFiles.remove(block.id);
                                      final idx = _contentBlocks.indexWhere((b) => b.id == block.id);
                                      if (idx != -1) {
                                        _contentBlocks[idx] = block.copyWith(imagePaths: ['']);
                                      }
                                    });
                                    _markUnsaved();
                                  },
                                  icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                                  label: const Text(
                                    'Удалить',
                                    style: TextStyle(fontSize: 12, color: Colors.red),
                                  ),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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

  Widget _buildVideoBlockWidget(VideoContentBlock block, int index) {
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
            title: 'Видео',
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
                  TextFormField(
                    initialValue: block.url,
                    decoration: const InputDecoration(
                      labelText: 'URL видео',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _contentBlocks[index] = block.copyWith(url: value);
                      });
                      _markUnsaved();
                    },
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<VideoProviderType>(
                    initialValue: block.provider,
                    decoration: const InputDecoration(
                      labelText: 'Платформа',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: VideoProviderType.youtube,
                        child: Text('YouTube'),
                      ),
                      DropdownMenuItem(
                        value: VideoProviderType.rutube,
                        child: Text('RuTube'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _contentBlocks[index] =
                              block.copyWith(provider: value);
                        });
                        _markUnsaved();
                      }
                    },
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
            title: 'Аудио',
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
                              const Icon(Icons.audiotrack, size: 20, color: Colors.orange),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  selectedAudioFile.path.split('/').last,
                                  style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const Icon(Icons.check_circle, color: Colors.green, size: 18),
                            ],
                          ),
                          const SizedBox(height: 8),
                        ] else if (block.audioPath?.isNotEmpty ?? false) ...[
                          Row(
                            children: [
                              const Icon(Icons.audiotrack, size: 20, color: Colors.orange),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  block.audioPath!.split('/').last,
                                  style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const Icon(Icons.check_circle, color: Colors.green, size: 18),
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
                                selectedAudioFile != null || (block.audioPath?.isNotEmpty ?? false)
                                    ? 'Заменить'
                                    : 'Выбрать файл',
                                style: const TextStyle(fontSize: 12),
                              ),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                            if (selectedAudioFile != null || (block.audioPath?.isNotEmpty ?? false)) ...[
                              const SizedBox(width: 8),
                              TextButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _selectedBlockAudioFiles.remove(block.id);
                                    final idx = _contentBlocks.indexWhere((b) => b.id == block.id);
                                    if (idx != -1) {
                                      _contentBlocks[idx] = block.copyWith(audioPath: '');
                                    }
                                  });
                                  _markUnsaved();
                                },
                                icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                                label: const Text('Удалить', style: TextStyle(fontSize: 12, color: Colors.red)),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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