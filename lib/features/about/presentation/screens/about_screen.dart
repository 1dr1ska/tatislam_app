import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tatislam_app/core/constants/app_localizations.dart';
import 'package:tatislam_app/core/constants/app_strings.dart';
import 'package:tatislam_app/core/providers/locale_provider.dart';
import 'package:tatislam_app/core/providers/text_scale_provider.dart';
import 'package:tatislam_app/core/utils/responsive.dart';
import 'package:tatislam_app/features/auth/providers/auth_provider.dart';
import 'package:tatislam_app/features/publications/presentation/widgets/app_background.dart';
import 'package:url_launcher/url_launcher.dart';

/// Glassmorphism constants matching the app design system.
const double _glassBlur = 18;
const double _glassOpacity = 0.40;
const double _glassBorderOpacity = 0.30;
const double _glassBorderWidth = 0.8;
const double _glassRadius = 16;
const double _cardPadding = 14;
const double _sectionSpacing = 16;
const Color _goldAccent = Color(0xFFE0B84A);

/// Data model for a link/contact card.
class _LinkItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final String url;
  final bool isEmail;

  const _LinkItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.url,
    this.isEmail = false,
  });
}

class AboutScreen extends ConsumerStatefulWidget {
  const AboutScreen({super.key});

  @override
  ConsumerState<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends ConsumerState<AboutScreen> {
  Future<void> _launchUrl(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!launched) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AppLocalizations.of(ref).errorLoading)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = ref.watch(isAdminProvider);

