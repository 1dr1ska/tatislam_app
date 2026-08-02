import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:tatislam_app/core/utils/responsive.dart';
import 'package:tatislam_app/features/detail/domain/services/video_url_parser_service.dart';
import 'package:tatislam_app/features/publications/domain/entities/content_block.dart';
import 'package:tatislam_app/features/publications/domain/entities/video_provider_type.dart';

/// Glassmorphism constants matching the design system.
const double _glassBlur = 12;
const double _glassOpacity = 0.25;
const double _glassBorderOpacity = 0.35;
const double _glassBorderWidth = 0.8;
const double _glassRadius = 12;

/// Renders a [VideoContentBlock] — YouTube or Rutube embedded via WebView,
/// or a direct URL as an external link card.
///
/// Uses stateful widget to cache [WebViewController] so that the embedded
/// player survives rebuilds (orientation changes, pull-to-refresh, etc.).
class VideoContentWidget extends ConsumerStatefulWidget {
  final VideoContentBlock block;
  final VideoUrlParserService urlParser;

  const VideoContentWidget({
    super.key,
    required this.block,
    this.urlParser = const VideoUrlParserService(),
  });

  @override
  ConsumerState<VideoContentWidget> createState() => _VideoContentWidgetState();
}

class _VideoContentWidgetState extends ConsumerState<VideoContentWidget> {
  /// Cached WebViewController keyed by provider+videoId so the iframe is
  /// loaded only once and survives rebuilds.
  WebViewController? _youtubeController;
  WebViewController? _rutubeController;
  String? _lastYoutubeId;
  String? _lastRutubeId;

  @override
  void initState() {
    super.initState();
    _initControllers();
  }

  @override
  void didUpdateWidget(VideoContentWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the block URL changed (e.g. editing), re-init controllers.
    if (oldWidget.block.url != widget.block.url) {
      _youtubeController = null;
      _rutubeController = null;
      _lastYoutubeId = null;
      _lastRutubeId = null;
      _initControllers();
    }
  }

  /// Lazily creates controllers only when a video of that type is first
  /// encountered on the screen.
  void _ensureYoutubeController(String videoId) {
    if (_youtubeController == null || _lastYoutubeId != videoId) {
      _lastYoutubeId = videoId;
      _youtubeController = _buildController(
        'https://www.youtube.com/embed/$videoId',
      );
    }
  }

  void _ensureRutubeController(String videoId) {
    if (_rutubeController == null || _lastRutubeId != videoId) {
      _lastRutubeId = videoId;
      _rutubeController = _buildController(
        'https://rutube.ru/play/embed/$videoId',
      );
    }
  }

  WebViewController _buildController(String embedUrl) {
    return WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            if (request.url == embedUrl) {
              return NavigationDecision.navigate;
            }
            _launchUrl(context, request.url);
            return NavigationDecision.prevent;
          },
        ),
      )
      ..loadRequest(Uri.parse(embedUrl));
  }

  /// Called once per widget lifecycle to pre-init controllers for the
  /// current block's URL.
  void _initControllers() {
    if (widget.block.url.isEmpty) return;

    if (widget.block.provider == VideoProviderType.youtube) {
      final videoId = widget.urlParser.extractYouTubeId(widget.block.url);
      if (videoId != null) {
        _ensureYoutubeController(videoId);
      }
    } else if (widget.block.provider == VideoProviderType.rutube) {
      final videoId = widget.urlParser.extractRutubeId(widget.block.url);
      if (videoId != null) {
        _ensureRutubeController(videoId);
      }
    }
  }

  @override
  void dispose() {
    // Controllers are discarded; WebView internally releases resources.
    _youtubeController = null;
    _rutubeController = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.block.url.isEmpty) {
      return _buildUnavailable(context);
    }

    if (widget.block.provider == VideoProviderType.youtube) {
      final videoId = widget.urlParser.extractYouTubeId(widget.block.url);
      if (videoId != null && _youtubeController != null) {
        return _buildEmbeddedVideo(
          context: context,
          controller: _youtubeController!,
          caption: widget.block.caption,
        );
      }
      // Fall through to fallback if no controller
    } else if (widget.block.provider == VideoProviderType.rutube) {
      final videoId = widget.urlParser.extractRutubeId(widget.block.url);
      if (videoId != null && _rutubeController != null) {
        return _buildEmbeddedVideo(
          context: context,
          controller: _rutubeController!,
          caption: widget.block.caption,
        );
      }
      // Rutube video ID not found — show fallback
      return _buildRutubeFallback(context, widget.block.url, widget.block.caption);
    } else {
      if (widget.urlParser.isValidUrl(widget.block.url)) {
        return _buildExternalLinkCard(
          context: context,
          url: widget.block.url,
          caption: widget.block.caption,
        );
      }
    }

    return _buildUnavailable(context);
  }

  /// Compact glass container wrapping the embedded video.
  /// Uses the cached [controller] so the iframe is loaded only once.
  Widget _buildEmbeddedVideo({
    required BuildContext context,
    required WebViewController controller,
    String? caption,
  }) {
    final isWide = ResponsiveBreakpoints.isTablet(context) ||
        ResponsiveBreakpoints.isCompactLandscape(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: ClipRRect(
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(_glassRadius),
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: isWide ? 400 : double.infinity,
                    ),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: WebViewWidget(controller: controller),
                    ),
                  ),
                ),
                if (caption != null && caption.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                    child: Text(
                      caption,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF2D2D44),
                        height: 1.5,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Renders a fallback card for unknown Rutube URLs — opens in browser.
  Widget _buildRutubeFallback(
    BuildContext context,
    String url,
    String? caption,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: ClipRRect(
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(_glassRadius),
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.play_circle_fill,
                          size: 56,
                          color: Color(0xFFD4A843),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Видео на Rutube',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFD4A843),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            url,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF2D2D44),
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(height: 12),
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
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                    child: Text(
                      caption,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF2D2D44),
                        height: 1.5,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Renders a card for direct video URLs — opens in browser.
  Widget _buildExternalLinkCard({
    required BuildContext context,
    required String url,
    String? caption,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: ClipRRect(
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: SizedBox(
                    width: double.infinity,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.play_circle_fill,
                          size: 56,
                          color: Color(0xFFD4A843),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Видео',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFD4A843),
                          ),
                        ),
                        const SizedBox(height: 12),
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
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                    child: Text(
                      caption,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF2D2D44),
                        height: 1.5,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUnavailable(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_glassRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: _glassBlur, sigmaY: _glassBlur),
          child: Container(
            width: double.infinity,
            height: 180,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: _glassOpacity),
              borderRadius: BorderRadius.circular(_glassRadius),
              border: Border.all(
                color: Colors.white.withValues(alpha: _glassBorderOpacity),
                width: _glassBorderWidth,
              ),
            ),
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