import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import 'package:tatislam_app/core/constants/app_colors.dart';
import 'package:tatislam_app/core/constants/app_localizations.dart' as loc;
import 'package:tatislam_app/core/storage/storage_providers.dart';
import 'package:tatislam_app/features/admin/queue/publication_save_payload.dart';
import 'package:tatislam_app/features/admin/queue/queue_providers.dart';
import 'package:tatislam_app/features/publications/data/publication_providers.dart';
import 'package:tatislam_app/features/publications/domain/entities/publication_detail.dart';
import 'package:tatislam_app/features/sections/data/section_providers.dart';
import 'package:tatislam_app/features/sections/domain/entities/section.dart';

/// Holds a selected photo's raw bytes and original name, independently of
/// `dart:io` — works on both Android and Web.
class _SelectedPhoto {
  final Uint8List bytes;
  final String name;

  const _SelectedPhoto({required this.bytes, required this.name});
}

/// Editor for `photo` type publications.
///
/// A photo publication is a full-bleed rectangle in the home grid that shows a
/// single image (in its original aspect ratio). This screen lets the admin
/// pick/replace that image and choose the primary + additional sections.
class PhotoPublicationEditorScreen extends ConsumerStatefulWidget {
  final String? publicationId;

  const PhotoPublicationEditorScreen({super.key, this.publicationId});

  @override
  ConsumerState<PhotoPublicationEditorScreen> createState() =>
      _PhotoPublicationEditorScreenState();
}

