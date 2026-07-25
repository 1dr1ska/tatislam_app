import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tatislam_app/features/publications/data/publication_providers.dart';
import 'package:tatislam_app/features/publications/domain/entities/publication.dart';
import 'package:tatislam_app/core/constants/app_colors.dart';
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

  @override
  void initState() {
    super.initState();
    _publicationsFuture = _loadPublications();
  }

  Future<List<Publication>> _loadPublications() async {
    final repository = ref.read(publicationRepositoryProvider);
    if (_searchQuery.trim().isNotEmpty) {
      return repository.getPublications(searchQuery: _searchQuery.trim(), includeAllStatuses: true);
    }
    return repository.getPublications(includeAllStatuses: true); // Include all statuses for admin
  }

  void _refreshPublications() {
    setState(() {
      _publicationsFuture = _loadPublications();
    });
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
      _refreshPublications();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Публикации'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              context.push('/admin/publications/new');
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Поиск',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: _onSearchChanged,
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

                // Sort publications
                publications.sort((a, b) {
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

                return ListView.builder(
                  itemCount: publications.length,
                  itemBuilder: (context, index) {
                    final publication = publications[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        leading: _getIconForType(publication.type),
                        title: Text(publication.title),
                        subtitle: _getStatusBadge(publication.status ?? 'draft'),
                        trailing: PopupMenuButton<String>(
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
                        ),
                        onTap: () {
                          context.push('/admin/publications/${publication.id}/edit');
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _getIconForType(String type) {
    switch (type) {
      case 'article':
        return const Icon(Icons.article, color: AppColors.articleColor);
      case 'video':
        return const Icon(Icons.play_circle, color: AppColors.videoColor);
      case 'audio':
        return const Icon(Icons.audiotrack, color: AppColors.audioColor);
      default:
        return const Icon(Icons.article, color: AppColors.articleColor);
    }
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

  Widget _getStatusBadge(String status) {
    Color color;
    String text;

    switch (status) {
      case 'draft':
        color = Colors.grey;
        text = 'Черновик';
        break;
      case 'published':
        color = Colors.green;
        text = 'Опубликовано';
        break;
      case 'archived':
        color = Colors.orange;
        text = 'Архив';
        break;
      default:
        color = Colors.grey;
        text = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
