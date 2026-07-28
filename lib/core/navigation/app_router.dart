import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tatislam_app/features/about/presentation/screens/about_screen.dart';
import 'package:tatislam_app/features/admin/presentation/screens/admin_screen.dart';
import 'package:tatislam_app/features/admin/presentation/screens/publication_editor_screen.dart';
import 'package:tatislam_app/features/admin/presentation/screens/section_editor_screen.dart';
import 'package:tatislam_app/features/auth/presentation/screens/login_screen.dart';
import 'package:tatislam_app/features/auth/presentation/screens/register_screen.dart';
import 'package:tatislam_app/features/auth/providers/auth_provider.dart';
import 'package:tatislam_app/features/detail/presentation/screens/publication_detail_screen_new.dart';
import 'package:tatislam_app/features/publications/presentation/screens/main_screen.dart';

/// App router configuration using go_router.
/// 
/// Navigation structure:
/// - `/` — MainScreen (single entry point: search + filters + publications grid)
/// - `/about` — About screen (opened from logo tap)
/// - `/publication/:id` — Publication detail
/// - `/login`, `/register` — Auth screens
/// - `/admin/**` — Admin section (protected)
final appRouterProvider = Provider<GoRouter>((ref) {
  // Watch current user to make redirect reactive when session resolves
  ref.watch(currentUserProvider);

  return GoRouter(
    // Remove the initial route splash — start at the main screen
    initialLocation: '/',
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
            final userAsync = container.read(currentUserProvider);

            // Wait for the future to resolve before deciding
            return userAsync.when(
              data: (user) => (user?.isAdmin ?? false) ? null : '/login',
              loading: () => null, // Don't redirect yet — wait for Supabase to restore session
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
      // Main screen — single entry point for all user-facing content
      GoRoute(
        path: '/',
        name: 'main',
        builder: (context, state) => const MainScreen(),
      ),
      // About screen
      GoRoute(
        path: '/about',
        name: 'about',
        builder: (context, state) => const AboutScreen(),
      ),
      // Publication detail screen
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
  );
});