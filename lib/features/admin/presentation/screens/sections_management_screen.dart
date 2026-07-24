import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tatislam_app/features/sections/data/section_providers.dart';
import 'package:tatislam_app/features/sections/domain/entities/section.dart';

class SectionsManagementScreen extends ConsumerStatefulWidget {
  const SectionsManagementScreen({super.key});

  @override
  ConsumerState<SectionsManagementScreen> createState() => _SectionsManagementScreenState();
}

class _SectionsManagementScreenState extends ConsumerState<SectionsManagementScreen> {
  late Future<List<Section>> _sectionsFuture;
  bool _isLoading = false;

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

  Future<void> _createSection() async {
    final name = await _showCreateSectionDialog();
    if (name != null && name.isNotEmpty) {
      setState(() {
        _isLoading = true;
      });

      try {
        final repository = ref.read(sectionRepositoryProvider);
        await repository.createSection(name);
        await _refreshSections();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Раздел создан')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ошибка создания раздела: $e')),
          );
        }
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<String?> _showCreateSectionDialog() async {
    final controller = TextEditingController();
    return showDialog<String?>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Создать раздел'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(labelText: 'Название раздела'),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text('Создать'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _renameSection(Section section) async {
    final name = await _showRenameSectionDialog(section.name);
    if (name != null && name.isNotEmpty && name != section.name) {
      setState(() {
        _isLoading = true;
      });

      try {
        final repository = ref.read(sectionRepositoryProvider);
        await repository.renameSection(section.id, name);
        await _refreshSections();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Раздел переименован')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ошибка переименования раздела: $e')),
          );
        }
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<String?> _showRenameSectionDialog(String currentName) async {
    final controller = TextEditingController(text: currentName);
    return showDialog<String?>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Переименовать раздел'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(labelText: 'Новое название'),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text('Сохранить'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _setVisibility(Section section, bool isVisible) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final repository = ref.read(sectionRepositoryProvider);
      await repository.setVisibility(section.id, isVisible);
      await _refreshSections();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Раздел ${isVisible ? 'показан' : 'скрыт'}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка изменения видимости: $e')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteSection(Section section) async {
    final confirmed = await _showDeleteConfirmationDialog(section.name);
    if (confirmed) {
      setState(() {
        _isLoading = true;
      });

      try {
        final repository = ref.read(sectionRepositoryProvider);
        await repository.deleteSection(section.id);
        await _refreshSections();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Раздел удален')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ошибка удаления раздела: $e')),
          );
        }
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<bool> _showDeleteConfirmationDialog(String sectionName) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Удалить раздел'),
          content: Text('Вы уверены, что хотите удалить раздел "$sectionName"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Удалить'),
            ),
          ],
        );
      },
    ) ?? false;
  }

  Future<void> _moveSectionUp(Section section) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final repository = ref.read(sectionRepositoryProvider);
      final result = await repository.moveSectionUp(section);
      
      if (result != null || result == null) {
        // Refresh the list regardless of result (null is expected)
        await _refreshSections();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Раздел перемещен вверх')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка перемещения раздела вверх: $e')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _moveSectionDown(Section section) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final repository = ref.read(sectionRepositoryProvider);
      final result = await repository.moveSectionDown(section);
      
      if (result != null || result == null) {
        // Refresh the list regardless of result (null is expected)
        await _refreshSections();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Раздел перемещен вниз')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка перемещения раздела вниз: $e')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Управление разделами'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _isLoading ? null : _createSection,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _refreshSections,
          ),
        ],
      ),
      body: FutureBuilder<List<Section>>(
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
                  Text('Ошибка загрузки разделов: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _refreshSections,
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
                  Icon(Icons.category_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Разделы не найдены'),
                  SizedBox(height: 16),
                  Text('Нажмите + для создания нового раздела'),
                ],
              ),
            );
          }

          final sections = snapshot.data!;
          
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: sections.length,
            itemBuilder: (context, index) {
              return _buildSectionTile(sections[index], index, sections.length);
            },
          );
        },
      ),
    );
  }

  Widget _buildSectionTile(Section section, int index, int totalSections) {
    return Card(
      key: Key(section.id),
      margin: const EdgeInsets.only(bottom: 16),
      child: ListTile(
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_upward, size: 18),
              onPressed: index > 0 ? () => _moveSectionUp(section) : null,
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints.tightFor(width: 36, height: 36),
            ),
            IconButton(
              icon: const Icon(Icons.arrow_downward, size: 18),
              onPressed: index < totalSections - 1 ? () => _moveSectionDown(section) : null,
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints.tightFor(width: 36, height: 36),
            ),
          ],
        ),
        title: Text(section.name),
        subtitle: Text('Порядок: ${section.sortOrder}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              value: section.isVisible,
              onChanged: (value) => _setVisibility(section, value),
            ),
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => _renameSection(section),
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () => _deleteSection(section),
            ),
          ],
        ),
        onTap: () => _renameSection(section),
      ),
    );
  }

  Future<void> _updateSectionOrder(List<Section> sections) async {
    try {
      final repository = ref.read(sectionRepositoryProvider);
      final orderedIds = sections.map((s) => s.id).toList();
      await repository.reorderSections(orderedIds);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка сохранения порядка: $e')),
        );
      }
    }
  }
}