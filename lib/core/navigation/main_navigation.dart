import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:tatislam_app/core/constants/app_colors.dart';
import 'package:tatislam_app/core/constants/app_strings.dart';

typedef SetStateCallback = void Function(VoidCallback fn);

class MainNavigation extends StatefulWidget {
  final SetStateCallback setState;

  const MainNavigation({super.key, required this.setState});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    // Listen to router changes to update index
    final GoRouter router = GoRouter.of(context);
    final String location = router.routeInformationProvider.value.uri.path;

    // Check if we're on the publication detail screen
    final bool isPublicationDetailScreen = location.startsWith('/publication/');

    // If we're on the publication detail screen, don't show bottom navigation
    if (isPublicationDetailScreen) {
      return const SizedBox.shrink();
    }

    // Update index based on current location
    if (location == '/') {
      _currentIndex = 0;
    } else if (location.startsWith('/catalog')) {
      _currentIndex = 1;
    } else if (location.startsWith('/search')) {
      _currentIndex = 2;
    } else if (location.startsWith('/about')) {
      _currentIndex = 3;
    } else {
      _currentIndex = 0;
    }

    // Define colors for each tab
    final List<Color> selectedColors = [
      AppColors.navHome,
      AppColors.navCatalog,
      AppColors.navSearch,
      AppColors.navAbout,
    ];

    return BottomNavigationBar(
      currentIndex: _currentIndex,
      onTap: (index) => _onItemTapped(index, context),
      selectedItemColor: selectedColors[_currentIndex],
      unselectedItemColor: AppColors.textLight,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home_outlined),
          activeIcon: Icon(Icons.home),
          label: AppStrings.homeTab,
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.book_outlined),
          activeIcon: Icon(Icons.book),
          label: AppStrings.catalogTab,
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.search_outlined),
          activeIcon: Icon(Icons.search),
          label: AppStrings.searchTab,
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.info_outline),
          activeIcon: Icon(Icons.info),
          label: AppStrings.aboutTab,
        ),
      ],
    );
  }

  void _onItemTapped(int index, BuildContext context) {
    final GoRouter router = GoRouter.of(context);
    switch (index) {
      case 0:
        router.go('/');
        break;
      case 1:
        router.go('/catalog');
        break;
      case 2:
        router.go('/search');
        break;
      case 3:
        router.go('/about');
        break;
    }
  }
}
