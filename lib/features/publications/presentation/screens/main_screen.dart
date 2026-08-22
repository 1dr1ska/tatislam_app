import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:tatislam_app/core/storage/storage_providers.dart';
import 'package:tatislam_app/features/detail/presentation/screens/image_viewer_screen.dart';
import 'package:tatislam_app/core/constants/app_localizations.dart';
import 'package:tatislam_app/core/constants/app_colors.dart';
import 'package:tatislam_app/core/providers/text_scale_provider.dart';
import 'package:tatislam_app/core/utils/date_format.dart';
import 'package:tatislam_app/core/utils/responsive.dart';
import 'package:tatislam_app/features/publications/domain/entities/publication.dart';
import 'package:tatislam_app/features/publications/presentation/providers/publications_providers.dart';
import 'package:tatislam_app/features/publications/presentation/widgets/app_background.dart';
import 'package:tatislam_app/features/sections/data/section_providers.dart';
import 'package:tatislam_app/features/sections/domain/entities/section.dart';
import 'package:tatislam_app/features/sections/presentation/providers/selected_section_provider.dart';
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
    final sections = ref.watch(sectionsProvider);
    final publicationsAsync = ref.watch(mainPublicationsProvider);
    final showFavoritesOnly = ref.watch(favoritesFilterProvider);
    final selectedSection = ref.watch(selectedSectionProvider);

    final backgroundPath = selectedSection?.backgroundImage;

    return PopScope(
      canPop: false,
      child: Stack(
        children: [
          AppBackground(imagePath: backgroundPath),
          Scaffold(
            backgroundColor: Colors.transparent,
            appBar: PreferredSize(
              preferredSize: const Size.fromHeight(kToolbarHeight),
              child: ClipRRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: _glassBlur,
                    sigmaY: _glassBlur,
                  ),
                  child: AppBar(
                    backgroundColor: Colors.white.withValues(
                      alpha: _glassOpacity,
                    ),
                    titleSpacing: 0,
                    title: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Logo — identical glass style
                        GestureDetector(
                          onTap: () {
                            GoRouter.of(context).push('/about');
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: _glassBox(),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(
                                  _glassRadius - 1,
                                ),
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
                                color: Colors.white.withValues(
                                  alpha: _glassOpacity,
                                ),
                                borderRadius: BorderRadius.circular(
                                  _glassRadius,
                                ),
                                border: Border.all(
                                  color: _isSearchFocused
                                      ? const Color(
                                          0xFFD4A843,
                                        ).withValues(alpha: 0.6)
                                      : _glassBorderColor.withValues(
                                          alpha: _glassBorderOpacity,
                                        ),
                                  width: _isSearchFocused
                                      ? 1.2
                                      : _glassBorderWidth,
                                ),
                              ),
                              child: TextField(
                                controller: _searchController,
                                focusNode: _searchFocusNode,
                                decoration: InputDecoration(
                                  hintText: AppLocalizations.of(ref).searchHint,
                                  hintStyle: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: Colors.white.withValues(
                                          alpha: 0.85,
                                        ),
                                      ),
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  filled: false,
                                  fillColor: Colors.transparent,
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                    horizontal: 12,
                                  ),
                                  suffixIcon: _searchController.text.isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(
                                            Icons.clear,
                                            size: 18,
                                            color: Colors.white70,
                                          ),
                                          onPressed: _clearSearch,
                                        )
                                      : null,
                                ),
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(color: const Color(0xFFF8F7F2)),
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
                              showFavoritesOnly
                                  ? Icons.star
                                  : Icons.star_border,
                              color: showFavoritesOnly
                                  ? Colors.amber
                                  : Colors.white.withValues(alpha: 0.85),
                              size: 20,
                            ),
                            tooltip: showFavoritesOnly
                                ? AppLocalizations.of(ref).showAll
                                : AppLocalizations.of(ref).showFavorites,
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
                await ref.read(mainPublicationsProvider.notifier).refresh();
                await ref.read(sectionsProvider.notifier).refresh();
                ref.invalidate(favoritesProvider);
                await ref.read(favoritesProvider.future);
              },
              child: Column(
                children: [
                  _buildSectionFilters(ref, sections),
                  const SizedBox(height: 12),
                  Expanded(
                    child: _buildPublicationsGrid(
                      context,
                      ref,
                      publicationsAsync,
                      hasLocalSections: sections.isNotEmpty,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionFilters(WidgetRef ref, List<Section> sections) {
    final selectedSection = ref.watch(selectedSectionProvider);
    final textScale = ref.watch(textScaleProvider).scale;
    final scale = ResponsiveBreakpoints.glassScale(context);

    if (sections.isEmpty) {
      return const SizedBox.shrink();
    }

    // Height adapts to both device size and text scale so chips don't clip
    final chipH = (40 * scale * (0.5 + textScale * 0.5)).clamp(36.0, 60.0);
    final chipHoriPad = (14 * scale).clamp(12.0, 20.0);

    return SizedBox(
      height: chipH + 8,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        children: [
          _buildFilterChip(
            label: AppLocalizations.of(ref).allSections,
            selected: selectedSection == null,
            onSelected: (selected) {
              ref.read(selectedSectionProvider.notifier).state = null;
            },
            height: chipH,
            horizontalPadding: chipHoriPad,
          ),
          const SizedBox(width: 8),
          ...sections.map(
            (section) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _buildFilterChip(
                label: section.name,
                selected: selectedSection?.id == section.id,
                onSelected: (selected) {
                  ref.read(selectedSectionProvider.notifier).state = selected
                      ? section
                      : null;
                },
                height: chipH,
                horizontalPadding: chipHoriPad,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool selected,
    required ValueChanged<bool> onSelected,
    double height = 40,
    double horizontalPadding = 14,
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
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: 0,
              ),
              height: height,
              alignment: Alignment.center,
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
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: selected ? Colors.black87 : Colors.white,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPublicationsGrid(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<PublicationsPage> publicationsAsync, {
    required bool hasLocalSections,
  }) {
    // First load (no previous data) — show a centered spinner.
    if (publicationsAsync.isLoading && publicationsAsync.value == null) {
      return const Center(child: CircularProgressIndicator());
    }

    // A full error with no data to fall back on.
    if (publicationsAsync.hasError && publicationsAsync.value == null) {
      return _buildGridError(context, ref, hasLocalSections);
    }

    final page =
        publicationsAsync.value ?? const PublicationsPage(items: [], hasMore: false);

    // While a background refresh is in flight we still have data — render the
    // grid (new data will land when the refresh completes) so the user never
    // sees a blank screen.
    return _buildGrid(context, ref, page);
  }

  Widget _buildGrid(
    BuildContext context,
    WidgetRef ref,
    PublicationsPage page,
  ) {
    // Inject synthetic admin card when searching for "admin"
    final query = ref.watch(searchQueryProvider);
    final showAdminCard = query.trim().toLowerCase() == 'admin';
    final displayList = showAdminCard
        ? [
            Publication(
              id: 'admin_access',
              title: 'Панель администратора',
              type: 'admin',
              publishedAt: DateTime.now(),
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
              primarySectionId: '',
            ),
            ...page.items,
          ]
        : page.items;
    final hasMore = page.hasMore;

    if (displayList.isEmpty) {
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
                AppLocalizations.of(ref).noPublicationsFound,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
      );
    }

    // Determine grid columns and aspect ratio based on breakpoint
    final isTablet = ResponsiveBreakpoints.isTablet(context);
    final isLandscape = ResponsiveBreakpoints.isCompactLandscape(context);
    final availableWidth = ResponsiveBreakpoints.layoutWidth(context) - 32;
    final cardMinWidth = isTablet ? 280.0 : (isLandscape ? 200.0 : 160.0);
    final cols = (availableWidth / cardMinWidth).floor().clamp(2, 4);
    // Base aspect ratio (width/height) for the card grid.
    // Taller cards on mobile, more compact on landscape/tablet.
    // Reduced by ~10% to give more room for 3-line titles.
    final baseAspectRatio = isTablet ? 0.75 : (isLandscape ? 0.85 : 0.78);
    // Scale aspect ratio inversely with text size so cards grow taller
    // when text is larger, preventing overflow.
    final textScale = ref.watch(textScaleProvider).scale;
    final aspectRatio = baseAspectRatio / (0.5 + textScale * 0.5);

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        // Pre-load the next page shortly before reaching the bottom.
        if (hasMore &&
            notification.metrics.extentAfter < 400 &&
            notification.metrics.axisDirection == AxisDirection.down) {
          ref.read(mainPublicationsProvider.notifier).loadMore();
        }
        return false;
      },
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: GridView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cols,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: aspectRatio,
            ),
            itemCount: displayList.length + (hasMore ? 1 : 0),
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) {
              if (index >= displayList.length) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                  ),
                );
              }
              final publication = displayList[index];
              return _PublicationCard(publication: publication, index: index);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildGridError(
    BuildContext context,
    WidgetRef ref,
    bool hasLocalSections,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 64),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: AppColors.error),
            const SizedBox(height: 16),
            Text(
              hasLocalSections
                  ? AppLocalizations.of(ref).errorLoading
                  : AppLocalizations.of(ref).needInternetForFirstLoad,
              textAlign: TextAlign.center,
            ),
            if (hasLocalSections) ...[
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(mainPublicationsProvider),
                child: Text(AppLocalizations.of(ref).retry),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PublicationCard extends ConsumerWidget {
  final Publication publication;
  final int index;

  const _PublicationCard({required this.publication, required this.index});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFavorite = ref.watch(favoritesIsFavoriteProvider(publication.id));
    final textScale = ref.watch(textScaleProvider).scale;
    // Scale bottom padding and spacing with text size so cards don't overflow
    final bottomPadding = (14 * (0.5 + textScale * 0.5)).clamp(14.0, 24.0);
    final titleDateSpacing = (6 * (0.5 + textScale * 0.5)).clamp(6.0, 12.0);
    final isPhoto =
        publication.type == 'photo' && publication.photoPath != null;

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
          if (publication.type == 'admin') {
            GoRouter.of(context).go('/login');
          } else if (isPhoto) {
            final mediaStorage = ref.read(mediaStorageRepositoryProvider);
            final photoPath = publication.photoPath!;
            Navigator.of(context).push(
              PageRouteBuilder(
                // Fade transition with a transparent background — the
                // default Material zoom transition flashes a white frame
                // while the route is being built.
                opaque: false,
                transitionDuration: const Duration(milliseconds: 200),
                reverseTransitionDuration: const Duration(milliseconds: 150),
                pageBuilder: (context, animation, secondaryAnimation) =>
                    ImageViewerScreen(
                  imageUrl: mediaStorage.publicUrlFor(photoPath),
                  fileName: photoPath.split('/').last,
                ),
                transitionsBuilder: (
                  context,
                  animation,
                  secondaryAnimation,
                  child,
                ) => FadeTransition(opacity: animation, child: child),
              ),
            );
          } else {
            GoRouter.of(
              context,
            ).push('/publication/${publication.id}?source=catalog');
          }
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
              child: isPhoto
                  ? _buildPhotoBody(context, ref, isFavorite)
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                  // Icon area
                  Transform.translate(
                    offset: const Offset(0, -8),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Center(
                        child: Image.asset(
                          AppIcons.pathOrDefault(publication.icon),
                          width: 140,
                          height: 140,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(12, 0, 12, bottomPadding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          publication.title,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: const Color(0xFFFEFEF7),
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                        SizedBox(height: titleDateSpacing),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              formatRelativeDate(publication.publishedAt),
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.85),
                                  ),
                            ),
                            GestureDetector(
                              onTap: () async {
                                final toggleFavorite = ref.read(
                                  toggleFavoriteProvider,
                                );
                                await toggleFavorite(publication.id);
                                Future.microtask(() {
                                  ref.invalidate(favoritesProvider);
                                  ref.invalidate(mainPublicationsProvider);
                                });
                              },
                              child: Icon(
                                isFavorite ? Icons.star : Icons.star_border,
                                color: isFavorite
                                    ? Colors.amber
                                    : Colors.white.withValues(alpha: 0.70),
                                size: 20,
                              ),
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

  /// Renders a photo card: the photo fills the fixed-size rectangle while
  /// preserving its original aspect ratio (BoxFit.contain letterboxes it), with
  /// the favorite star overlaid on top. Tapping the star toggles the favorite;
  /// taps anywhere else fall through to the outer card's onTap (fullscreen
  /// viewer).
  Widget _buildPhotoBody(
    BuildContext context,
    WidgetRef ref,
    bool isFavorite,
  ) {
    final mediaStorage = ref.read(mediaStorageRepositoryProvider);
    final imageUrl = mediaStorage.publicUrlFor(publication.photoPath!);

    Widget buildImage({required BoxFit fit}) {
      return CachedNetworkImage(
        imageUrl: imageUrl,
        fit: fit,
        fadeInDuration: const Duration(milliseconds: 300),
        fadeInCurve: Curves.easeIn,
        placeholder: (context, url) => Container(
          width: double.infinity,
          color: Colors.transparent,
          child: const Center(
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: AppColors.gold,
            ),
          ),
        ),
        errorWidget: (context, url, error) => const Center(
          child: Icon(
            Icons.broken_image,
            color: Colors.white,
            size: 48,
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        children: [
          // Blurred cover backdrop — fills the whole card so letterboxed
          // areas never show the empty glass background.
          Positioned.fill(
            child: SizedBox.expand(
              child: buildImage(fit: BoxFit.cover),
            ),
          ),
          // Dim + blur overlay for a softer, pleasant look.
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                width: double.infinity,
                color: Colors.black.withValues(alpha: 0.28),
              ),
            ),
          ),
          // The actual photo, preserving its original aspect ratio, inset
          // from the card edges and softly rounded.
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: buildImage(fit: BoxFit.contain),
              ),
            ),
          ),
          // Favorite star overlay — its own tap handler takes precedence.
          Positioned(
            top: 8,
            right: 8,
            child: GestureDetector(
              onTap: () async {
                final toggleFavorite = ref.read(toggleFavoriteProvider);
                await toggleFavorite(publication.id);
                Future.microtask(() {
                  ref.invalidate(favoritesProvider);
                  ref.invalidate(mainPublicationsProvider);
                });
              },
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.35),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.30),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Icon(
                  isFavorite ? Icons.star : Icons.star_border,
                  color: isFavorite
                      ? Colors.amber
                      : Colors.white.withValues(alpha: 0.90),
                  size: 20,
                ),
              ),
            ),
          ),
        ],
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

class _TapScaleState extends State<_TapScale>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scale = Tween(
      begin: 1.0,
      end: 0.98,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
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
        builder: (context, child) =>
            Transform.scale(scale: _scale.value, child: child),
        child: widget.child,
      ),
    );
  }
}
