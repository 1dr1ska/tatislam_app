import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:tatislam_app/core/constants/app_colors.dart';
import 'package:tatislam_app/features/detail/domain/services/video_url_parser_service.dart';
import 'package:tatislam_app/features/publications/domain/entities/content_block.dart';
import 'package:tatislam_app/features/publications/domain/entities/video_provider_type.dart';

/// Renders a [VideoContentBlock] — YouTube or Rutube embedded via WebView,
/// or a direct URL as an external link card.
class VideoContentWidget extends ConsumerWidget {
  final VideoContentBlock block;
  final VideoUrlParserService urlParser;

  const VideoContentWidget({
    super.key,
    required this.block,
    this.urlParser = const VideoUrlParserService(),
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (block.url.isEmpty) {
      return _buildUnavailable(context);
    }

    if (block.provider == VideoProviderType.youtube) {
      final videoId = urlParser.extractYouTubeId(block.url);
      if (videoId != null) {
        return _buildEmbeddedVideo(
          context: context,
          embedUrl: 'https://www.youtube.com/embed/$videoId',
          caption: block.caption,
        );
      }
    } else if (block.provider == VideoProviderType.rutube) {
      final videoId = urlParser.extractRutubeId(block.url);
      if (videoId != null) {
        return _buildEmbeddedVideo(
          context: context,
          embedUrl: 'https://rutube.ru/play/embed/$videoId',
          caption: block.caption,
        );
      }
      // Rutube video ID not found — show fallback
      return _buildRutubeFallback(context, block.url, block.caption);
    } else {
      if (urlParser.isValidUrl(block.url)) {
        return _buildExternalLinkCard(
          context: context,
          url: block.url,
          caption: block.caption,
        );
      }
    }

    return _buildUnavailable(context);
  }

  /// Renders a video embed (YouTube or Rutube) directly in the card
  /// via WebView with proper 16:9 aspect ratio.
  Widget _buildEmbeddedVideo({
    required BuildContext context,
    required String embedUrl,
    String? caption,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: Column(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(12),
            ),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: WebViewWidget(
                controller: WebViewController()
                  ..setJavaScriptMode(JavaScriptMode.unrestricted)
                  ..setNavigationDelegate(
                    NavigationDelegate(
                      onNavigationRequest: (request) {
                        // Allow the initial embed load
                        if (request.url == embedUrl) {
                          return NavigationDecision.navigate;
                        }
                        // Open any other links (e.g. "Смотреть на RUTUBE")
                        // in the external browser
                        _launchUrl(context, request.url);
                        return NavigationDecision.prevent;
                      },
                    ),
                  )
                  ..loadRequest(Uri.parse(embedUrl)),
              ),
            ),
          ),
          if (caption != null && caption.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(caption),
            ),
        ],
      ),
    );
  }

  /// Renders a fallback card for unknown Rutube URLs — opens in browser.
  Widget _buildRutubeFallback(
    BuildContext context,
    String url,
    String? caption,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.videoColor.withValues(alpha: 0.1),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.play_circle_fill,
                    size: 64,
                    color: AppColors.videoColor,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Видео на Rutube',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.videoColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      url,
                      style:
                          const TextStyle(fontSize: 12, color: Colors.grey),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => _launchUrl(context, url),
                    child: const Text('Открыть в браузере'),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(
                  Icons.play_circle_filled,
                  color: AppColors.videoColor,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Text(
                  'Видео (Rutube)',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
          if (caption != null && caption.isNotEmpty)
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(caption),
            ),
        ],
      ),
    );
  }

  /// Renders a card for direct video URLs — opens in browser.
  Widget _buildExternalLinkCard({
    required BuildContext context,
    required String url,
    String? caption,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.videoColor.withValues(alpha: 0.1),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.play_circle_fill,
                    size: 64,
                    color: AppColors.videoColor,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Видео',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.videoColor,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => _launchUrl(context, url),
                    child: const Text('Открыть в браузере'),
                  ),
                ],
              ),
            ),
          ),
          if (caption != null && caption.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(caption),
            ),
        ],
      ),
    );
  }

  Widget _buildUnavailable(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: SizedBox(
        height: 200,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.videocam_off, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                'Видео недоступно',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _launchUrl(BuildContext context, String url) async {
    try {
      final uri = Uri.parse(url);
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
      if (await launchUrl(uri, mode: LaunchMode.platformDefault)) return;
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Не удалось открыть URL: $url\nПопробуйте открыть его вручную в браузере',
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка при открытии URL: $e')),
        );
      }
    }
  }
}