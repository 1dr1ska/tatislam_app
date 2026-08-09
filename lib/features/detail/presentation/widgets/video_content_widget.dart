import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:tatislam_app/features/detail/presentation/widgets/rutube_web_view_factory.dart';
import 'package:tatislam_app/features/detail/presentation/widgets/youtube_web_view_factory.dart';
import 'package:tatislam_app/core/constants/app_localizations.dart';
import 'package:tatislam_app/core/widgets/glass_container.dart';
import 'package:tatislam_app/features/detail/domain/services/video_url_parser_service.dart';
import 'package:tatislam_app/features/publications/domain/entities/content_block.dart';
import 'package:tatislam_app/features/publications/domain/entities/video_provider_type.dart';

const double _glassOpacity = 0.25;
const double _glassRadius = 12;

// Must match the Android applicationId in android/app/build.gradle.kts.
const String _youtubeAppReferer = 'https://com.example.tatislam_app';

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
  WebViewController? _youtubeController;
  WebViewController? _rutubeController;

  String? _lastYoutubeId;
  String? _lastRutubeId;

  String? _youtubeViewId;
  String? _rutubeViewId;

  @override
  void initState() {
    super.initState();
    _initControllers();
  }

  @override
  void didUpdateWidget(VideoContentWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.block.url != widget.block.url) {
      _youtubeController = null;
      _rutubeController = null;

      _lastYoutubeId = null;
      _lastRutubeId = null;

      _youtubeViewId = null;
      _rutubeViewId = null;

      _initControllers();
    }
  }

  void _ensureYoutubeController(String videoId) {
    if (_lastYoutubeId == videoId &&
        (kIsWeb ? _youtubeViewId != null : _youtubeController != null)) {
      return;
    }

    _lastYoutubeId = videoId;

    if (kIsWeb) {
      // On Web use our own iframe factory, just like RuTube.
      // Do NOT create/register the view from build().
      _youtubeViewId = registerYoutubeView(videoId);
      return;
    }

    // Android/iOS: use WebView. Android additionally sends the application
    // Referer required by YouTube for direct embed loading.
    _youtubeController = _buildController(
      'https://www.youtube.com/embed/$videoId',
      headers: const {'Referer': _youtubeAppReferer},
    );
  }

  void _ensureRutubeController(String videoId) {
    if (_lastRutubeId == videoId &&
        (kIsWeb ? _rutubeViewId != null : _rutubeController != null)) {
      return;
    }

    _lastRutubeId = videoId;

    if (kIsWeb) {
      _rutubeViewId = registerRutubeView(videoId);
    } else {
      _rutubeController = _buildController(
        'https://rutube.ru/play/embed/$videoId',
      );
    }
  }

  WebViewController _buildController(
    String embedUrl, {
    Map<String, String>? headers,
  }) {
    return WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            if (request.url == embedUrl ||
                request.url.startsWith('$embedUrl?')) {
              return NavigationDecision.navigate;
            }

            _launchUrl(context, request.url);
            return NavigationDecision.prevent;
          },
        ),
      )
      ..loadRequest(
        Uri.parse(embedUrl),
        headers: headers ?? const <String, String>{},
      );
  }

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
    _youtubeController = null;
    _rutubeController = null;
    _youtubeViewId = null;
    _rutubeViewId = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.block.url.isEmpty) {
      return _buildUnavailable();
    }

    if (widget.block.provider == VideoProviderType.youtube) {
      final videoId = widget.urlParser.extractYouTubeId(widget.block.url);

      if (videoId == null) {
        return _buildUnavailable();
      }

      if (kIsWeb && _youtubeViewId != null) {
        return _buildYoutubeWebView();
      }

      if (!kIsWeb && _youtubeController != null) {
        return _buildEmbeddedVideo(controller: _youtubeController!);
      }

      return _buildYoutubeFallback(videoId: videoId);
    }

    if (widget.block.provider == VideoProviderType.rutube) {
      final videoId = widget.urlParser.extractRutubeId(widget.block.url);

      if (videoId != null) {
        if (kIsWeb && _rutubeViewId != null) {
          return _buildRutubeWebView();
        }

        if (!kIsWeb && _rutubeController != null) {
          return _buildEmbeddedVideo(controller: _rutubeController!);
        }
      }

      return _buildRutubeFallback();
    }

    if (widget.urlParser.isValidUrl(widget.block.url)) {
      return _buildExternalLinkCard();
    }

    return _buildUnavailable();
  }

  Widget _buildEmbeddedVideo({required WebViewController controller}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GlassContainer(
        opacity: _glassOpacity,
        borderRadius: _glassRadius,
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(_glassRadius),
          ),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: WebViewWidget(controller: controller),
          ),
        ),
      ),
    );
  }

  Widget _buildYoutubeWebView() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GlassContainer(
        opacity: _glassOpacity,
        borderRadius: _glassRadius,
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(_glassRadius),
          ),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: HtmlElementView(viewType: _youtubeViewId!),
          ),
        ),
      ),
    );
  }

  Widget _buildYoutubeFallback({required String videoId}) {
    final localizations = AppLocalizations.of(ref);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GlassContainer(
        opacity: _glassOpacity,
        borderRadius: _glassRadius,
        child: AspectRatio(
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
                  size: 48,
                  color: Color(0xFFFF0000),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Не удалось загрузить видео YouTube',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFEFEF7),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Видео можно открыть напрямую в YouTube.',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFFFEFEF7),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () =>
                      _launchUrl(context, 'https://youtu.be/$videoId'),
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: Text(localizations.openInBrowser),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRutubeWebView() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GlassContainer(
        opacity: _glassOpacity,
        borderRadius: _glassRadius,
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(_glassRadius),
          ),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: HtmlElementView(viewType: _rutubeViewId!),
          ),
        ),
      ),
    );
  }

  Widget _buildRutubeFallback() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GlassContainer(
        opacity: _glassOpacity,
        borderRadius: _glassRadius,
        child: AspectRatio(
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
                Text(
                  AppLocalizations.of(ref).videoOnRutube,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFD4A843),
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    widget.block.url,
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
                  onPressed: () => _launchUrl(context, widget.block.url),
                  child: Text(AppLocalizations.of(ref).openInBrowser),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExternalLinkCard() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GlassContainer(
        opacity: _glassOpacity,
        borderRadius: _glassRadius,
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.play_circle_fill,
                size: 56,
                color: Color(0xFFD4A843),
              ),
              const SizedBox(height: 12),
              Text(
                AppLocalizations.of(ref).video,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFD4A843),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => _launchUrl(context, widget.block.url),
                child: Text(AppLocalizations.of(ref).openInBrowser),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUnavailable() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GlassContainer(
        opacity: _glassOpacity,
        borderRadius: _glassRadius,
        height: 180,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.videocam_off, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                AppLocalizations.of(ref).videoUnavailable,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(color: Colors.grey),
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

      if (await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      )) {
        return;
      }

      if (await launchUrl(
        uri,
        mode: LaunchMode.platformDefault,
      )) {
        return;
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(ref).couldNotOpenUrl(url),
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(ref).urlOpeningError(e.toString()),
            ),
          ),
        );
      }
    }
  }
}
