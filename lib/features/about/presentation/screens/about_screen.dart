import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tatislam_app/core/constants/app_colors.dart';
import 'package:tatislam_app/core/constants/app_strings.dart';
import 'package:tatislam_app/features/auth/providers/auth_provider.dart';
import 'package:url_launcher/url_launcher.dart';

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
        ).showSnackBar(SnackBar(content: Text(AppStrings.errorLoading)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = ref.watch(isAdminProvider);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // App Icon at the top — tap to open admin if authorized
          Center(
            child: GestureDetector(
              onTap: () {
                if (isAdmin) {
                  GoRouter.of(context).go('/admin');
                }
              },
              child: Container(
                width: 120,
                height: 120,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                ),
                child: const CircleAvatar(
                  radius: 56,
                  backgroundColor: Colors.black,
                  backgroundImage: AssetImage('assets/images/app_icon.png'),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Center(child: RichText(text: AppStrings.getColoredAppName())),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'v${AppStrings.appVersion}',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
            ),
          ),
          const SizedBox(height: 32),

          // Description
          Text(
            AppStrings.appDescription,
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.justify,
          ),
          const SizedBox(height: 32),

          // Features
          Text(
            'Приложение мөмкинлекләре:',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildFeatureItem(
            context,
            Icons.home,
            'Баш бит',
            'Соңгы язмаларны уңайлы карау',
            AppColors.navHome,
          ),
          _buildFeatureItem(
            context,
            Icons.book,
            'Каталог',
            'Төрләре буенча бүленгән барлык язмалар',
            AppColors.navCatalog,
          ),
          _buildFeatureItem(
            context,
            Icons.search,
            'Эзләргә',
            'Исеме, тасвирламасы һәм эчтәлеге буенча эзләү',
            AppColors.navSearch,
          ),
          _buildFeatureItem(
            context,
            Icons.star,
            'Сайланганнар',
            'Язмаларны соңрак уку өчен саклагыз',
            Colors.amber,
          ),
          const SizedBox(height: 32),

          // Links
          Text(
            'Ссылки:',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildLinkItem(
            context,
            Icons.language,
            'Безнең сайт',
            'tatislam.com',
            'https://tatislam.com',
            AppColors.website,
          ),
          _buildLinkItem(
            context,
            Icons.play_circle_filled,
            'YouTube каналы',
            'youtube.com/channel/UCyoQBRnx-UU2gBPPFjU1hIw',
            'https://www.youtube.com/channel/UCyoQBRnx-UU2gBPPFjU1hIw',
            AppColors.youtube,
          ),
          _buildLinkItem(
            context,
            Icons.ondemand_video,
            'RuTube каналы',
            'rutube.ru/channel/38324482',
            'https://rutube.ru/channel/38324482',
            AppColors.rutube,
          ),
          _buildLinkItem(
            context,
            Icons.people_alt,
            'ВКонтакте',
            'vk.com/tat_islam_com',
            'https://vk.com/tat_islam_com',
            AppColors.vkontakte,
          ),
          _buildLinkItem(
            context,
            Icons.chat,
            'Бип',
            'bip.ai/join/tatislam',
            'https://bip.ai/join/tatislam',
            AppColors.bip,
          ),
          _buildLinkItem(
            context,
            Icons.forum,
            'Макс',
            'max.ru/join/W0hU3jNSKOSno',
            'https://max.ru/join/W0hU3jNSKOSno',
            AppColors.max,
          ),
          _buildLinkItem(
            context,
            Icons.telegram,
            'Telegram каналы',
            't.me/tatislam',
            'https://t.me/tatislam',
            AppColors.telegram,
          ),
          const SizedBox(height: 32),

          // Contact
          Text(
            'Контактлар:',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildContactItem(
            context,
            Icons.email,
            'Email',
            'faizr@inbox.ru',
            AppColors.email,
          ),
          const SizedBox(height: 32),

          // Footer
          // Барлык хокуклар сакланган.
          Text(
            '© 2026 ${AppStrings.appName}.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(
    BuildContext context,
    IconData icon,
    String title,
    String description,
    Color iconColor,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: iconColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                ),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLinkItem(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    String url,
    Color iconColor,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon, color: iconColor),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: Icon(Icons.chevron_right, color: iconColor),
        onTap: () => _launchUrl(context, url),
      ),
    );
  }

  Widget _buildContactItem(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    Color iconColor,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon, color: iconColor),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: Icon(Icons.chevron_right, color: iconColor),
        onTap: () => _launchUrl(context, 'mailto:$subtitle'),
      ),
    );
  }
}