    return Stack(
      children: [
        const AppBackground(),
        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(48),
            child: ClipRRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: AppBar(
                  backgroundColor: Colors.white.withValues(alpha: 0.22),
                  titleSpacing: 0,
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => GoRouter.of(context).pop(),
                  ),
                  title: Text(
                    AppLocalizations.of(ref).aboutScreenTitle,
                    style: const TextStyle(
                      color: Color(0xFFF8F7F2),
                      fontWeight: FontWeight.w600,
                      fontSize: 17,
                    ),
                  ),
                ),
              ),
            ),
          ),
          body: SafeArea(child: _buildBody(context, isAdmin)),
        ),
      ],
    );
  }

  Widget _buildBody(BuildContext context, bool isAdmin) {
    final isLandscape =
        ResponsiveBreakpoints.isCompactLandscape(context) ||
        ResponsiveBreakpoints.isTablet(context);

    if (isLandscape) {
      return _buildLandscapeLayout(context, isAdmin);
    }

    return _buildPortraitLayout(context, isAdmin);
  }

  Widget _buildPortraitLayout(BuildContext context, bool isAdmin) {
    final textScale = ref.watch(textScaleProvider);
    final scale = textScale.scale;
    // Increase vertical spacing when text is larger
    final spacing = (_sectionSpacing * (1.0 + (scale - 1.0) * 0.5)).clamp(
      _sectionSpacing,
      32.0,
    );
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTextScaleSettings(context),
          SizedBox(height: spacing),
          _buildLogoSection(isAdmin),
          SizedBox(height: spacing),
          _buildDescriptionCard(),
          SizedBox(height: spacing),
          _buildFeaturesSection(),
          SizedBox(height: spacing),
          _buildLinksSection(),
          SizedBox(height: spacing),
          _buildContactsSection(),
          SizedBox(height: spacing),
          _buildFooter(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildLandscapeLayout(BuildContext context, bool isAdmin) {
    final textScale = ref.watch(textScaleProvider);
    final scale = textScale.scale;
    // Increase vertical spacing when text is larger
    final spacing = (_sectionSpacing * (1.0 + (scale - 1.0) * 0.5)).clamp(
      _sectionSpacing,
      32.0,
    );
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTextScaleSettings(context),
              SizedBox(height: spacing),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left column: logo + version
                  Expanded(
                    flex: 1,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 32),
                      child: Column(children: [_buildLogoSection(isAdmin)]),
                    ),
                  ),
                  const SizedBox(width: 24),
                  // Right column: description, features, links, contacts
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDescriptionCard(),
                        SizedBox(height: spacing),
                        _buildFeaturesSection(),
                        SizedBox(height: spacing),
                        _buildLinksSection(),
                        SizedBox(height: spacing),
                        _buildContactsSection(),
                        SizedBox(height: spacing),
                        _buildFooter(),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogoSection(bool isAdmin) {
    final scale = ref.watch(textScaleProvider).scale;
    return Column(
      children: [
        GestureDetector(
          onTap: () {
            if (isAdmin) {
              GoRouter.of(context).go('/admin');
            }
          },
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _goldAccent.withValues(alpha: 0.20),
                  blurRadius: 16,
                  spreadRadius: 3,
                ),
              ],
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/images/app_icon.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          AppLocalizations.of(ref).version(AppStrings.appVersion),
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.80),
            fontSize: (14 * scale).roundToDouble(),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildDescriptionCard() {
    final scale = ref.watch(textScaleProvider).scale;
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: _buildGlassCard(
          child: Text(
            AppLocalizations.of(ref).appDescription,
            style: TextStyle(
              color: const Color(0xFF1A1A2E).withValues(alpha: 0.90),
              fontSize: (14 * scale).roundToDouble(),
              height: 1.55,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeaturesSection() {
    final scale = ref.watch(textScaleProvider).scale;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(ref).features,
          style: TextStyle(
            color: const Color(0xFFF8F7F2),
            fontSize: (16 * scale).roundToDouble(),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildFeatureCard(
                icon: Icons.headphones,
                label: AppLocalizations.of(ref).featureAudio,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildFeatureCard(
                icon: Icons.play_circle_filled,
                label: AppLocalizations.of(ref).featureVideo,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildFeatureCard(
                icon: Icons.article,
                label: AppLocalizations.of(ref).featureArticles,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildFeatureCard(
                icon: Icons.search,
                label: AppLocalizations.of(ref).featureSearch,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildFeatureCard(
                icon: Icons.star,
                label: AppLocalizations.of(ref).featureFavorites,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildFeatureCard(
                icon: Icons.filter_alt,
                label: AppLocalizations.of(ref).featureFilters,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLinksSection() {
    final scale = ref.watch(textScaleProvider).scale;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(ref).links,
          style: TextStyle(
            color: const Color(0xFFF8F7F2),
            fontSize: (16 * scale).roundToDouble(),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        _buildLinkCard(
          item: _LinkItem(
            icon: Icons.language,
            title: AppLocalizations.of(ref).linkOurSite,
            subtitle: 'tatislam.com',
            url: 'https://tatislam.com',
          ),
        ),
        const SizedBox(height: 10),
        _buildLinkCard(
          item: _LinkItem(
            icon: Icons.play_circle_filled,
            title: AppLocalizations.of(ref).linkYouTube,
            subtitle: 'youtube.com/channel/UCyoQBRnx-UU2gBPPFjU1hIw',
            url: 'https://www.youtube.com/channel/UCyoQBRnx-UU2gBPPFjU1hIw',
          ),
        ),
        const SizedBox(height: 10),
        _buildLinkCard(
          item: _LinkItem(
            icon: Icons.ondemand_video,
            title: AppLocalizations.of(ref).linkRuTube,
            subtitle: 'rutube.ru/channel/38324482',
            url: 'https://rutube.ru/channel/38324482',
          ),
        ),
        const SizedBox(height: 10),
        _buildLinkCard(
          item: _LinkItem(
            icon: Icons.people_alt,
            title: AppLocalizations.of(ref).linkVK,
            subtitle: 'vk.com/tat_islam_com',
            url: 'https://vk.com/tat_islam_com',
          ),
        ),
        const SizedBox(height: 10),
        _buildLinkCard(
          item: _LinkItem(
            icon: Icons.chat,
            title: AppLocalizations.of(ref).linkBip,
            subtitle: 'bip.ai/join/tatislam',
            url: 'https://bip.ai/join/tatislam',
          ),
        ),
        const SizedBox(height: 10),
        _buildLinkCard(
          item: _LinkItem(
            icon: Icons.forum,
            title: AppLocalizations.of(ref).linkMax,
            subtitle: 'max.ru/join/W0hU3jNSKOSno',
            url: 'https://max.ru/join/W0hU3jNSKOSno',
          ),
        ),
        const SizedBox(height: 10),
        _buildLinkCard(
          item: _LinkItem(
            icon: Icons.telegram,
            title: AppLocalizations.of(ref).linkTelegram,
            subtitle: 't.me/tatislam',
            url: 'https://t.me/tatislam',
          ),
        ),
      ],
    );
  }

  Widget _buildContactsSection() {
    final scale = ref.watch(textScaleProvider).scale;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(ref).contacts,
          style: TextStyle(
            color: const Color(0xFFF8F7F2),
            fontSize: (16 * scale).roundToDouble(),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        _buildLinkCard(
          item: const _LinkItem(
            icon: Icons.email,
            title: 'Email',
            subtitle: 'faizr@inbox.ru',
            url: 'faizr@inbox.ru',
            isEmail: true,
          ),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    final scale = ref.watch(textScaleProvider).scale;
    return Center(
      child: Text(
        '© 2026 ТАТИСЛАМ.',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.60),
          fontSize: (13 * scale).roundToDouble(),
        ),
      ),
    );
  }

  /// Builds a generic glassmorphism container.
  Widget _buildGlassCard({required Widget child}) {
    final scale = ref.watch(textScaleProvider).scale;
    final padding = (_cardPadding * (1.0 + (scale - 1.0) * 0.5)).clamp(
      _cardPadding,
      24.0,
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(_glassRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: _glassBlur, sigmaY: _glassBlur),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: _glassOpacity),
            borderRadius: BorderRadius.circular(_glassRadius),
            border: Border.all(
              color: Colors.white.withValues(alpha: _glassBorderOpacity),
              width: _glassBorderWidth,
            ),
          ),
          padding: EdgeInsets.all(padding),
          child: child,
        ),
      ),
    );
  }

  /// Builds the settings section — text size + interface language.
  /// On wide screens (>= 600px) uses two columns: left = text size, right = language.
  /// On narrow screens falls back to vertical layout.
  Widget _buildTextScaleSettings(BuildContext context) {
    final textScale = ref.watch(textScaleProvider);
    final appLocale = ref.watch(localeProvider);
    final t = AppLocalizations.fromLocale(appLocale);
    final scale = textScale.scale;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t.settings,
          style: TextStyle(
            color: const Color(0xFFF8F7F2),
            fontSize: (16 * scale).roundToDouble(),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 600;
            return _buildGlassCard(
              child: isWide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left column: Text size
                        Expanded(
                          child: _buildTextSizeColumn(
                            textScale,
                            appLocale,
                            scale,
                          ),
                        ),
                        const SizedBox(width: 24),
                        // Right column: Interface language
                        Expanded(
                          child: _buildLanguageColumn(
                            appLocale,
                            scale,
                          ),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLanguageColumn(appLocale, scale),
                        const SizedBox(height: 8),
                        const Divider(color: Color(0x1A1A1A2E)),
                        const SizedBox(height: 8),
                        _buildTextSizeColumn(textScale, appLocale, scale),
                      ],
                    ),
            );
          },
        ),
      ],
    );
  }

  /// Column with interface language radio buttons.
  Widget _buildLanguageColumn(AppLocale appLocale, double scale) {
    final t = AppLocalizations.fromLocale(appLocale);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t.interfaceLanguage,
          style: TextStyle(
            color: const Color(0xFF1A1A2E).withValues(alpha: 0.90),
            fontSize: (14 * scale).roundToDouble(),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        ...AppLocale.values.map((locale) {
          final isSelected = appLocale == locale;
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: GestureDetector(
              onTap: () =>
                  ref.read(localeProvider.notifier).setLocale(locale),
              child: Row(
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected
                            ? _goldAccent
                            : Colors.grey.shade400,
                        width: 2,
                      ),
                    ),
                    child: isSelected
                        ? Center(
                            child: Container(
                              width: 12,
                              height: 12,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: _goldAccent,
                              ),
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    locale.displayName(appLocale),
                    style: TextStyle(
                      color: const Color(
                        0xFF1A1A2E,
                      ).withValues(alpha: 0.85),
                      fontSize: (14 * scale).roundToDouble(),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  /// Column with text size radio buttons.
  Widget _buildTextSizeColumn(
    TextScaleLevel textScale,
    AppLocale appLocale,
    double scale,
  ) {
    final t = AppLocalizations.fromLocale(appLocale);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t.textSize,
          style: TextStyle(
            color: const Color(0xFF1A1A2E).withValues(alpha: 0.90),
            fontSize: (14 * scale).roundToDouble(),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        ...TextScaleLevel.values.map((level) {
          final isSelected = textScale == level;
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: GestureDetector(
              onTap: () =>
                  ref.read(textScaleProvider.notifier).setScale(level),
              child: Row(
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected
                            ? _goldAccent
                            : Colors.grey.shade400,
                        width: 2,
                      ),
                    ),
                    child: isSelected
                        ? Center(
                            child: Container(
                              width: 12,
                              height: 12,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: _goldAccent,
                              ),
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    level.displayName(appLocale),
                    style: TextStyle(
                      color: const Color(
                        0xFF1A1A2E,
                      ).withValues(alpha: 0.85),
                      fontSize: (14 * scale).roundToDouble(),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  /// Builds a small feature card with a gold icon and label.
  Widget _buildFeatureCard({required IconData icon, required String label}) {
    final scale = ref.watch(textScaleProvider).scale;
    final vPadding = (16 * (1.0 + (scale - 1.0) * 0.5)).clamp(16.0, 22.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.25),
              width: 0.8,
            ),
          ),
          padding: EdgeInsets.symmetric(vertical: vPadding, horizontal: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: _goldAccent, size: 34),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  color: const Color(0xFFF8F7F2),
                  fontSize: (12 * scale).roundToDouble(),
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds a glass link/contact card with icon, title, subtitle, and arrow.
  Widget _buildLinkCard({required _LinkItem item}) {
    final scale = ref.watch(textScaleProvider).scale;
    final vPadding = (12 * (1.0 + (scale - 1.0) * 0.5)).clamp(12.0, 18.0);
    return GestureDetector(
      onTap: () =>
          _launchUrl(context, item.isEmail ? 'mailto:${item.url}' : item.url),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.25),
                width: 0.8,
              ),
            ),
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: vPadding),
            child: Row(
              children: [
                Icon(item.icon, color: _goldAccent, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: TextStyle(
                          color: const Color(0xFFF8F7F2),
                          fontSize: (15 * scale).roundToDouble(),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.subtitle,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.70),
                          fontSize: (12 * scale).roundToDouble(),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: _goldAccent.withValues(alpha: 0.70),
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
