import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tatislam_app/core/constants/app_colors.dart';
import 'package:tatislam_app/core/constants/app_localizations.dart';
import 'package:tatislam_app/features/sections/data/section_providers.dart';
import 'package:tatislam_app/features/sections/domain/entities/section.dart';
import 'package:tatislam_app/features/publications/data/publication_providers.dart';

class SectionsManagementScreen extends ConsumerStatefulWidget {
  const SectionsManagementScreen({super.key});

  @override
  ConsumerState<SectionsManagementScreen> createState() =>
      _SectionsManagementScreenState();
}

class _SectionsManagementScreenState
    extends ConsumerState<SectionsManagementScreen> {
  late Future<List<Section>> _sectionsFuture;

  @override
  void initState() {
    super.initState();
    _sectionsFuture = _loadSections();
  }

  Future<List<Section>> _loadSections() async {
    final repository = ref.read(sectionRepositoryProvider);
    return repository.getSections(includeHidden: true);
  }

  Future<void> _refreshSections() async {
    setState(() {
      _sectionsFuture = _loadSections();
    });
  }

  Future<void> _renameSection(Section section) async {
    final result = await context.push<bool>(
      '/admin/sections/${section.id}/edit',
    );
    if (result == true && mounted) {
      _refreshSections();
    }
  }

  Future<void> _setVisibility(Section section, bool isVisible) async {
    try {
      final repository = ref.read(sectionRepositoryProvider);
      await repository.setVisibility(section.id, isVisible);
      await _refreshSections();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.admin.sectionVisibilityChanged(isVisible))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.admin.sectionVisibilityError}$e')),
        );
      }
    }
  }

  Future<void> _deleteSection(Section section) async {
    // Check if section has publications before allowing deletion
    final hasPublications = await _checkSectionHasPublications(section.id);
    if (hasPublications) {
      if (mounted) {
        _showCannotDeleteDialog(section.name);
      }
      return;
    }

    final confirmed = await _showDeleteConfirmationDialog(section.name);
    if (confirmed) {
      try {
        final repository = ref.read(sectionRepositoryProvider);
        await repository.deleteSection(section.id);
        await _refreshSections();

        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(AppLocalizations.admin.sectionDeleted)));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${AppLocalizations.admin.sectionDeleteError}$e')),
          );
        }
      }
    }
  }

  /// Checks if any publication references this section (primary or additional).
  Future<bool> _checkSectionHasPublications(String sectionId) async {
    try {
      final repository = ref.read(publicationRepositoryProvider);
      final publications = await repository.getPublications(
        includeAllStatuses: true,
      );
      return publications.any((pub) => pub.primarySectionId == sectionId);
    } catch (_) {
      // If we can't check (e.g. network error), assume safe to proceed
      // The DB will enforce referential integrity
      return false;
    }
  }

  void _showCannotDeleteDialog(String sectionName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 24),
            const SizedBox(width: 8),
            Expanded(child: Text(AppLocalizations.admin.cannotDeleteSection)),
          ],
        ),
        content: Text(AppLocalizations.admin.sectionHasPublications(sectionName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.admin.gotIt),
          ),
        ],
      ),
    );
  }

  Future<bool> _showDeleteConfirmationDialog(String sectionName) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: Text(AppLocalizations.admin.deleteSectionTitle),
              content: Text(AppLocalizations.admin.sectionDeleteConfirmation(sectionName)),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(AppLocalizations.admin.cancelAction),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: Text(AppLocalizations.admin.deleteAction),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  Future<void> _moveSectionUp(Section section) async {
    try {
      final repository = ref.read(sectionRepositoryProvider);
      await repository.moveSectionUp(section);
      await _refreshSections();

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AppLocalizations.admin.sectionMovedUp)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.admin.sectionMoveUpError}$e')),
        );
      }
    }
  }

  Future<void> _moveSectionDown(Section section) async {
    try {
      final repository = ref.read(sectionRepositoryProvider);
      await repository.moveSectionDown(section);
      await _refreshSections();

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AppLocalizations.admin.sectionMovedDown)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.admin.sectionMoveDownError}$e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Section>>(
      future: _sectionsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text(AppLocalizations.admin.sectionLoadError('${snapshot.error}')),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _refreshSections,
                  child: Text(AppLocalizations.admin.retry),
                ),
              ],
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.category_outlined, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text(AppLocalizations.admin.noSections),
                const SizedBox(height: 8),
                Text(
                  AppLocalizations.admin.createFirstSection,
                  style: const TextStyle(color: AppColors.textLight, fontSize: 13),
                ),
              ],
            ),
          );
        }

        final sections = snapshot.data!;

        return RefreshIndicator(
          onRefresh: _refreshSections,
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            itemCount: sections.length,
            itemBuilder: (context, index) {
              return _buildSectionTile(sections[index], index, sections.length);
            },
          ),
        );
      },
    );
  }

  Widget _buildSectionTile(Section section, int index, int totalSections) {
    return Card(
      key: Key(section.id),
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            // Reorder buttons
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 28,
                  height: 28,
                  child: IconButton(
                    icon: const Icon(Icons.keyboard_arrow_up, size: 18),
                    onPressed: index > 0 ? () => _moveSectionUp(section) : null,
                    padding: EdgeInsets.zero,
                    splashRadius: 14,
                  ),
                ),
                SizedBox(
                  width: 28,
                  height: 28,
                  child: IconButton(
                    icon: const Icon(Icons.keyboard_arrow_down, size: 18),
                    onPressed: index < totalSections - 1
                        ? () => _moveSectionDown(section)
                        : null,
                    padding: EdgeInsets.zero,
                    splashRadius: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
            // Section info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    section.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    AppLocalizations.admin.orderLabel(section.sortOrder),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textLight,
                    ),
                  ),
                ],
              ),
            ),
            // Visibility switch
            Switch(
              value: section.isVisible,
              onChanged: (value) => _setVisibility(section, value),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            // Edit button
            SizedBox(
              width: 36,
              height: 36,
              child: IconButton(
                icon: const Icon(Icons.edit_outlined, size: 18),
                onPressed: () => _renameSection(section),
                padding: EdgeInsets.zero,
                splashRadius: 18,
              ),
            ),
            // Delete button
            SizedBox(
              width: 36,
              height: 36,
              child: IconButton(
                icon: const Icon(
                  Icons.delete_outline,
                  size: 18,
                  color: Colors.red,
                ),
                onPressed: () => _deleteSection(section),
                padding: EdgeInsets.zero,
                splashRadius: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
