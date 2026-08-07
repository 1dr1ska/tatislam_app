import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tatislam_app/core/constants/app_colors.dart';
import 'package:tatislam_app/core/constants/app_icons.dart';
import 'package:tatislam_app/core/constants/app_localizations.dart';
import 'package:tatislam_app/features/publications/data/publication_providers.dart';
import 'package:tatislam_app/features/publications/domain/entities/publication.dart';
import 'package:tatislam_app/features/publications/presentation/providers/publications_providers.dart';

class PublicationsListScreen extends ConsumerStatefulWidget {
  const PublicationsListScreen({super.key});

  @override
  ConsumerState<PublicationsListScreen> createState() =>
      _PublicationsListScreenState();
}

class _PublicationsListScreenState
    extends ConsumerState<PublicationsListScreen> {
  late Future<List<Publication>> _publicationsFuture;
  String _searchQuery = '';
  final String _sortBy = 'publishedAt';
  final bool _sortAscending = false;
  bool _mounted = true;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _mounted = true;
    _publicationsFuture = _loadPublications();
  }

  @override
  void dispose() {
    _mounted = false;
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<List<Publication>> _loadPublications() async {
    final repository = ref.read(publicationRepositoryProvider);
    if (_searchQuery.trim().isNotEmpty) {
      return repository.getPublications(
        searchQuery: _searchQuery.trim(),
        includeAllStatuses: true,
      );
    }
    return repository.getPublications(includeAllStatuses: true);
  }

  void _refreshPublications() {
    if (!_mounted) return;
    setState(() {
      _publicationsFuture = _loadPublications();
    });
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 350), () {
      if (!_mounted) return;
      setState(() {
        _searchQuery = query;
        _publicationsFuture = _loadPublications();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    // Auto-refresh the list when any publication is created, updated or
    // deleted (version counter is incremented by the editor and delete flows).
    ref.listen(publicationListVersionProvider, (previous, next) {
      if (previous != next) {
        _refreshPublications();
      }
    });

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: TextField(
            decoration: InputDecoration(
              hintText: AppLocalizations.admin.searchPublications,
              prefixIcon: const Icon(Icons.search, size: 20),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            onChanged: _onSearchChanged,
            style: const TextStyle(fontSize: 14),
          ),
        ),
        Expanded(
          child: FutureBuilder<List<Publication>>(
            future: _publicationsFuture,
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
                      Text('${AppLocalizations.admin.publicationLoadError}${snapshot.error}'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _refreshPublications,
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
                      const Icon(
                        Icons.article_outlined,
                        size: 64,
                        color: AppColors.articleColor,
                      ),
                      const SizedBox(height: 16),
                      Text(AppLocalizations.admin.noPublicationsFound),
                    ],
                  ),
                );
              }

              final publications = snapshot.data!;

              // Create a sorted copy — never mutate the original list in build()
              final sorted = List<Publication>.from(publications)
                ..sort((a, b) {
                  switch (_sortBy) {
                    case 'title':
                      final comparison = a.title.compareTo(b.title);
                      return _sortAscending ? comparison : -comparison;
                    case 'publishedAt':
                      final comparison = a.publishedAt.compareTo(b.publishedAt);
                      return _sortAscending ? comparison : -comparison;
                    default:
                      return 0;
                  }
                });

              return RefreshIndicator(
                onRefresh: () async => _refreshPublications(),
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                  itemCount: sorted.length,
                  itemBuilder: (context, index) {
                    return _buildPublicationCard(sorted[index]);
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPublicationCard(Publication publication) {
    final typeInfo = _getTypeInfo(publication.type);
    final statusInfo = _getStatusInfo(publication.status ?? 'draft');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          context.push('/admin/publications/${publication.id}/edit');
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top row: icon + title + menu
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Publication icon — large, no decorative container
                  publication.icon != null &&
                          AppIcons.paths.containsKey(publication.icon)
                      ? Image.asset(
                          AppIcons.paths[publication.icon]!,
                          width: 40,
                          height: 40,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) => Icon(
                            typeInfo.icon,
                            color: typeInfo.color,
                            size: 36,
                          ),
                        )
                      : Icon(typeInfo.icon, color: typeInfo.color, size: 36),
                  const SizedBox(width: 12),
                  // Title
                  Expanded(
                    child: Text(
                      publication.title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Menu
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') {
                        context.push(
                          '/admin/publications/${publication.id}/edit',
                        );
                      } else if (value == 'delete') {
                        _confirmDelete(context, publication);
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'edit',
                        child: Text(AppLocalizations.admin.editAction),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Text(AppLocalizations.admin.deleteAction),
                      ),
                    ],
                    icon: const Icon(
                      Icons.more_vert,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Bottom row: status badge + date
              Row(
                children: [
                  // Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: statusInfo.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          statusInfo.icon,
                          size: 10,
                          color: statusInfo.color,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          statusInfo.label,
                          style: TextStyle(
                            fontSize: 10,
                            color: statusInfo.color,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // Date
                  Text(
                    _formatDate(publication.publishedAt),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textLight,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  _TypeInfo _getTypeInfo(String type) {
    switch (type) {
      case 'article':
        return _TypeInfo(Icons.article, AppColors.articleColor, 'Статья');
      case 'video':
        return _TypeInfo(Icons.play_circle, AppColors.videoColor, 'Видео');
      case 'audio':
        return _TypeInfo(Icons.audiotrack, AppColors.audioColor, 'Аудио');
      default:
        return _TypeInfo(Icons.article, AppColors.articleColor, 'Статья');
    }
  }

  _StatusInfo _getStatusInfo(String status) {
    switch (status) {
      case 'draft':
        return _StatusInfo(Icons.edit_note, Colors.grey, 'Черновик');
      case 'published':
        return _StatusInfo(
          Icons.check_circle,
          AppColors.islamGreen,
          'Опубликовано',
        );
      default:
        return _StatusInfo(Icons.edit_note, Colors.grey, status);
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  void _confirmDelete(BuildContext context, Publication publication) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppLocalizations.admin.deleteConfirmation),
        content: Text(AppLocalizations.admin.deleteConfirmationMessage(publication.title)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(AppLocalizations.admin.cancelAction),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await _deletePublication(context, publication);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(AppLocalizations.admin.deleteAction),
          ),
        ],
      ),
    );
  }

  Future<void> _deletePublication(
    BuildContext context,
    Publication publication,
  ) async {
    try {
      final repository = ref.read(publicationRepositoryProvider);
      await repository.deletePublication(publication.id);
      ref.read(publicationListVersionProvider.notifier).state++;
      _refreshPublications();

      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AppLocalizations.admin.publicationDeleted)));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${AppLocalizations.admin.publicationDeleteError}$e')));
      }
    }
  }
}

class _TypeInfo {
  final IconData icon;
  final Color color;
  final String label;
  const _TypeInfo(this.icon, this.color, this.label);
}

class _StatusInfo {
  final IconData icon;
  final Color color;
  final String label;
  const _StatusInfo(this.icon, this.color, this.label);
}
