import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tatislam_app/core/navigation/main_navigation.dart';
import 'package:tatislam_app/features/about/presentation/screens/about_screen.dart';
import 'package:tatislam_app/features/admin/presentation/screens/admin_screen.dart';
import 'package:tatislam_app/features/admin/presentation/screens/publication_editor_screen.dart';
import 'package:tatislam_app/features/admin/presentation/screens/section_editor_screen.dart';
import 'package:tatislam_app/features/auth/presentation/screens/login_screen.dart';
import 'package:tatislam_app/features/auth/presentation/screens/register_screen.dart';
import 'package:tatislam_app/features/auth/providers/auth_provider.dart';
import 'package:tatislam_app/features/catalog/presentation/screens/catalog_screen.dart';
import 'package:tatislam_app/features/detail/presentation/screens/publication_detail_screen_new.dart';
import 'package:tatislam_app/features/home/presentation/screens/home_screen.dart';
import 'package:tatislam_app/features/search/presentation/screens/search_screen.dart';

/// App router configuration using go_router with ShellRoute for bottom navigation
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    routes: [
      // Login route (outside shell)
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      // Register route (outside shell)
      GoRoute(
        path: '/register',
        name: 'register',
        builder: (context, state) => const RegisterScreen(),
      ),
      // Admin route (outside shell, protected)
          GoRoute(
            path: '/admin',
            name: 'admin',
            builder: (context, state) => const AdminScreen(),
            redirect: (context, state) {
              try {
                // In debug mode, allow access to admin screen
                if (kDebugMode) {
                  return null; // Allow access in debug mode
                }
                
                final container = ProviderScope.containerOf(context);
                final authState = container.read(authStateProvider);
                
                // If auth state is loading or error, redirect to login
                return authState.when(
                  data: (user) => (user?.isAdmin ?? false) ? null : '/login',
                  loading: () => '/login',
                  error: (error, stackTrace) => '/login',
                );
              } catch (e) {
                // If any error occurs, redirect to login
                return '/login';
              }
            },
            routes: [
              GoRoute(
                path: 'publications/new',
                name: 'newPublication',
                builder: (context, state) => const PublicationEditorScreen(),
              ),
              GoRoute(
                path: 'publications/:id/edit',
                name: 'editPublication',
                builder: (context, state) {
                  final id = state.pathParameters['id']!;
                  return PublicationEditorScreen(publicationId: id);
                },
              ),
              GoRoute(
                path: 'sections/new',
                name: 'newSection',
                builder: (context, state) => const SectionEditorScreen(),
              ),
              GoRoute(
                path: 'sections/:id/edit',
                name: 'editSection',
                builder: (context, state) {
                  final id = state.pathParameters['id']!;
                  return SectionEditorScreen(sectionId: id);
                },
              ),
            ],
          ),
      // Main app routes with bottom navigation
      ShellRoute(
        builder: (context, state, child) => StatefulBuilder(
          builder: (context, setState) => Scaffold(
            body: child,
            bottomNavigationBar: MainNavigation(setState: setState),
          ),
        ),
        routes: [
          GoRoute(
            path: '/',
            name: 'home',
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: '/catalog',
            name: 'catalog',
            builder: (context, state) => const CatalogScreen(),
          ),
          GoRoute(
            path: '/search',
            name: 'search',
            builder: (context, state) => const SearchScreen(),
          ),
          GoRoute(
            path: '/about',
            name: 'about',
            builder: (context, state) => const AboutScreen(),
          ),
          GoRoute(
            path: '/publication/:id',
            name: 'publicationDetail',
            builder: (context, state) {
              final id = state.pathParameters['id']!;
              final sourceScreen = state.uri.queryParameters['source'];
              final selectedSectionId = state.uri.queryParameters['section'];
              final catalogMode = state.uri.queryParameters['mode'];
              return PublicationDetailScreen(
                publicationId: id,
                sourceScreen: sourceScreen,
                selectedSectionId: selectedSectionId,
                catalogMode: catalogMode,
              );
            },
          ),
        ],
      ),
    ],
  );
});

// Legacy router for backward compatibility
final GoRouter appRouter = GoRouter(
  routes: [
    // Login route (outside shell)
    GoRoute(
      path: '/login',
      name: 'login',
      builder: (context, state) => const LoginScreen(),
    ),
    // Register route (outside shell)
    GoRoute(
      path: '/register',
      name: 'register',
      builder: (context, state) => const RegisterScreen(),
    ),
    // Admin route (outside shell, basic protection)
    GoRoute(
      path: '/admin',
      name: 'admin',
      builder: (context, state) => const AdminScreen(),
    ),
    // Main app routes with bottom navigation
    ShellRoute(
      builder: (context, state, child) => StatefulBuilder(
        builder: (context, setState) => Scaffold(
          body: child,
          bottomNavigationBar: MainNavigation(setState: setState),
        ),
      ),
      routes: [
        GoRoute(
          path: '/',
          name: 'home',
          builder: (context, state) => const HomeScreen(),
        ),
        GoRoute(
          path: '/catalog',
          name: 'catalog',
          builder: (context, state) => const CatalogScreen(),
        ),
        GoRoute(
          path: '/search',
          name: 'search',
          builder: (context, state) => const SearchScreen(),
        ),
        GoRoute(
          path: '/about',
          name: 'about',
          builder: (context, state) => const AboutScreen(),
        ),
        GoRoute(
          path: '/publication/:id',
          name: 'publicationDetail',
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            return PublicationDetailScreen(publicationId: id);
          },
        ),
      ],
    ),
  ],
);
