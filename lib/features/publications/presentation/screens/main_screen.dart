import 'dart:math' as math;
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:tatislam_app/core/storage/storage_providers.dart';
import 'package:tatislam_app/core/widgets/network_image.dart' show appWebImageRenderMethod;
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
import 'package:tatislam_app/features/saved_publications/presentation/providers/saved_publications_providers.dart';

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
    final showSavedOnly = ref.watch(savedPublicationsFilterProvider);
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
                      // Saved-publications (offline) toggle — identical glass style
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: _glassBox(),
                          child: IconButton(
                            icon: Icon(
                              showSavedOnly
                                  ? Icons.download_done
                                  : Icons.download_outlined,
                              color: showSavedOnly
                                  ? Colors.greenAccent
                                  : Colors.white.withValues(alpha: 0.85),
                              size: 20,
                            ),
                            tooltip: showSavedOnly
                                ? AppLocalizations.of(ref).showAll
                                : AppLocalizations.of(ref).showSaved,
                            onPressed: () {
                              ref.read(toggleSavedPublicationsFilterProvider)();
                            },
                            padding: EdgeInsets.zero,
                          ),
                        ),
                      ),
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
                      showSavedOnly: showSavedOnly,
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
                label: section.localizedName(AppLocalizations.of(ref).appLocale),
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
    required bool showSavedOnly,
  }) {
    if (showSavedOnly) {
      return _buildSavedPublicationsGrid(context, ref);
    }

    // First load (no previous data) — show a centered spinner.
    if (publicationsAsync.isLoading && publicationsAsync.value == null) {
      return const Center(child: CircularProgressIndicator());
    }

    // A full error with no data to fall back on.
    if (publicationsAsync.hasError && publicationsAsync.value == null) {
      return _buildGridError(context, ref);
    }

    final page =
        publicationsAsync.value ?? const PublicationsPage(items: [], hasMore: false);

    // While a background refresh is in flight we still have data — render the
    // grid (new data will land when the refresh completes) so the user never
    // sees a blank screen.
    return _buildGrid(context, ref, page);
  }

  /// Grid of fully-saved (offline) publications shown when the saved-only
  /// filter is active. Reads only local storage — never the network — so it
  /// works even when the device is offline.
  Widget _buildSavedPublicationsGrid(BuildContext context, WidgetRef ref) {
    final publicationsAsync = ref.watch(
      savedPublicationPublicationsProvider,
    );
    // Honor the "favorites only" filter in the downloaded grid too. Built from
    // the local (Hive) favorite ids so it stays consistent with the star on
    // each card and works fully offline.
    final showFavoritesOnly = ref.watch(favoritesFilterProvider);

    return publicationsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => _buildGridError(context, ref),
      data: (publications) {
        var items = publications;
        if (showFavoritesOnly) {
          final favoriteIds = ref.watch(localFavoriteIdsProvider);
          items = publications
              .where((p) => favoriteIds.contains(p.id))
              .toList();
        }
        if (items.isEmpty) {
          return _buildSavedEmptyState(context, ref);
        }
        final page = PublicationsPage(
          items: items,
          hasMore: false,
        );
        return _buildGrid(context, ref, page, savedOnly: true);
      },
    );
  }

  Widget _buildSavedEmptyState(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(ref);
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.download_outlined,
                size: 64,
                color: Colors.white70,
              ),
              const SizedBox(height: 16),
              Text(
                t.noSavedPublications,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGrid(
    BuildContext context,
    WidgetRef ref,
    PublicationsPage page, {
    bool savedOnly = false,
  }) {
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
      // Scrollable (and pull-to-refresh friendly) even when there are no
      // results, so the user can still swipe to reload.
      return LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(
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
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    }

    // Determine grid columns based on breakpoint.
    final isTablet = ResponsiveBreakpoints.isTablet(context);
    final isLandscape = ResponsiveBreakpoints.isCompactLandscape(context);
    final effectiveWidth = math.min(
      ResponsiveBreakpoints.layoutWidth(context),
      1000.0, // the grid is capped by ConstrainedBox(maxWidth: 1000)
    );
    final availableWidth = effectiveWidth - 32;
    final cardMinWidth = isTablet ? 280.0 : (isLandscape ? 200.0 : 160.0);
    final cols = (availableWidth / cardMinWidth).floor().clamp(2, 4);
    final tileInnerWidth = availableWidth - 16.0 * (cols - 1);
    final tileWidth = tileInnerWidth / cols;

    // Fit each card's height to its actual content so tiles never leave a
    // large empty strip at the bottom. The reserved 4-line title block keeps
    // every card the same height regardless of title length.
    final textScale = ref.watch(textScaleProvider).scale;
    // Icon band grows with the tile width but is capped, so wide/large
    // screens don't waste vertical space on an oversized empty band.
    final bandHeight =
        (tileWidth * 9 / 16).clamp(56.0, 84.0).toDouble();

    final titleTheme = Theme.of(context).textTheme.titleMedium;
    final titleSize = titleTheme?.fontSize ?? 16.0; // already * textScale
    final bodySize = Theme.of(context).textTheme.bodySmall?.fontSize ?? 12.0;
    // The card renders the title with height:1.35 across up to 4 lines.
    final titleBlock = titleSize * 1.35 * 4;
    // The date row is at least as tall as the (non-scaling) star icon.
    final dateRow = math.max(20.0, bodySize * 1.5);
    final titleDateSpacing = (6 * (0.5 + textScale * 0.5))
        .clamp(6.0, 12.0)
        .toDouble();
    final bottomPad = (14 * (0.5 + textScale * 0.5))
        .clamp(14.0, 24.0)
        .toDouble();
    final reservedHeight = bandHeight +
        titleBlock +
        titleDateSpacing +
        dateRow +
        bottomPad +
        6.0; // safety buffer for font-metric differences

    // Split the list into rows of `cols`. Each row is laid out so that every
    // card in it is as tall as the tallest content in that row, and rows are
    // packed with the same 16px gap used between cards in a row. This way a
    // row containing only short titles shrinks to fit them instead of
    // reserving space for a 4-line title and leaving a big empty strip.
    final rows = <Widget>[];
    for (var i = 0; i < displayList.length; i += cols) {
      rows.add(
        _buildCardRow(
          context: context,
          ref: ref,
          items: displayList.sublist(
            i,
            math.min(i + cols, displayList.length),
          ),
          startIndex: i,
          cols: cols,
          bandHeight: bandHeight,
          photoHeight: reservedHeight,
          savedOnly: savedOnly,
        ),
      );
    }

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
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var r = 0; r < rows.length; r++) ...[
                  if (r > 0) const SizedBox(height: 16),
                  rows[r],
                ],
                if (hasMore) ...[
                  const SizedBox(height: 12),
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Lays out one grid row so all its cards are equal height (the tallest
  /// content in that row). Cards use `IntrinsicHeight` + `crossAxisAlignment:
  /// stretch` so short cards expand to match the row and there is no ragged
  /// bottom edge or extra vertical gap.
  Widget _buildCardRow({
    required BuildContext context,
    required WidgetRef ref,
    required List<Publication> items,
    required int startIndex,
    required int cols,
    required double bandHeight,
    required double photoHeight,
    required bool savedOnly,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var j = 0; j < items.length; j++) ...[
            if (j > 0) const SizedBox(width: 16),
            Expanded(
              child: _PublicationCard(
                publication: items[j],
                index: startIndex + j,
                bandHeight: bandHeight,
                photoHeight: photoHeight,
                savedOnly: savedOnly,
              ),
            ),
          ],
          // Keep cards in a trailing (partial) row the same width as full rows
          // instead of letting them stretch to fill the leftover space.
          for (var k = items.length; k < cols; k++)
            const Expanded(child: SizedBox.shrink()),
        ],
      ),
    );
  }

  Widget _buildGridError(BuildContext context, WidgetRef ref) {
    // Scrollable so the surrounding RefreshIndicator can still react to a
    // pull gesture. This is the state the user lands in when they open the
    // app offline, so it must be swipeable — otherwise re-loading after the
    // connection returns would be impossible until the widget rebuilds.
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 64),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.wifi_off,
                      size: 64,
                      color: AppColors.error,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      AppLocalizations.of(ref).errorNoInternet,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      AppLocalizations.of(ref).errorNoInternetHint,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => ref.invalidate(mainPublicationsProvider),
                      child: Text(AppLocalizations.of(ref).retry),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PublicationCard extends ConsumerWidget {
  final Publication publication;
  final int index;
  final double bandHeight;
  /// Fixed height reserved for photo cards so they keep the same footprint as
  /// text cards in the same row (a photo has no intrinsic height of its own).
  final double photoHeight;

  /// When true the card is rendered inside the saved-only grid and gets an
  /// offline ("saved to device") badge overlay.
  final bool savedOnly;

  const _PublicationCard({
    required this.publication,
    required this.index,
    required this.bandHeight,
    this.photoHeight = 120,
    this.savedOnly = false,
  });

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
        child: Stack(
          // Expand the glass so every card is a full-height panel regardless
          // of how short its title is - no trailing empty strip.
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: SizedBox.expand(
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
                        ? SizedBox(
                            height: photoHeight,
                            width: double.infinity,
                            child: _buildPhotoBody(context, ref, isFavorite),
                          )
                        : Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                  // Icon band: fixed height (capped by the grid) so wide
                  // tiles/screens don't waste space on an oversized empty band.
                  SizedBox(
                    height: bandHeight,
                    width: double.infinity,
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: Image.asset(
                        AppIcons.pathOrDefault(publication.icon),
                        width: 140,
                        height: 140,
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
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                height: 1.35,
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
        if (savedOnly)
          Positioned(
            top: 8,
            left: 8,
            child: _buildSavedBadge(ref),
          ),
      ],
      ),
      ),
    );
  }

  /// Compact badge indicating the publication is saved for offline reading,
  /// shown on cards inside the saved-only grid.
  Widget _buildSavedBadge(WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Tooltip(
        message: AppLocalizations.of(ref).showSaved,
        child: Icon(
          Icons.download_done,
          color: Colors.greenAccent,
          size: 16,
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
        imageRenderMethodForWeb: appWebImageRenderMethod,
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
