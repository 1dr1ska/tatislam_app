import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import 'package:tatislam_app/core/services/media_optimization_service.dart';
import 'package:tatislam_app/core/services/models/image_optimization_result.dart';
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
  uploadingCover,
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
  final _coverImageController = TextEditingController();
  final _dateController = TextEditingController();
  final _uuid = const Uuid();

  late Future<PublicationDetail?> _publicationFuture;
  late Future<List<Section>> _sectionsFuture;

  String _selectedCoverImagePath = '';
  File? _selectedCoverImageFile;
  List<ContentBlock> _contentBlocks = [];
  Set<String> _selectedSectionIds = {};
  String _status = 'draft';
  DateTime? _publishedAt;

  // Map to store selected image files for each content block
  final Map<String, File> _selectedBlockImageFiles = {};

  // Map to store optimization results for each content block image
  final Map<String, ImageOptimizationResult> _blockImageOptimizationResults =
      {};

  // Optimization result for the cover image
  ImageOptimizationResult? _coverImageOptimizationResult;

  // Map to store selected audio files for each content block
  final Map<String, File> _selectedBlockAudioFiles = {};

  bool _isProcessing = false;
  bool _isSaving = false;

  final MediaOptimizationService _optimizationService =
      const MediaOptimizationService();

  _SaveStep _currentSaveStep = _SaveStep.idle;
  int _uploadedFileCount = 0;
  int _totalFileCount = 0;
  Timer? _autoSaveTimer;

  @override
  void initState() {
    super.initState();
    _sectionsFuture = _loadSections();
    if (widget.publicationId != null) {
      _publicationFuture = _loadPublication(widget.publicationId!);
    } else {
      _publicationFuture = Future.value(null);
    }
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _titleController.dispose();
    _coverImageController.dispose();
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

      // Fill form fields with publication data
      _titleController.text = detail.publication.title;
      _selectedCoverImagePath = detail.publication.coverImagePath;
      _contentBlocks = List.from(detail.blocks);
      _selectedSectionIds = Set.from(detail.sectionIds);
      _status = detail.publication.status ?? 'draft';
      _publishedAt = detail.publication.publishedAt;
      _dateController.text = _formatDate(_publishedAt!);

      setState(() {});

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

  Future<void> _pickCoverImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _isProcessing = true;
      });

      try {
        final bytes = await pickedFile.readAsBytes();
        final result = await _optimizationService.optimizeImage(
          originalBytes: bytes,
          originalFileName: pickedFile.name,
        );

        setState(() {
          _selectedCoverImageFile = File(pickedFile.path);
          _coverImageOptimizationResult = result;
          _coverImageController.text = result.fileName;
        });
      } catch (e) {
        // Если оптимизация не удалась — используем исходный файл
        setState(() {
          _selectedCoverImageFile = File(pickedFile.path);
          _coverImageOptimizationResult = null;
          _coverImageController.text = pickedFile.path.split('/').last;
        });
      } finally {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _pickBlockImage(String blockId) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _isProcessing = true;
      });

      try {
        final bytes = await pickedFile.readAsBytes();
        final result = await _optimizationService.optimizeImage(
          originalBytes: bytes,
          originalFileName: pickedFile.name,
        );

        setState(() {
          _selectedBlockImageFiles[blockId] = File(pickedFile.path);
          _blockImageOptimizationResults[blockId] = result;
        });
      } catch (e) {
        // Если оптимизация не удалась — используем исходный файл
        setState(() {
          _selectedBlockImageFiles[blockId] = File(pickedFile.path);
          _blockImageOptimizationResults.remove(blockId);
        });
      } finally {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _pickBlockAudio(String blockId) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickMedia();

    if (pickedFile != null) {
      setState(() {
        _selectedBlockAudioFiles[blockId] = File(pickedFile.path);
      });
      _scheduleAutoSave();
    }
  }

  Future<String> _uploadCoverImage() async {
    if (_selectedCoverImageFile == null) {
      return _selectedCoverImagePath;
    }

    try {
      final storageRepository = ref.read(mediaStorageRepositoryProvider);

      // Use optimized bytes if available, otherwise read from file
      final Uint8List bytes;
      final String extension;

      if (_coverImageOptimizationResult != null) {
        bytes = _coverImageOptimizationResult!.bytes;
        extension = _coverImageOptimizationResult!.fileName.split('.').last;
      } else {
        bytes = await _selectedCoverImageFile!.readAsBytes();
        extension = _selectedCoverImageFile!.path.split('.').last;
      }

      final path = StoragePaths.cover(_uuid.v4(), extension);
      await storageRepository.upload(path, bytes);

      // Delete old cover image if it exists and is different
      if (_selectedCoverImagePath.isNotEmpty &&
          _selectedCoverImagePath != path) {
        try {
          await storageRepository.delete([_selectedCoverImagePath]);
        } catch (e) {
          // Ignore delete errors
        }
      }

      return path;
    } catch (e) {
      throw Exception('Ошибка загрузки обложки: $e');
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

      // Use optimized bytes if available, otherwise read from file
      final Uint8List bytes;
      final String extension;

      final optimizationResult = _blockImageOptimizationResults[blockId];
      if (optimizationResult != null) {
        bytes = optimizationResult.bytes;
        extension = optimizationResult.fileName.split('.').last;
      } else {
        bytes = await selectedImageFile.readAsBytes();
        extension = selectedImageFile.path.split('.').last;
      }

      final path = StoragePaths.blockImage(
          widget.publicationId ?? _uuid.v4(), extension,
          blockId: blockId);

      await storageRepository.upload(path, bytes);

      // Delete old image if it exists and is different
      if (currentImagePath.isNotEmpty && currentImagePath != path) {
        try {
          await storageRepository.delete([currentImagePath]);
        } catch (e) {
          // Ignore delete errors
        }
      }

      return path;
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
      await storageRepository.upload(path, bytes);

      // Delete old audio file if it exists and is different
      if (currentAudioPath.isNotEmpty && currentAudioPath != path) {
        try {
          await storageRepository.delete([currentAudioPath]);
        } catch (e) {
          // Ignore delete errors
        }
      }

      return path;
    } catch (e) {
      throw Exception('Ошибка загрузки аудио: $e');
    }
  }

  Future<List<ContentBlock>> _updateBlocksWithImagePaths(
      String publicationId) async {
    final updatedBlocks = <ContentBlock>[];

    // Count total files that need uploading
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
        // Upload image for this block
        final imagePath =
            await _uploadBlockImage(block.id, block.imagePath);

        // Create updated block with new image path
        final updatedBlock = block.copyWith(imagePaths: [imagePath]);
        updatedBlocks.add(updatedBlock);
        _uploadedFileCount++;
        _updateSaveStep();
      } else if (block is AudioContentBlock) {
        // Upload audio file for this block
        final audioPath =
            await _uploadBlockAudio(block.id, block.audioPath ?? '');

        // Create updated block with new audio path
        final updatedBlock = block.copyWith(audioPath: audioPath);
        updatedBlocks.add(updatedBlock);
        _uploadedFileCount++;
        _updateSaveStep();
      } else {
        // For other blocks, just add them as is
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
      case _SaveStep.uploadingCover:
        return 'Загрузка обложки...';
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

  /// Schedules a debounced auto-save. Cancels any pending auto-save first.
  void _scheduleAutoSave() {
    // Only auto-save if we have a publication ID (editing existing)
    if (widget.publicationId == null) return;

    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(seconds: 3), _autoSave);
  }

  Future<void> _savePublication() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
      _currentSaveStep = _SaveStep.uploadingCover;
    });

    try {
      final title = _titleController.text.trim();

      // Upload cover image
      final coverImagePath = await _uploadCoverImage();

      setState(() {
        _currentSaveStep = _SaveStep.savingMetadata;
      });

      final repository = ref.read(publicationRepositoryProvider);

      if (widget.publicationId == null) {
        // Create new publication
        final publication = await repository.createPublication(
          title: title,
          description: '',
          coverImagePath: coverImagePath,
          type: 'article',
          publishedAt: DateTime.now(),
          status: _status,
        );

        setState(() {
          _currentSaveStep = _SaveStep.uploadingFiles;
        });

        // Update content blocks with uploaded image paths
        final updatedBlocks =
            await _updateBlocksWithImagePaths(publication.id);

        setState(() {
          _currentSaveStep = _SaveStep.savingSections;
        });

        // Save section associations
        await repository.setSections(
            publication.id, _selectedSectionIds.toList());

        setState(() {
          _currentSaveStep = _SaveStep.savingBlocks;
        });

        // Save content blocks
        await repository.replaceBlocks(publication.id, updatedBlocks);

        setState(() {
          _currentSaveStep = _SaveStep.done;
        });

        if (mounted) {
          final messenger = ScaffoldMessenger.of(context);
          final navigator = Navigator.of(context);
          // Show success briefly before closing
          await Future.delayed(const Duration(milliseconds: 500));
          messenger.showSnackBar(
            const SnackBar(content: Text('Публикация создана')),
          );
          ref.invalidate(publicationRepositoryProvider);
          if (mounted) navigator.pop(true);
        }
      } else {
        // Update existing publication
        final publication = await repository.updatePublication(
          id: widget.publicationId!,
          title: title,
          description: '',
          coverImagePath: coverImagePath,
          publishedAt: _publishedAt ?? DateTime.now(),
          type: 'article',
          status: _status,
        );

        setState(() {
          _currentSaveStep = _SaveStep.uploadingFiles;
        });

        // Update content blocks with uploaded image paths
        final updatedBlocks =
            await _updateBlocksWithImagePaths(publication.id);

        setState(() {
          _currentSaveStep = _SaveStep.savingSections;
        });

        // Save section associations
        await repository.setSections(
            widget.publicationId!, _selectedSectionIds.toList());

        setState(() {
          _currentSaveStep = _SaveStep.savingBlocks;
        });

        // Save content blocks
        await repository.replaceBlocks(
            widget.publicationId!, updatedBlocks);

        setState(() {
          _currentSaveStep = _SaveStep.done;
        });

        if (mounted) {
          final messenger = ScaffoldMessenger.of(context);
          final navigator = Navigator.of(context);
          await Future.delayed(const Duration(milliseconds: 500));
          messenger.showSnackBar(
            const SnackBar(content: Text('Публикация обновлена')),
          );
          ref.invalidate(publicationRepositoryProvider);
          if (mounted) navigator.pop(true);
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
        // Reset step after a delay so the user can see the final state
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

  Future<void> _autoSave() async {
    // Don't auto-save if we're already saving manually
    if (_isSaving) return;

    setState(() {
      _isSaving = true;
      _currentSaveStep = _SaveStep.uploadingCover;
    });

    try {
      final title = _titleController.text.trim();

      // Upload cover image
      final coverImagePath = await _uploadCoverImage();

      setState(() {
        _currentSaveStep = _SaveStep.savingMetadata;
      });

      final repository = ref.read(publicationRepositoryProvider);

      // Update existing publication
      final publication = await repository.updatePublication(
        id: widget.publicationId!,
        title: title,
        description: '',
        coverImagePath: coverImagePath,
        publishedAt: _publishedAt ?? DateTime.now(),
        type: 'article',
        status: _status,
      );

      setState(() {
        _currentSaveStep = _SaveStep.uploadingFiles;
      });

      // Update content blocks with uploaded image paths
      final updatedBlocks =
          await _updateBlocksWithImagePaths(publication.id);

      setState(() {
        _currentSaveStep = _SaveStep.savingSections;
      });

      // Save section associations
      await repository.setSections(
          widget.publicationId!, _selectedSectionIds.toList());

      setState(() {
        _currentSaveStep = _SaveStep.savingBlocks;
      });

      // Save content blocks
      await repository.replaceBlocks(
          widget.publicationId!, updatedBlocks);

      setState(() {
        _currentSaveStep = _SaveStep.done;
      });

      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        // Show auto-save indicator briefly
        await Future.delayed(const Duration(seconds: 1));
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Автосохранение выполнено'),
            duration: Duration(seconds: 1),
          ),
        );
        ref.invalidate(publicationRepositoryProvider);
      }
    } catch (e) {
      // Don't show error for auto-save, just log it
      debugPrint('Auto-save error: $e');
      setState(() {
        _currentSaveStep = _SaveStep.error;
      });
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
      _scheduleAutoSave();
    }
  }

  void _moveBlockDown(int index) {
    if (index < _contentBlocks.length - 1) {
      setState(() {
        final block = _contentBlocks.removeAt(index);
        _contentBlocks.insert(index + 1, block);
        _updateOrderIndices();
      });
      _scheduleAutoSave();
    }
  }

  void _removeBlock(int index) {
    setState(() {
      _contentBlocks.removeAt(index);
    });
    _scheduleAutoSave();
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
        });
        _scheduleAutoSave();
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

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/admin'),
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
            // Save progress indicator
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
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Metadata Card
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Метаданные',
                                    style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 16),
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
                                      _scheduleAutoSave();
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextFormField(
                                          controller: _coverImageController,
                                          decoration: const InputDecoration(
                                            labelText: 'Обложка',
                                            border: OutlineInputBorder(),
                                          ),
                                          readOnly: true,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      ElevatedButton(
                                        onPressed: _pickCoverImage,
                                        child: const Text('Выбрать'),
                                      ),
                                    ],
                                  ),
                                  if (_selectedCoverImagePath.isNotEmpty ||
                                      _selectedCoverImageFile != null) ...[
                                    const SizedBox(height: 16),
                                    Container(
                                      height: 200,
                                      decoration: BoxDecoration(
                                        border: Border.all(color: Colors.grey),
                                      ),
                                      child: _selectedCoverImageFile != null
                                          ? Image.file(
                                              _selectedCoverImageFile!,
                                              fit: BoxFit.contain)
                                          : Image.network(
                                              ref
                                                  .read(
                                                      mediaStorageRepositoryProvider)
                                                  .publicUrlFor(
                                                      _selectedCoverImagePath),
                                              fit: BoxFit.contain,
                                              errorBuilder: (context, error,
                                                      stackTrace) =>
                                                  const Icon(
                                                      Icons.broken_image),
                                            ),
                                    ),
                                  ],
                                  const SizedBox(height: 16),
                                  FutureBuilder<List<Section>>(
                                    future: _sectionsFuture,
                                    builder: (context, snapshot) {
                                      if (snapshot.connectionState ==
                                          ConnectionState.waiting) {
                                        return const CircularProgressIndicator();
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
                                      return Wrap(
                                        spacing: 8.0,
                                        runSpacing: 8.0,
                                        children: sections.map((section) {
                                          return FilterChip(
                                            label: Text(section.name),
                                            selected: _selectedSectionIds
                                                .contains(section.id),
                                            onSelected: (selected) {
                                              setState(() {
                                                if (selected) {
                                                  _selectedSectionIds
                                                      .add(section.id);
                                                } else {
                                                  _selectedSectionIds
                                                      .remove(section.id);
                                                }
                                              });
                                              _scheduleAutoSave();
                                            },
                                          );
                                        }).toList(),
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 16),
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
                                      DropdownMenuItem(
                                          value: 'archived',
                                          child: Text('Архив')),
                                    ],
                                    onChanged: (value) {
                                      if (value != null) {
                                        setState(() {
                                          _status = value;
                                        });
                                        _scheduleAutoSave();
                                      }
                                    },
                                  ),
                                  const SizedBox(height: 16),
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
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Content Blocks
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Блоки контента',
                                    style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 16),
                                  // Add block buttons
                                  Wrap(
                                    spacing: 8.0,
                                    runSpacing: 8.0,
                                    children: [
                                      ElevatedButton.icon(
                                        onPressed: () {
                                          setState(() {
                                            _contentBlocks.add(
                                                TextContentBlock(
                                              id: _uuid.v4(),
                                              publicationId:
                                                  widget.publicationId ?? '',
                                              orderIndex:
                                                  _contentBlocks.length,
                                              text: '',
                                            ));
                                          });
                                          _scheduleAutoSave();
                                        },
                                        icon: const Icon(Icons.text_fields),
                                        label: const Text('Текст'),
                                      ),
                                      ElevatedButton.icon(
                                        onPressed: () {
                                          setState(() {
                                            _contentBlocks.add(
                                                ImageContentBlock.single(
                                              id: _uuid.v4(),
                                              publicationId:
                                                  widget.publicationId ?? '',
                                              orderIndex:
                                                  _contentBlocks.length,
                                              imagePath: '',
                                              caption: '',
                                            ));
                                          });
                                          _scheduleAutoSave();
                                        },
                                        icon: const Icon(Icons.image),
                                        label: const Text('Изображение'),
                                      ),
                                      ElevatedButton.icon(
                                        onPressed: () {
                                          setState(() {
                                            _contentBlocks.add(
                                                VideoContentBlock(
                                              id: _uuid.v4(),
                                              publicationId:
                                                  widget.publicationId ?? '',
                                              orderIndex:
                                                  _contentBlocks.length,
                                              url: '',
                                              provider:
                                                  VideoProviderType.rutube,
                                              caption: '',
                                            ));
                                          });
                                          _scheduleAutoSave();
                                        },
                                        icon: const Icon(Icons.video_library),
                                        label: const Text('Видео'),
                                      ),
                                      ElevatedButton.icon(
                                        onPressed: () {
                                          setState(() {
                                            _contentBlocks.add(
                                                AudioContentBlock(
                                              id: _uuid.v4(),
                                              publicationId:
                                                  widget.publicationId ?? '',
                                              orderIndex:
                                                  _contentBlocks.length,
                                              source: AudioSourceType.upload,
                                              audioPath: '',
                                              caption: '',
                                            ));
                                          });
                                          _scheduleAutoSave();
                                        },
                                        icon: const Icon(Icons.audiotrack),
                                        label: const Text('Аудио'),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  // Content blocks list
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
                                ],
                              ),
                            ),
                          ),
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

  Widget _buildTextBlockWidget(TextContentBlock block, int index) {
    return Card(
      key: Key(block.id),
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Column(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_upward),
                      onPressed:
                          index > 0 ? () => _moveBlockUp(index) : null,
                    ),
                    IconButton(
                      icon: const Icon(Icons.arrow_downward),
                      onPressed: index < _contentBlocks.length - 1
                          ? () => _moveBlockDown(index)
                          : null,
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                const Text('Текстовый блок',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () => _removeBlock(index),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              initialValue: block.text,
              decoration: const InputDecoration(
                labelText: 'Текст',
                border: OutlineInputBorder(),
              ),
              maxLines: 5,
              onChanged: (value) {
                setState(() {
                  _contentBlocks[index] = block.copyWith(text: value);
                });
                _scheduleAutoSave();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageBlockWidget(ImageContentBlock block, int index) {
    // Get the selected image file for this block if it exists
    final selectedImageFile = _selectedBlockImageFiles[block.id];
    final optimizationResult = _blockImageOptimizationResults[block.id];

    return Card(
      key: Key(block.id),
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Column(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_upward),
                      onPressed:
                          index > 0 ? () => _moveBlockUp(index) : null,
                    ),
                    IconButton(
                      icon: const Icon(Icons.arrow_downward),
                      onPressed: index < _contentBlocks.length - 1
                          ? () => _moveBlockDown(index)
                          : null,
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                const Text('Изображение',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () => _removeBlock(index),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'Изображение',
                      border: OutlineInputBorder(),
                    ),
                    controller: TextEditingController(
                      text: selectedImageFile != null
                          ? (optimizationResult?.fileName ??
                              selectedImageFile.path.split('/').last)
                          : block.imagePath.split('/').last,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _isProcessing ? null : () => _pickBlockImage(block.id),
                  child: const Text('Выбрать'),
                ),
              ],
            ),
            if (_isProcessing && selectedImageFile != null) ...[
              const SizedBox(height: 16),
              const Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 12),
                    Text('Оптимизация...'),
                  ],
                ),
              ),
            ],
            if (optimizationResult != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Изображение',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'до обработки: ${_formatBytes(optimizationResult.originalSize)}',
                      style: const TextStyle(fontSize: 13),
                    ),
                    Text(
                      'после обработки: ${_formatBytes(optimizationResult.finalSize)}',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
            if (selectedImageFile != null) ...[
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                ),
                child: AspectRatio(
                  aspectRatio: 3 / 2,
                  child: Image.file(
                    selectedImageFile,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) =>
                        const Icon(Icons.broken_image),
                  ),
                ),
              ),
            ] else if (block.imagePath.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                ),
                child: AspectRatio(
                  aspectRatio: 3 / 2,
                  child: Image.network(
                    ref
                        .read(mediaStorageRepositoryProvider)
                        .publicUrlFor(block.imagePath),
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) =>
                        const Icon(Icons.broken_image),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            TextFormField(
              initialValue: block.caption,
              decoration: const InputDecoration(
                labelText: 'Подпись',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  _contentBlocks[index] = block.copyWith(captions: [value]);
                });
                _scheduleAutoSave();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoBlockWidget(VideoContentBlock block, int index) {
    return Card(
      key: Key(block.id),
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Column(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_upward),
                      onPressed:
                          index > 0 ? () => _moveBlockUp(index) : null,
                    ),
                    IconButton(
                      icon: const Icon(Icons.arrow_downward),
                      onPressed: index < _contentBlocks.length - 1
                          ? () => _moveBlockDown(index)
                          : null,
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                const Text('Видео',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () => _removeBlock(index),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              initialValue: block.url,
              decoration: const InputDecoration(
                labelText: 'URL видео',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  _contentBlocks[index] = block.copyWith(url: value);
                });
                _scheduleAutoSave();
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<VideoProviderType>(
              initialValue: block.provider,
              decoration: const InputDecoration(
                labelText: 'Платформа',
                border: OutlineInputBorder(),
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
                  _scheduleAutoSave();
                }
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              initialValue: block.caption,
              decoration: const InputDecoration(
                labelText: 'Подпись',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  _contentBlocks[index] = block.copyWith(caption: value);
                });
                _scheduleAutoSave();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAudioBlockWidget(AudioContentBlock block, int index) {
    // Get the selected audio file for this block if it exists
    final selectedAudioFile = _selectedBlockAudioFiles[block.id];

    return Card(
      key: Key(block.id),
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Column(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_upward),
                      onPressed:
                          index > 0 ? () => _moveBlockUp(index) : null,
                    ),
                    IconButton(
                      icon: const Icon(Icons.arrow_downward),
                      onPressed: index < _contentBlocks.length - 1
                          ? () => _moveBlockDown(index)
                          : null,
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                const Text('Аудио',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () => _removeBlock(index),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Only show the upload option (remove external URL option)
            const Text('Загрузить файл',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'Аудио файл',
                      border: OutlineInputBorder(),
                    ),
                    controller: TextEditingController(
                      text: selectedAudioFile != null
                          ? selectedAudioFile.path.split('/').last
                          : (block.audioPath?.split('/').last ?? ''),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: () => _pickBlockAudio(block.id),
                  child: const Text('Выбрать'),
                ),
              ],
            ),
            if (selectedAudioFile != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.audiotrack, size: 24),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        selectedAudioFile.path.split('/').last,
                        style:
                            const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const Icon(Icons.check, color: Colors.green),
                  ],
                ),
              ),
            ] else if (block.audioPath?.isNotEmpty ?? false) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.audiotrack, size: 24),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        block.audioPath!.split('/').last,
                        style:
                            const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const Icon(Icons.check, color: Colors.green),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            TextFormField(
              initialValue: block.caption,
              decoration: const InputDecoration(
                labelText: 'Подпись',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  _contentBlocks[index] = block.copyWith(caption: value);
                });
                _scheduleAutoSave();
              },
            ),
          ],
        ),
      ),
    );
  }

  String _formatBytes(int bytes) {
    const mb = 1024 * 1024;
    final value = bytes / mb;
    return '${value.toStringAsFixed(1)} MB';
  }
}