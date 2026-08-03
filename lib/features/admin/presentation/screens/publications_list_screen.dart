import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tatislam_app/core/constants/app_colors.dart';
import 'package:tatislam_app/core/constants/app_icons.dart';
import 'package:tatislam_app/features/publications/data/publication_providers.dart';
import 'package:tatislam_app/features/publications/domain/entities/publication.dart';

class PublicationsListScreen extends ConsumerStatefulWidget {
  const PublicationsListScreen({super.key});

  @override
  ConsumerState<PublicationsListScreen> createState() => _PublicationsListScreenState();
}

class _PublicationsListScreenState extends ConsumerState<PublicationsListScreen> {
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
      return repository.getPublications(searchQuery: _searchQuery.trim(), includeAllStatuses: true);
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
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Поиск публикаций...',
              prefixIcon: const Icon(Icons.search, size: 20),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                      Text('Ошибка загрузки: ${snapshot.error}'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _refreshPublications,
                        child: const Text('Повторить'),
                      ),
                    ],
                  ),
                );
              }

              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.article_outlined, size: 64, color: AppColors.articleColor),
                      SizedBox(height: 16),
                      Text('Публикации не найдены'),
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
                  // Publication icon (actual icon selected for this publication)
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: typeInfo.color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: publication.icon != null &&
                              AppIcons.paths.containsKey(publication.icon)
                          ? Image.asset(
                              AppIcons.paths[publication.icon]!,
                              width: 28,
                              height: 28,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) =>
                                  Icon(typeInfo.icon,
                                      color: typeInfo.color, size: 24),
                            )
                          : Icon(typeInfo.icon,
                              color: typeInfo.color, size: 24),
                    ),
                  ),
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
                        context.push('/admin/publications/${publication.id}/edit');
                      } else if (value == 'delete') {
                        _confirmDelete(context, publication);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Text('Редактировать'),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Удалить'),
                      ),
                    ],
                    icon: const Icon(Icons.more_vert, size: 18, color: AppColors.textSecondary),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Bottom row: type badge + status badge + date
              Row(
                children: [
                  // Type badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: typeInfo.color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      typeInfo.label,
                      style: TextStyle(
                        fontSize: 10,
                        color: typeInfo.color,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusInfo.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusInfo.icon, size: 10, color: statusInfo.color),
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
        return _StatusInfo(Icons.check_circle, AppColors.islamGreen, 'Опубликовано');
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
        title: const Text('Подтверждение удаления'),
        content: Text('Вы уверены, что хотите удалить "${publication.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await _deletePublication(context, publication);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
  }

  Future<void> _deletePublication(BuildContext context, Publication publication) async {
    try {
      final repository = ref.read(publicationRepositoryProvider);
      await repository.deletePublication(publication.id);
      _refreshPublications();
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Публикация удалена')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка удаления: $e')),
        );
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