class _PhotoPublicationEditorScreenState
    extends ConsumerState<PhotoPublicationEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _dateController = TextEditingController();

  late Future<PublicationDetail?> _publicationFuture;
  late Future<List<Section>> _sectionsFuture;

  String? _primarySectionId;
  final Set<String> _selectedSectionIds = {};
  bool _hasAdditionalSections = false;
  String _status = 'published';
  DateTime? _publishedAt;
  String? _existingPhotoPath;
  _SelectedPhoto? _pickedPhoto;

  bool _hasUnsavedChanges = false;
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
    final sections = await repository.getSections(includeHidden: true);

    // For a brand-new photo publication, preselect the admin-chosen default
    // section (if any) so the primary section doesn't have to be picked every
    // time. Editing an existing publication keeps its saved primary section.
    if (widget.publicationId == null && _primarySectionId == null) {
      final defaultSection = sections
          .where((s) => s.isDefaultForPhoto)
          .firstOrNull;
      if (defaultSection != null) {
        _primarySectionId = defaultSection.id;
        _selectedSectionIds.add(defaultSection.id);
      }
    }

    return sections;
  }

  Future<PublicationDetail?> _loadPublication(String id) async {
    try {
      final repository = ref.read(publicationRepositoryProvider);
      final detail = await repository.getPublicationDetail(id);

      _titleController.text = detail.publication.title;
      _primarySectionId = detail.publication.primarySectionId;
      for (final sectionId in detail.sectionIds) {
        _selectedSectionIds.add(sectionId);
      }
      _hasAdditionalSections = detail.publication.hasAdditionalSections;
      _status = detail.publication.status ?? 'published';
      _publishedAt = detail.publication.publishedAt;
      _existingPhotoPath = detail.publication.photoPath;
      _dateController.text = _formatDate(_publishedAt!);
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

  Future<void> _pickPhoto() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 95,
      );

      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        final name = pickedFile.name;
        setState(() {
          _pickedPhoto = _SelectedPhoto(bytes: bytes, name: name);
          if (_titleController.text.trim().isEmpty) {
            _titleController.text = _stripExtension(name);
          }
          _hasUnsavedChanges = true;
        });
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

  String _stripExtension(String fileName) {
    final dotIndex = fileName.lastIndexOf('.');
    if (dotIndex > 0) {
      return fileName.substring(0, dotIndex);
    }
    return fileName;
  }

  /// Validates the form, snapshots it into a [PublicationSavePayload] and puts
  /// it into the background upload queue. The editor closes immediately; the
  /// publication is saved and uploaded by the queue in the background.
  Future<void> _savePublication() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Primary section is required.
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

    // A photo is required for new publications.
    final hasExistingPhoto = _existingPhotoPath?.isNotEmpty ?? false;
    if (_pickedPhoto == null && !hasExistingPhoto) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.AppLocalizations.admin.selectPhotoRequired)),
      );
      return;
    }

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

  /// Snapshots the current form state (including picked photo bytes) into an
  /// immutable [PublicationSavePayload] for the background queue.
  PublicationSavePayload _buildSavePayload() {
    final rawTitle = _titleController.text.trim();
    final title = rawTitle.isEmpty
        ? (_pickedPhoto != null ? _stripExtension(_pickedPhoto!.name) : 'Фото')
        : rawTitle;
    return PublicationSavePayload(
      publicationId: widget.publicationId,
      isPhoto: true,
      title: title,
      type: 'photo',
      publishedAt: _publishedAt ?? DateTime.now(),
      status: _status,
      primarySectionId: _primarySectionId ?? '',
      hasAdditionalSections: _hasAdditionalSections,
      sectionIds: _sectionIdsToSave(),
      newPhoto: _pickedPhoto == null
          ? null
          : SelectedMediaFile(
              bytes: _pickedPhoto!.bytes,
              name: _pickedPhoto!.name,
            ),
      existingPhotoPath: _existingPhotoPath,
    );
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

  /// Shows exit confirmation dialog if there are unsaved changes.
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
      return false;
    } else if (result == 'discard') {
      return true;
    }
    return false;
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
                ? loc.AppLocalizations.admin.newPhotoTitle
                : loc.AppLocalizations.admin.editPhotoTitle,
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _savePublication,
            ),
          ],
          bottom: _buildStatusBar(),
        ),
        body: FutureBuilder<PublicationDetail?>(
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
                    _buildSectionCard(
                      title: loc.AppLocalizations.admin.photoField,
                      icon: Icons.photo,
                      child: _buildPhotoPicker(),
                    ),
                    const SizedBox(height: 12),
                    _buildSectionCard(
                      title: loc.AppLocalizations.admin.metadata,
                      icon: Icons.info_outline,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextFormField(
                            controller: _titleController,
                            decoration: InputDecoration(
                              labelText: loc.AppLocalizations.admin.titleField,
                              hintText:
                                  loc.AppLocalizations.admin.photoTitleOptional,
                              border: const OutlineInputBorder(),
                            ),
                            onChanged: (value) {
                              _markUnsaved();
                            },
                          ),
                          const SizedBox(height: 12),
                          _buildPrimarySectionSelector(),
                          const SizedBox(height: 12),
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
                            _buildAdditionalSectionsSelector(),
                          ],
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

  Widget _buildPhotoPicker() {
    final hasLocal = _pickedPhoto != null;
    final hasRemote = !hasLocal && (_existingPhotoPath?.isNotEmpty ?? false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              if (hasLocal)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      constraints: const BoxConstraints(maxHeight: 320),
                      width: double.infinity,
                      color: Colors.grey.shade100,
                      child: Image.memory(
                        _pickedPhoto!.bytes,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) =>
                            const Center(
                              child: Icon(Icons.broken_image, size: 32),
                            ),
                      ),
                    ),
                  ),
                )
              else if (hasRemote)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      constraints: const BoxConstraints(maxHeight: 320),
                      width: double.infinity,
                      color: Colors.grey.shade100,
                      child: Image.network(
                        ref
                            .read(mediaStorageRepositoryProvider)
                            .publicUrlFor(_existingPhotoPath!),
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) =>
                            const Center(
                              child: Icon(Icons.broken_image, size: 32),
                            ),
                      ),
                    ),
                  ),
                )
              else
                const SizedBox(
                  height: 160,
                  child: Center(
                    child: Icon(
                      Icons.add_photo_alternate_outlined,
                      size: 48,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _pickPhoto,
                style: ElevatedButton.styleFrom(elevation: 0),
                child: Text(
                  hasLocal || hasRemote
                      ? loc.AppLocalizations.admin.replacePhoto
                      : loc.AppLocalizations.admin.selectPhoto,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPrimarySectionSelector() {
    return FutureBuilder<List<Section>>(
      future: _sectionsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: LinearProgressIndicator(),
          );
        }
        if (snapshot.hasError) {
          return Text(
            loc.AppLocalizations.admin.sectionLoadError('${snapshot.error}'),
          );
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Text(loc.AppLocalizations.admin.noSectionsAvailable);
        }
        final sections = snapshot.data!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              loc.AppLocalizations.admin.primarySection,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
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
                    _sectionValidationAttempted = false;
                  });
                  _markUnsaved();
                },
                contentPadding: EdgeInsets.zero,
                dense: true,
                visualDensity: VisualDensity.compact,
              );
            }),
            if (_sectionValidationAttempted &&
                (_primarySectionId == null || _primarySectionId!.isEmpty)) ...[
              const SizedBox(height: 4),
              Text(
                loc.AppLocalizations.admin.selectPrimarySection,
                style: TextStyle(fontSize: 12, color: Colors.red[700]),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildAdditionalSectionsSelector() {
    return FutureBuilder<List<Section>>(
      future: _sectionsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: LinearProgressIndicator(),
          );
        }
        if (snapshot.hasError) {
          return Text(
            loc.AppLocalizations.admin.sectionLoadError('${snapshot.error}'),
          );
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Text(loc.AppLocalizations.admin.noSectionsAvailable);
        }
        final sections = snapshot.data!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              loc.AppLocalizations.admin.additionalSections,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6.0,
              runSpacing: 6.0,
              children: sections.map((section) {
                final isPrimary = section.id == _primarySectionId;
                return FilterChip(
                  label: Text(
                    section.name,
                    style: const TextStyle(fontSize: 12),
                  ),
                  selected: _selectedSectionIds.contains(section.id),
                  onSelected: isPrimary
                      ? null
                      : (selected) {
                          setState(() {
                            if (selected) {
                              _selectedSectionIds.add(section.id);
                            } else {
                              _selectedSectionIds.remove(section.id);
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
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      clipBehavior: Clip.antiAlias,
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
}
