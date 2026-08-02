import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tatislam_app/core/constants/app_colors.dart';
import 'package:tatislam_app/features/admin/presentation/screens/publications_list_screen.dart';
import 'package:tatislam_app/features/admin/presentation/screens/sections_management_screen.dart';

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  int _selectedIndex = 0;

  static const List<Widget> _widgetOptions = <Widget>[
    PublicationsListScreen(),
    SectionsManagementScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.secondary,
        title: Text(
          _selectedIndex == 0 ? 'Публикации' : 'Разделы',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
            onPressed: () {
              context.go('/');
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: Column(
          children: [
            // Header with app branding
            Container(
              width: double.infinity,
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 16,
                bottom: 16,
                left: 16,
                right: 16,
              ),
              color: AppColors.secondary,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.admin_panel_settings,
                    color: Colors.white,
                    size: 28,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Admin Panel',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Управление контентом',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            // Navigation items
            ListTile(
              leading: Icon(
                Icons.article_outlined,
                color: _selectedIndex == 0 ? Colors.blue : Colors.grey[600],
              ),
              title: Text(
                'Публикации',
                style: TextStyle(
                  color: _selectedIndex == 0 ? Colors.blue : Colors.black87,
                  fontWeight: _selectedIndex == 0 ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              selected: _selectedIndex == 0,
              selectedTileColor: Colors.blue.withValues(alpha: 0.08),
              onTap: () {
                _onItemTapped(0);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(
                Icons.category_outlined,
                color: _selectedIndex == 1 ? Colors.blue : Colors.grey[600],
              ),
              title: Text(
                'Разделы',
                style: TextStyle(
                  color: _selectedIndex == 1 ? Colors.blue : Colors.black87,
                  fontWeight: _selectedIndex == 1 ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              selected: _selectedIndex == 1,
              selectedTileColor: Colors.blue.withValues(alpha: 0.08),
              onTap: () {
                _onItemTapped(1);
                Navigator.pop(context);
              },
            ),
            const Divider(),
            ListTile(
              leading: Icon(Icons.home_outlined, color: Colors.grey[600]),
              title: const Text('На главную'),
              onTap: () {
                Navigator.pop(context);
                context.go('/');
              },
            ),
            const Spacer(),
            // Footer
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'TatIslam v1.0',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
      body: _widgetOptions.elementAt(_selectedIndex),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onItemTapped,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.article_outlined),
            selectedIcon: Icon(Icons.article),
            label: 'Публикации',
          ),
          NavigationDestination(
            icon: Icon(Icons.category_outlined),
            selectedIcon: Icon(Icons.category),
            label: 'Разделы',
          ),
        ],
      ),
    );
  }
}
