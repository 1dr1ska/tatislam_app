import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tatislam_app/core/constants/app_strings.dart';
import 'package:tatislam_app/core/constants/app_colors.dart';
import 'package:tatislam_app/features/auth/providers/auth_provider.dart';
import 'package:tatislam_app/features/publications/domain/entities/publication.dart';
import 'package:tatislam_app/features/search/providers/search_provider.dart';
import 'package:tatislam_app/features/favorites/providers/favorites_provider.dart';
import 'package:tatislam_app/features/catalog/presentation/providers/catalog_favorites_provider.dart';
import 'package:tatislam_app/core/constants/app_icons.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _showClearButton = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _showClearButton = _searchController.text.isNotEmpty;
    });
    
    // Trigger search immediately
    ref.read(searchActionProvider)(_searchController.text);
  }

  void _clearSearch() {
    _searchController.clear();
    ref.read(searchActionProvider)('');
  }

  @override
  Widget build(BuildContext context) {
    final searchResultsAsync = ref.watch(searchResultsProvider);

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          focusNode: _searchFocusNode,
          decoration: InputDecoration(
            hintText: 'Эзләү...',
            border: InputBorder.none,
            suffixIcon: _showClearButton
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: _clearSearch,
                  )
                : null,
          ),
          onSubmitted: (query) {
            ref.read(searchActionProvider)(query);
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              ref.read(searchActionProvider)(_searchController.text);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search suggestions
          // TODO: Implement search suggestions
          const SizedBox(height: 16),
          // Search results
          Expanded(
            child: _buildSearchResults(searchResultsAsync),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults(AsyncValue<List<Publication>> searchResultsAsync) {
    return searchResultsAsync.when(
      data: (publications) {
        if (publications.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.search_off,
                  size: 64,
                  color: AppColors.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  'Нәтиҗәләр табылмады',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Башка сүзләр белән эзләп карагыз',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          );
        }

        return GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 0.8,
          ),
          itemCount: publications.length,
          padding: const EdgeInsets.all(16),
          itemBuilder: (context, index) {
            final publication = publications[index];
            return _PublicationCard(publication: publication);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: AppColors.error,
            ),
            const SizedBox(height: 16),
            Text(AppStrings.errorLoading),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                // TODO: Implement retry logic
              },
              child: Text(AppStrings.retry),
            ),
          ],
        ),
      ),
    );
  }
}

class _PublicationCard extends ConsumerWidget {
  final Publication publication;

  const _PublicationCard({required this.publication});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the auth state to determine if user is admin
    final authState = ref.watch(authStateProvider);
    final isSpecialAdminCard = publication.id == 'admin_access';
    final isFavorite = !isSpecialAdminCard
        ? ref.watch(favoritesIsFavoriteProvider(publication.id))
        : false;
    
    return GestureDetector(
      onTap: () {
        // Check if this is the special admin publication
        if (publication.id == 'admin_access') {
          // Check if user is admin
          final isAdmin = authState.when(
            data: (user) => user?.isAdmin ?? false,
            loading: () => false,
            error: (_, _) => false,
          );
          
          if (isAdmin) {
            // Navigate to admin screen
            GoRouter.of(context).go('/admin');
          } else {
            // Navigate to login screen
            GoRouter.of(context).go('/login');
          }
        } else {
          // Navigate to regular publication detail with context
          GoRouter.of(context).go(
            '/publication/${publication.id}?source=search',
          );
        }
      },
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Check if user is admin for styling purposes
            final isAdmin = authState.when(
              data: (user) => user?.isAdmin ?? false,
              loading: () => false,
              error: (_, _) => false,
            );
            
            final isSpecialAdminCard = publication.id == 'admin_access';
            
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icon (or admin icon for special admin card)
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Container(
                          color: isSpecialAdminCard 
                            ? (isAdmin ? Colors.green.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1))
                            : AppColors.primary.withValues(alpha: 0.1),
                          child: isSpecialAdminCard
                            ? Center(child: Icon(
                                Icons.admin_panel_settings, 
                                size: 48, 
                                color: isAdmin ? Colors.green : Colors.orange,
                              ))
                            : Center(
                                child: Image.asset(
                                  AppIcons.pathOrDefault(publication.icon),
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.contain,
                                ),
                              ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isSpecialAdminCard 
                              ? (isAdmin ? 'Панель администратора' : 'Требуется авторизация') 
                              : publication.title,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: isSpecialAdminCard 
                                ? (isAdmin ? Colors.green : Colors.orange)
                                : null,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _formatDate(publication.publishedAt),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              if (isSpecialAdminCard)
                                Icon(Icons.admin_panel_settings, size: 16, color: AppColors.primary)
                              else
                                IconButton(
                                  icon: Icon(
                                    isFavorite ? Icons.star : Icons.star_border,
                                    color: isFavorite ? Colors.amber : null,
                                  ),
                                  onPressed: () async {
                                    final toggleFavorite = ref.read(toggleFavoriteProvider);
                                    await toggleFavorite(publication.id);
                                    Future.microtask(() {
                                      ref.invalidate(favoritesProvider);
                                      ref.invalidate(catalogFavoritesProvider);
                                    });
                                  },
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 60) {
      return '${diff.inMinutes} мин. элек';
    } else if (diff.inHours < 24) {
      return '${diff.inHours} сәг. элек';
    } else {
      return '${diff.inDays} көн элек';
    }
  }
}