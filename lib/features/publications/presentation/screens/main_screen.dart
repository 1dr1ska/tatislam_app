import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tatislam_app/core/constants/app_strings.dart';
import 'package:tatislam_app/core/constants/app_colors.dart';
import 'package:tatislam_app/features/publications/domain/entities/publication.dart';
import 'package:tatislam_app/features/publications/presentation/providers/publications_providers.dart';
import 'package:tatislam_app/features/publications/presentation/widgets/app_background.dart';
import 'package:tatislam_app/features/sections/data/section_providers.dart';
import 'package:tatislam_app/features/sections/domain/entities/section.dart';
import 'package:tatislam_app/features/catalog/presentation/providers/selected_section_provider.dart';
import 'package:tatislam_app/features/favorites/providers/favorites_provider.dart';
import 'package:tatislam_app/core/constants/app_icons.dart';

/// Main screen — the single entry point for all user-facing content.
/// Contains:
/// - AppBar: logo (→ about), search field, favorites toggle (star)
/// - Section filter chips
/// - Publications grid
class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text;
    ref.read(searchQueryProvider.notifier).state = query;
  }

  void _clearSearch() {
    _searchController.clear();
    ref.read(searchQueryProvider.notifier).state = '';
  }

  @override
  Widget build(BuildContext context) {
    final sectionsAsync = ref.watch(sectionsProvider);
    final publicationsAsync = ref.watch(mainPublicationsProvider);
    final showFavoritesOnly = ref.watch(favoritesFilterProvider);
    final selectedSection = ref.watch(selectedSectionProvider);

    // Watch favorites to react to changes
    ref.watch(favoritesProvider);

    // Determine background: use section's backgroundImage if set, otherwise default
    final backgroundPath = selectedSection?.backgroundImage;

    final isLoading = sectionsAsync.isLoading || publicationsAsync.isLoading;

    return Stack(
      children: [
        // Background layer — section background or default
        AppBackground(imagePath: backgroundPath),
        // Foreground layer — all UI content
        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.white.withValues(alpha: 0.85),
            titleSpacing: 0,
            title: Row(
              children: [
                // Logo — tap to open About screen
                GestureDetector(
                  onTap: () {
                    GoRouter.of(context).go('/about');
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: SizedBox(
                      width: 36,
                      height: 36,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.asset(
                          'assets/images/app_icon.png',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(Icons.mosque, size: 28),
                        ),
                      ),
                    ),
                  ),
                ),
                // Search field
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Эзләү...',
                      border: InputBorder.none,
                      filled: false,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 20),
                              onPressed: _clearSearch,
                            )
                          : null,
                    ),
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              ],
            ),
            actions: [
              // Favorites toggle button
              IconButton(
                icon: Icon(
                  showFavoritesOnly ? Icons.star : Icons.star_border,
                  color: showFavoritesOnly ? Colors.amber : null,
                ),
                tooltip: showFavoritesOnly ? 'Барлык язмалар' : 'Сайланганнар',
                onPressed: () {
                  ref.read(toggleFavoritesFilterProvider)();
                },
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(sectionsProvider);
              ref.invalidate(mainPublicationsProvider);
              ref.invalidate(selectedSectionProvider);
              ref.invalidate(favoritesProvider);
              await Future.wait([
                ref.read(sectionsProvider.future),
                ref.read(mainPublicationsProvider.future),
                ref.read(favoritesProvider.future),
              ]);
            },
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Section filters
                        _buildSectionFilters(ref, sectionsAsync),
                        const SizedBox(height: 16),
                        // Publications grid
                        _buildPublicationsGrid(context, ref, publicationsAsync),
                      ],
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionFilters(
      WidgetRef ref, AsyncValue<List<Section>> sectionsAsync) {
    final selectedSection = ref.watch(selectedSectionProvider);

    return sectionsAsync.when(
      data: (sections) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildFilterChip(
                label: 'Барлык бүлекләр',
                selected: selectedSection == null,
                onSelected: (selected) {
                  ref.read(selectedSectionProvider.notifier).state = null;
                },
              ),
              ...sections.map((section) => _buildFilterChip(
                    label: section.name,
                    selected: selectedSection?.id == section.id,
                    onSelected: (selected) {
                      ref.read(selectedSectionProvider.notifier).state =
                          selected ? section : null;
                    },
                  )),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (error, stackTrace) => Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'Бүлекләрне йөкләү хатасы',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool selected,
    required ValueChanged<bool> onSelected,
  }) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: onSelected,
      backgroundColor: Colors.white.withValues(alpha: 0.75),
      selectedColor: AppColors.primary.withValues(alpha: 0.75),
      labelStyle: TextStyle(
        color: selected ? Colors.white : null,
      ),
    );
  }

  Widget _buildPublicationsGrid(BuildContext context, WidgetRef ref,
      AsyncValue<List<Publication>> publicationsAsync) {
    return publicationsAsync.when(
      data: (publications) {
        if (publications.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 64),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.article_outlined,
                    size: 64,
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Язмалар табылмады',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            ),
          );
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 0.85,
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
        child: Padding(
          padding: const EdgeInsets.only(top: 64),
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
                onPressed: () => ref.invalidate(mainPublicationsProvider),
                child: Text(AppStrings.retry),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PublicationCard extends ConsumerWidget {
  final Publication publication;

  const _PublicationCard({required this.publication});

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFavorite = ref.watch(favoritesIsFavoriteProvider(publication.id));

    return GestureDetector(
      onTap: () {
        GoRouter.of(context).go(
          '/publication/${publication.id}?source=catalog',
        );
      },
      child: Card(
        elevation: 2,
        color: Colors.white.withValues(alpha: 0.85),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Icon
                        ClipRRect(
                          borderRadius:
                              const BorderRadius.vertical(top: Radius.circular(12)),
                          child: AspectRatio(
                            aspectRatio: 16 / 9,
                            child: Container(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              child: Center(
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
                                publication.title,
                                style: Theme.of(context).textTheme.titleMedium,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _formatDate(publication.publishedAt),
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      isFavorite
                                          ? Icons.star
                                          : Icons.star_border,
                                      color: isFavorite ? Colors.amber : null,
                                    ),
                                    onPressed: () async {
                                      final toggleFavorite =
                                          ref.read(toggleFavoriteProvider);
                                      await toggleFavorite(publication.id);
                                      Future.microtask(() {
                                        ref.invalidate(favoritesProvider);
                                        ref.invalidate(mainPublicationsProvider);
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
        ),
      ),
    );
  }
}