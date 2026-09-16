import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tatislam_app/core/constants/app_colors.dart';
import 'package:tatislam_app/core/constants/app_localizations.dart';
import 'package:tatislam_app/features/admin/presentation/screens/publications_list_screen.dart';
import 'package:tatislam_app/features/admin/presentation/screens/sections_management_screen.dart';
import 'package:tatislam_app/features/admin/presentation/screens/uploads_queue_screen.dart';
import 'package:tatislam_app/features/admin/queue/queue_providers.dart';

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  int _selectedIndex = 0;

  static const List<Widget> _widgetOptions = <Widget>[
    PublicationsListScreen(),
    SectionsManagementScreen(),
    UploadsQueueScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final queue = ref.watch(publicationUploadQueueProvider);
    ref.watch(publicationUploadQueueVersionProvider);
    final activeCount = queue.activeCount;
    final uploadsLabel = activeCount > 0
        ? '${AppLocalizations.admin.uploadsTitle} ($activeCount)'
        : AppLocalizations.admin.uploadsTitle;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.secondary,
        leading: IconButton(
          icon: const Icon(Icons.home),
          onPressed: () {
            context.go('/');
          },
        ),
        title: Text(_titleForIndex(_selectedIndex)),
        actions: [
          if (_selectedIndex == 0) ...[
            IconButton(
              icon: const Icon(Icons.add_photo_alternate),
              tooltip: AppLocalizations.admin.newPhotoTooltip,
              onPressed: () {
                context.push('/admin/photos/new');
              },
            ),
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () {
                context.push('/admin/publications/new');
              },
            ),
          ],
          if (_selectedIndex == 1)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: _selectedIndex == 1
                  ? () {
                      context.push('/admin/sections/new');
                    }
                  : null,
            ),
          if (_selectedIndex == 1)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                // Refresh is handled by the SectionManagementScreen's own refresh
                setState(() {});
              },
            ),
        ],
      ),
      body: _widgetOptions.elementAt(_selectedIndex),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onItemTapped,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.article_outlined),
            selectedIcon: const Icon(Icons.article),
            label: AppLocalizations.admin.publicationsTitle,
          ),
          NavigationDestination(
            icon: const Icon(Icons.category_outlined),
            selectedIcon: const Icon(Icons.category),
            label: AppLocalizations.admin.sectionsTitle,
          ),
          NavigationDestination(
            icon: const Icon(Icons.cloud_upload_outlined),
            selectedIcon: const Icon(Icons.cloud_upload),
            label: uploadsLabel,
          ),
        ],
      ),
    );
  }

  String _titleForIndex(int index) {
    switch (index) {
      case 0:
        return AppLocalizations.admin.publicationsTitle;
      case 1:
        return AppLocalizations.admin.sectionsTitle;
      default:
        return AppLocalizations.admin.uploadsTitle;
    }
  }
}
