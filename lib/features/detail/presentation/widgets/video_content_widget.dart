import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:tatislam_app/features/detail/presentation/widgets/rutube_web_view_factory.dart';
import 'package:tatislam_app/core/constants/app_localizations.dart';
import 'package:tatislam_app/core/widgets/glass_container.dart';
import 'package:tatislam_app/features/detail/domain/services/video_url_parser_service.dart';
import 'package:tatislam_app/features/publications/domain/entities/content_block.dart';
import 'package:tatislam_app/features/publications/domain/entities/video_provider_type.dart';

/// Glassmorphism constants matching the design system.
const double _glassOpacity = 0.25;
const double _glassRadius = 12;

/// Renders a [VideoContentBlock] — YouTube or Rutube embedded via WebView,
/// or a direct URL as an external link card.
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

  /// Unique view ID for the HtmlElementView (web only).
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
      _rutubeViewId = null;
      _initControllers();
    }
  }

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

      if (kIsWeb) {
        // On Flutter Web, use HtmlElementView with a direct iframe.
        // webview_flutter_web uses an iframe internally, but RuTube blocks
        // embedding via X-Frame-Options. The factory is conditionally
        // imported — on non-web platforms it returns null.
        _rutubeViewId = registerRutubeView(videoId);
      } else {
        // On mobile (Android/iOS), use WebViewWidget.
        _rutubeController = _buildController(
          'https://rutube.ru/play/embed/$videoId',
        );
      }
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

  void _initControllers() {
    if (widget.block.url.isEmpty) return;

    if (widget.block.provider == VideoProviderType.youtube) {
      final videoId = widget.urlParser.extractYouTubeId(widget.block.url);
      if (videoId != null) _ensureYoutubeController(videoId);
    } else if (widget.block.provider == VideoProviderType.rutube) {
      final videoId = widget.urlParser.extractRutubeId(widget.block.url);
      if (videoId != null) _ensureRutubeController(videoId);
    }
  }

  @override
  void dispose() {
    _youtubeController = null;
    _rutubeController = null;
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
      if (videoId != null) {
        return _buildYoutubeFallback(videoId: videoId);
      }
    } else if (widget.block.provider == VideoProviderType.rutube) {
      final videoId = widget.urlParser.extractRutubeId(widget.block.url);
      if (videoId != null) {
        if (kIsWeb && _rutubeViewId != null) {
          // Flutter Web: render the HtmlElementView with the iframe.
          return _buildRutubeWebView();
        } else if (_rutubeController != null) {
          // Mobile: render the WebViewWidget.
          return _buildEmbeddedVideo(controller: _rutubeController!);
        }
      }
      return _buildRutubeFallback();
    } else {
      if (widget.urlParser.isValidUrl(widget.block.url)) {
        return _buildExternalLinkCard();
      }
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

  /// Renders a unified fallback card for YouTube on both Android and Web.
  ///
  /// YouTube's iframe embed does not work reliably inside an Android WebView
  /// (Error 153 — missing HTTP Referer). On Web the iframe may load with a
  /// VPN but fail without one. Since we cannot reliably detect the error
  /// inside Flutter, we show this fallback card that lets the user open the
  /// video directly in the YouTube app or browser.
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
                  '\u041d\u0435 \u0443\u0434\u0430\u043b\u043e\u0441\u044c \u0437\u0430\u0433\u0440\u0443\u0437\u0438\u0442\u044c \u0432\u0438\u0434\u0435\u043e YouTube',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFEFEF7),
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    '\u0412\u0438\u0434\u0435\u043e \u043c\u043e\u0436\u043d\u043e \u043e\u0442\u043a\u0440\u044b\u0442\u044c \u043d\u0430\u043f\u0440\u044f\u043c\u0443\u044e \u0432 YouTube.',
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

  /// Renders RuTube on Flutter Web using a direct HtmlElementView with iframe.
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
          ],
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
          ],
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
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
      if (await launchUrl(uri, mode: LaunchMode.platformDefault)) return;
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(ref).couldNotOpenUrl(url)),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AppLocalizations.of(ref).urlOpeningError(e.toString()))));
      }
    }
  }
}