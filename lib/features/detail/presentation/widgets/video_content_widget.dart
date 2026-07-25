import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:chewie/chewie.dart';
import 'package:tatislam_app/core/constants/app_colors.dart';
import 'package:tatislam_app/features/detail/domain/services/video_url_parser_service.dart';
import 'package:tatislam_app/features/detail/presentation/providers/video_player_provider.dart';
import 'package:tatislam_app/features/publications/domain/entities/content_block.dart';
import 'package:tatislam_app/features/publications/domain/entities/video_provider_type.dart';

/// Renders a [VideoContentBlock] — YouTube, Rutube, or direct video URL.
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
        return _buildYouTubePlayer(context, ref, videoId, block.caption);
      }
    } else if (block.provider == VideoProviderType.rutube) {
      return _buildRuTubePlayer(context, block.url, block.caption);
    } else {
      if (urlParser.isValidUrl(block.url)) {
        return _buildDirectVideoPlayer(context, ref, block.url);
      }
    }

    return _buildUnavailable(context);
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

  Widget _buildYouTubePlayer(
    BuildContext context,
    WidgetRef ref,
    String videoId,
    String? caption,
  ) {
    final videoUrl = 'https://www.youtube.com/watch?v=$videoId';
    final videoController = ref.watch(videoPlayerProvider(videoUrl));
    if (videoController == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final chewieController = ref.watch(chewieControllerProvider(videoController));
    if (chewieController == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: Column(
        children: [
          Chewie(controller: chewieController),
          if (caption != null && caption.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(caption),
            ),
        ],
      ),
    );
  }

  Widget _buildRuTubePlayer(
    BuildContext context,
    String url,
    String? caption,
  ) {
    final videoId = urlParser.extractRutubeId(url);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: Column(
        children: [
          Container(
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.videoColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: videoId != null
                ? _buildRutubeMiniPlayer(context, videoId, url)
                : _buildRutubeFallback(context, url),
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(caption),
            ),
        ],
      ),
    );
  }

  Widget _buildRutubeMiniPlayer(
    BuildContext context,
    String videoId,
    String url,
  ) {
    return Column(
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
        const Text(
          'Нажмите для воспроизведения',
          style: TextStyle(fontSize: 14, color: Colors.grey),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: () => _showRutubePlayerDialog(context, videoId),
          child: const Text('Воспроизвести'),
        ),
      ],
    );
  }

  Widget _buildRutubeFallback(BuildContext context, String url) {
    return Column(
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
            style: const TextStyle(fontSize: 12, color: Colors.grey),
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
    );
  }

  void _showRutubePlayerDialog(BuildContext context, String videoId) {
    final embedUrl = 'https://rutube.ru/play/embed/$videoId';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Видео Rutube'),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.8,
            height: MediaQuery.of(context).size.height * 0.5,
            child: WebViewWidget(
              controller: WebViewController()
                ..setJavaScriptMode(JavaScriptMode.unrestricted)
                ..loadRequest(Uri.parse(embedUrl)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Закрыть'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDirectVideoPlayer(
    BuildContext context,
    WidgetRef ref,
    String url,
  ) {
    final videoController = ref.watch(videoPlayerProvider(url));
    if (videoController == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final chewieController = ref.watch(chewieControllerProvider(videoController));
    if (chewieController == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: Chewie(controller: chewieController),
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