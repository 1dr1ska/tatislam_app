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

/// Unified glassmorphism constants for the entire design system.
const double _glassBlur = 12;
const double _glassOpacity = 0.22;
const double _glassBorderOpacity = 0.35;
const double _glassBorderWidth = 0.8;
const double _glassRadius = 8;
const Color _glassBorderColor = Colors.white;
const Color _glassShadowColor = Colors.black;
const double _glassShadowBlur = 12;
const Offset _glassShadowOffset = Offset(0, 3);
const double _glassShadowOpacity = 0.08;

/// Main screen — the single entry point for all user-facing content.
class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _isSearchFocused = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _searchFocusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchFocusNode.removeListener(_onFocusChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    setState(() {
      _isSearchFocused = _searchFocusNode.hasFocus;
    });
  }

  void _onSearchChanged() {
    final query = _searchController.text;
    ref.read(searchQueryProvider.notifier).state = query;
  }

  void _clearSearch() {
    _searchController.clear();
    ref.read(searchQueryProvider.notifier).state = '';
  }

  BoxDecoration _glassBox({double? radius}) {
    return BoxDecoration(
      color: Colors.white.withValues(alpha: _glassOpacity),
      borderRadius: BorderRadius.circular(radius ?? _glassRadius),
      border: Border.all(
        color: _glassBorderColor.withValues(alpha: _glassBorderOpacity),
        width: _glassBorderWidth,
      ),
      boxShadow: [
        BoxShadow(
          color: _glassShadowColor.withValues(alpha: _glassShadowOpacity),
          blurRadius: _glassShadowBlur,
          offset: _glassShadowOffset,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final sectionsAsync = ref.watch(sectionsProvider);
    final publicationsAsync = ref.watch(mainPublicationsProvider);
    final showFavoritesOnly = ref.watch(favoritesFilterProvider);
    final selectedSection = ref.watch(selectedSectionProvider);

    ref.watch(favoritesProvider);

    final backgroundPath = selectedSection?.backgroundImage;
    final isLoading = sectionsAsync.isLoading || publicationsAsync.isLoading;

    return Stack(
      children: [
        AppBackground(imagePath: backgroundPath),
        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(kToolbarHeight),
            child: ClipRRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: _glassBlur, sigmaY: _glassBlur),
                child: AppBar(
                  backgroundColor: Colors.white.withValues(alpha: _glassOpacity),
                  titleSpacing: 0,
                  title: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Logo — identical glass style
                      GestureDetector(
                        onTap: () {
                          GoRouter.of(context).go('/about');
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: _glassBox(),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(_glassRadius - 1),
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
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: _glassOpacity),
                              borderRadius: BorderRadius.circular(_glassRadius),
                              border: Border.all(
                                color: _isSearchFocused
                                    ? const Color(0xFFD4A843).withValues(alpha: 0.6)
                                    : _glassBorderColor.withValues(alpha: _glassBorderOpacity),
                                width: _isSearchFocused ? 1.2 : _glassBorderWidth,
                              ),
                            ),
                            child: TextField(
                              controller: _searchController,
                              focusNode: _searchFocusNode,
                              decoration: InputDecoration(
                                hintText: 'Эзләү...',
                                hintStyle: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.85),
                                  fontSize: 14,
                                ),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                filled: false,
                                fillColor: Colors.transparent,
                                contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                suffixIcon: _searchController.text.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear, size: 18, color: Colors.white70),
                                        onPressed: _clearSearch,
                                      )
                                    : null,
                              ),
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: const Color(0xFFF8F7F2),
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    // Favorites toggle — identical glass style
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: _glassBox(),
                        child: IconButton(
                          icon: Icon(
                            showFavoritesOnly ? Icons.star : Icons.star_border,
                            color: showFavoritesOnly ? Colors.amber : Colors.white.withValues(alpha: 0.85),
                            size: 20,
                          ),
                          tooltip: showFavoritesOnly ? 'Барлык язмалар' : 'Сайланганнар',
                          onPressed: () {
                            ref.read(toggleFavoritesFilterProvider)();
                          },
                          padding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
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
                        _buildSectionFilters(ref, sectionsAsync),
                        const SizedBox(height: 16),
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
        return SizedBox(
          height: 40,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            children: [
              _buildFilterChip(
                label: 'Барлык бүлекләр',
                selected: selectedSection == null,
                onSelected: (selected) {
                  ref.read(selectedSectionProvider.notifier).state = null;
                },
              ),
              const SizedBox(width: 8),
              ...sections.map((section) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _buildFilterChip(
                  label: section.name,
                  selected: selectedSection?.id == section.id,
                  onSelected: (selected) {
                    ref.read(selectedSectionProvider.notifier).state =
                        selected ? section : null;
                  },
                ),
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
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      child: GestureDetector(
        onTap: () => onSelected(!selected),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xFFD4A843)
                    : Colors.white.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: selected
                      ? const Color(0xFFD4A843).withValues(alpha: 0.70)
                      : Colors.white.withValues(alpha: 0.35),
                  width: 0.8,
                ),
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.black87 : Colors.white,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ),
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
            return _PublicationCard(
              publication: publication,
              index: index,
            );
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
  final int index;

  const _PublicationCard({
    required this.publication,
    required this.index,
  });

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

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 300 + (index * 50).clamp(0, 200)),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: _TapScale(
        onTap: () {
          GoRouter.of(context).go(
            '/publication/${publication.id}?source=catalog',
          );
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.35),
                  width: 0.8,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon — raised up by negative margin
                  Transform.translate(
                    offset: const Offset(0, -8),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Center(
                        child: Image.asset(
                          AppIcons.pathOrDefault(publication.icon),
                          width: 120,
                          height: 120,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          publication.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                color: const Color(0xFFFEFEF7),
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatDate(publication.publishedAt),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color:
                                        Colors.white.withValues(alpha: 0.85),
                                  ),
                            ),
                            IconButton(
                              icon: Icon(
                                isFavorite
                                    ? Icons.star
                                    : Icons.star_border,
                                color: isFavorite
                                    ? Colors.amber
                                    : Colors.white.withValues(alpha: 0.70),
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
          ),
        ),
      ),
    );
  }
}

/// Wraps a child with a subtle scale-down animation on tap.
class _TapScale extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _TapScale({required this.child, required this.onTap});

  @override
  State<_TapScale> createState() => _TapScaleState();
}

class _TapScaleState extends State<_TapScale> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scale = Tween(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _scale,
        builder: (context, child) => Transform.scale(
          scale: _scale.value,
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}