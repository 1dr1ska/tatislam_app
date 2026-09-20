import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:tatislam_app/features/detail/presentation/widgets/rutube_web_view_factory.dart';
import 'package:tatislam_app/features/detail/presentation/widgets/uploaded_video_web_view_factory.dart';
import 'package:tatislam_app/features/detail/presentation/widgets/youtube_web_view_factory.dart';
import 'package:tatislam_app/core/constants/app_localizations.dart';
import 'package:tatislam_app/core/storage/media_storage_repository.dart';
import 'package:tatislam_app/core/widgets/glass_container.dart';
import 'package:tatislam_app/features/detail/domain/services/video_url_parser_service.dart';
import 'package:tatislam_app/features/publications/domain/entities/content_block.dart';
import 'package:tatislam_app/features/publications/domain/entities/video_provider_type.dart';
import 'package:tatislam_app/features/publications/domain/entities/video_source_type.dart';
import 'package:tatislam_app/features/publications/domain/entities/local_media_resolver.dart';

const double _glassOpacity = 0.25;
const double _glassRadius = 12;

// Must match the Android applicationId in android/app/build.gradle.kts.
const String _youtubeAppReferer = 'https://com.example.tatislam_app';

class VideoContentWidget extends ConsumerStatefulWidget {
  final VideoContentBlock block;

  /// Needed to resolve [VideoContentBlock.videoPath] into a public URL when the
  /// video was uploaded to Storage ([VideoSourceType.upload]).
  final MediaStorageRepository? mediaStorage;

  /// Optional offline resolver — when it returns a local `file://` URI for
  /// [VideoContentBlock.videoPath], the uploaded video is played from that file
  /// with the native player instead of a network WebView (fully offline).
  final LocalMediaResolver? localMedia;

  final VideoUrlParserService urlParser;

  const VideoContentWidget({
    super.key,
    required this.block,
    this.mediaStorage,
    this.localMedia,
    this.urlParser = const VideoUrlParserService(),
  });

  @override
  ConsumerState<VideoContentWidget> createState() => _VideoContentWidgetState();
}

class _VideoContentWidgetState extends ConsumerState<VideoContentWidget> {
  WebViewController? _youtubeController;
  WebViewController? _rutubeController;
  WebViewController? _uploadedVideoController;

  String? _lastYoutubeId;
  String? _lastRutubeId;
  String? _lastUploadedUrl;

  String? _youtubeViewId;
  String? _rutubeViewId;
  String? _uploadedVideoViewId;

  @override
  void initState() {
    super.initState();
    _initControllers();
  }

  @override
  void didUpdateWidget(VideoContentWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    final sourceChanged =
        oldWidget.block.videoPath != widget.block.videoPath ||
            oldWidget.block.source != widget.block.source;
    if (oldWidget.block.url != widget.block.url || sourceChanged) {
      _youtubeController = null;
      _rutubeController = null;
      _uploadedVideoController = null;

      _lastYoutubeId = null;
      _lastRutubeId = null;
      _lastUploadedUrl = null;

      _youtubeViewId = null;
      _rutubeViewId = null;
      _uploadedVideoViewId = null;

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

  /// Sets up an inline player for an uploaded video (the URL is a public Storage
  /// link to the mp4). On Web — a native HTML5 `<video>`, otherwise a WebView
  /// loaded from a self-contained data: HTML page.
  void _ensureUploadedVideo(String url) {
    if (_lastUploadedUrl == url &&
        (kIsWeb
            ? _uploadedVideoViewId != null
            : _uploadedVideoController != null)) {
      return;
    }

    _lastUploadedUrl = url;

    if (kIsWeb) {
      _uploadedVideoViewId = registerUploadedVideoView(url);
    } else {
      _uploadedVideoController = _buildController(
        _videoDataUrl(url),
        headers: const <String, String>{},
      );
    }
  }

  /// Self-contained HTML with an inline `<video controls>` element.
  static String _videoDataUrl(String url) {
    final safeUrl = url.replaceAll('"', '%22').replaceAll("'", '%27');
    final html =
        '<!DOCTYPE html><html><head><meta name="viewport" '
        'content="width=device-width, initial-scale=1"></head>'
        '<body style="margin:0;background:#000">'
        '<video controls playsinline preload="metadata" '
        'style="width:100%;height:100%;object-fit:contain" '
        'src="$safeUrl"></video></body></html>';
    return 'data:text/html;base64,${base64Encode(utf8.encode(html))}';
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
    _uploadedVideoController = null;
    _youtubeViewId = null;
    _rutubeViewId = null;
    _uploadedVideoViewId = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Загруженное в Storage видео (upload): показываем inline-плеер.
    if (widget.block.source == VideoSourceType.upload) {
      final path = widget.block.videoPath ?? '';
      if (path.isEmpty || widget.mediaStorage == null) {
        return _buildUnavailable();
      }

      // Offline copy: if a downloaded local file exists for this video, play it
      // natively. Skipped on Web, where offline saving is unsupported.
      if (!kIsWeb) {
        final localUri = widget.localMedia?.call(path);
        if (localUri != null && localUri.isNotEmpty) {
          return _LocalVideoPlayer(
            uri: localUri,
            title: widget.block.videoName,
          );
        }
      }

      final url = widget.mediaStorage!.publicUrlFor(path);
      _ensureUploadedVideo(url);

      if (kIsWeb && _uploadedVideoViewId != null) {
        return _buildUploadedWebView();
      }

      if (!kIsWeb && _uploadedVideoController != null) {
        return _buildEmbeddedVideo(controller: _uploadedVideoController!);
      }

      return _buildExternalLinkCard(
        url: url,
        title: widget.block.videoName,
      );
    }

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

  Widget _buildUploadedWebView() {
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
            child: HtmlElementView(viewType: _uploadedVideoViewId!),
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

  Widget _buildExternalLinkCard({String? url, String? title}) {
    final targetUrl = url ?? widget.block.url;
    final label = title ?? AppLocalizations.of(ref).video;
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
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFD4A843),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => _launchUrl(context, targetUrl),
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

/// Plays an offline-downloaded (uploaded) video from a local `file://` URI with
/// the native [VideoPlayer], including minimal tap-to-toggle + progress
/// controls. Falls back to an "unavailable" card when the file cannot be read.
class _LocalVideoPlayer extends ConsumerStatefulWidget {
  final String uri;
  final String? title;

  const _LocalVideoPlayer({required this.uri, this.title});

  @override
  ConsumerState<_LocalVideoPlayer> createState() => _LocalVideoPlayerState();
}

class _LocalVideoPlayerState extends ConsumerState<_LocalVideoPlayer> {
  VideoPlayerController? _controller;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final uri = Uri.tryParse(widget.uri);
    if (uri == null || uri.scheme != 'file') {
      if (mounted) setState(() => _failed = true);
      return;
    }

    final controller = VideoPlayerController.file(File(uri.toFilePath()));
    _controller = controller;
    try {
      await controller.initialize();
      await controller.setLooping(false);
      await controller.setVolume(1);
      if (!mounted) return;
      await controller.play();
      setState(() {});
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Widget _buildUnavailableCard() {
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

  Widget _buildLoading() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Center(
          child: CircularProgressIndicator(
            color: Color(0xFFD4A843),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (_failed) return _buildUnavailableCard();
    if (controller == null || !controller.value.isInitialized) {
      return _buildLoading();
    }

    final aspectRatio = controller.value.aspectRatio > 0
        ? controller.value.aspectRatio
        : 16 / 9;
    final isPlaying = controller.value.isPlaying;

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
            aspectRatio: aspectRatio,
            child: Stack(
              alignment: Alignment.center,
              children: [
                VideoPlayer(controller),
                // Tap anywhere toggles play/pause.
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      setState(() {
                        isPlaying
                            ? controller.pause()
                            : controller.play();
                      });
                    },
                  ),
                ),
                // Center play/pause affordance when paused.
                if (!isPlaying)
                  Icon(
                    Icons.play_circle_fill,
                    size: 64,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                // Progress / scrubbing bar at the bottom.
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: ColoredBox(
                    color: Colors.black.withValues(alpha: 0.35),
                    child: VideoProgressIndicator(
                      controller,
                      allowScrubbing: true,
                      colors: const VideoProgressColors(
                        playedColor: Color(0xFFD4A843),
                        bufferedColor: Colors.white54,
                        backgroundColor: Colors.white12,
                      ),
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
}
