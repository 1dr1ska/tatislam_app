import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
const double _landscapeAspectRatio = 16 / 9;

// Must match the Android applicationId in android/app/build.gradle.kts.
const String _youtubeAppReferer = 'https://com.example.tatislam_app';

/// Playback speeds cycled through by the speed button.
const List<double> _kPlaybackSpeeds = <double>[0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

String _formatSpeed(double s) {
  if (s == s.roundToDouble()) return '${s.toInt()}x';
  return '${s}x';
}

String _formatDuration(Duration d) {
  final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

class VideoContentWidget extends ConsumerStatefulWidget {
  final VideoContentBlock block;

  /// Needed to resolve [VideoContentBlock.videoPath] into a public URL when the
  /// video was uploaded to Storage ([VideoSourceType.upload]).
  final MediaStorageRepository? mediaStorage;

  /// Optional offline resolver — when it returns a local `file://` URI for
  /// [VideoContentBlock.videoPath], the uploaded video is played from that file
  /// with the native player (fully offline).
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
    if (oldWidget.block.url != widget.block.url ||
        oldWidget.block.provider != widget.block.provider ||
        sourceChanged) {
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
      _youtubeViewId = registerYoutubeView(videoId);
      return;
    }

    _youtubeController = _buildController(
      'https://www.youtube.com/embed/$videoId?playsinline=1&rel=0',
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

  /// Web-only inline HTML5 player. On mobile we never use this — uploaded
  /// videos are played by [_NativeVideoPlayer], which letterboxes portrait
  /// and square content using the decoder's real aspect ratio and keeps its
  /// controls strictly inside the card.
  void _ensureUploadedVideo(String url) {
    if (_lastUploadedUrl == url && _uploadedVideoViewId != null) return;

    _lastUploadedUrl = url;
    _uploadedVideoViewId = registerUploadedVideoView(url);
  }

  WebViewController _buildController(
    String embedUrl, {
    Map<String, String>? headers,
  }) {
    final embedUri = Uri.parse(embedUrl);
    return WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            final requestUri = Uri.tryParse(request.url);
            if (requestUri != null &&
                requestUri.host == embedUri.host &&
                requestUri.path == embedUri.path) {
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
    // ── Uploaded video ────────────────────────────────────────────────
    if (widget.block.source == VideoSourceType.upload) {
      final path = widget.block.videoPath ?? '';
      if (path.isEmpty || widget.mediaStorage == null) {
        return _buildUnavailable();
      }

      if (!kIsWeb) {
        final localUri = widget.localMedia?.call(path);
        if (localUri != null && localUri.isNotEmpty) {
          return _NativeVideoPlayer(
            uri: localUri,
            title: widget.block.videoName,
          );
        }

        final url = widget.mediaStorage!.publicUrlFor(path);
        return _NativeVideoPlayer(uri: url, title: widget.block.videoName);
      }

      // Web: browser-native <video> with its own controls.
      final url = widget.mediaStorage!.publicUrlFor(path);
      _ensureUploadedVideo(url);
      if (_uploadedVideoViewId != null) {
        return _buildUploadedWebView();
      }

      return _buildExternalLinkCard(url: url, title: widget.block.videoName);
    }

    // ── YouTube / RuTube / external link ──────────────────────────────
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
        return _buildEmbeddedVideo(
          controller: _youtubeController!,
          contentAspectRatio: _youtubeContentAspectRatio,
        );
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

  Widget _buildEmbeddedVideo({
    required WebViewController controller,
    double aspectRatio = _landscapeAspectRatio,
    double? contentAspectRatio,
  }) {
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
            child: _buildEmbeddedPlayer(
              contentAspectRatio: contentAspectRatio,
              child: WebViewWidget(controller: controller),
            ),
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
            aspectRatio: _landscapeAspectRatio,
            child: _buildEmbeddedPlayer(
              contentAspectRatio: _youtubeContentAspectRatio,
              child: HtmlElementView(viewType: _youtubeViewId!),
            ),
          ),
        ),
      ),
    );
  }

  double? get _youtubeContentAspectRatio =>
      widget.urlParser.isYouTubeShortsUrl(widget.block.url) ? 9 / 16 : null;

  Widget _buildEmbeddedPlayer({
    required Widget child,
    double? contentAspectRatio,
  }) {
    if (contentAspectRatio == null) {
      return ColoredBox(color: Colors.black, child: child);
    }

    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: AspectRatio(
          aspectRatio: contentAspectRatio,
          child: child,
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
            aspectRatio: _landscapeAspectRatio,
            child: ColoredBox(
              color: Colors.black,
              child: HtmlElementView(viewType: _uploadedVideoViewId!),
            ),
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
          aspectRatio: _landscapeAspectRatio,
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
                    style: TextStyle(fontSize: 11, color: Color(0xFFFEFEF7)),
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
            aspectRatio: _landscapeAspectRatio,
            child: ColoredBox(
              color: Colors.black,
              child: HtmlElementView(viewType: _rutubeViewId!),
            ),
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
          aspectRatio: _landscapeAspectRatio,
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
          aspectRatio: _landscapeAspectRatio,
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

      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        return;
      }

      if (await launchUrl(uri, mode: LaunchMode.platformDefault)) {
        return;
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(ref).couldNotOpenUrl(url)),
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

/// Native player for uploaded videos. Uses the decoder's real aspect ratio,
/// letterboxes portrait / square / ultrawide content inside a fixed 16:9 card,
/// and keeps all playback controls inside the card so nothing ends up below
/// the visible rectangle.
class _NativeVideoPlayer extends ConsumerStatefulWidget {
  final String uri;
  final String? title;

  const _NativeVideoPlayer({required this.uri, this.title});

  @override
  ConsumerState<_NativeVideoPlayer> createState() => _NativeVideoPlayerState();
}

class _NativeVideoPlayerState extends ConsumerState<_NativeVideoPlayer> {
  VideoPlayerController? _controller;
  bool _failed = false;

  /// Shared with the fullscreen page so playback speed survives the
  /// transition between inline and fullscreen modes.
  final ValueNotifier<double> _speed = ValueNotifier<double>(1.0);

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final uri = Uri.tryParse(widget.uri);
    if (uri == null ||
        (uri.scheme != 'file' &&
            uri.scheme != 'http' &&
            uri.scheme != 'https')) {
      if (mounted) setState(() => _failed = true);
      return;
    }

    final controller = uri.scheme == 'file'
        ? VideoPlayerController.file(File(uri.toFilePath()))
        : VideoPlayerController.networkUrl(uri);
    _controller = controller;
    try {
      await controller.initialize();
      await controller.setLooping(false);
      await controller.setVolume(1);
      await controller.setPlaybackSpeed(_speed.value);
      controller.addListener(_onControllerChanged);
      if (!mounted) return;
      await controller.play();
      setState(() {});
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_onControllerChanged);
    _controller?.dispose();
    _speed.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _togglePlayback(VideoPlayerController controller) async {
    if (controller.value.isPlaying) {
      await controller.pause();
    } else {
      await controller.play();
    }
    if (mounted) setState(() {});
  }

  Future<void> _cycleSpeed() async {
    final controller = _controller;
    if (controller == null) return;

    final currentIndex = _kPlaybackSpeeds.indexOf(_speed.value);
    final nextIndex = (currentIndex + 1) % _kPlaybackSpeeds.length;
    final next = _kPlaybackSpeeds[nextIndex];
    _speed.value = next;
    try {
      await controller.setPlaybackSpeed(next);
    } catch (_) {
      // Some platforms reject certain speeds; keep the UI value anyway.
    }
  }

  void _openFullscreen() {
    final controller = _controller;
    if (controller == null) return;

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _FullscreenVideoPage(
          controller: controller,
          speed: _speed,
          title: widget.title,
        ),
      ),
    );
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
        aspectRatio: _landscapeAspectRatio,
        child: const ColoredBox(
          color: Colors.black,
          child: Center(
            child: CircularProgressIndicator(color: Color(0xFFD4A843)),
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

    final value = controller.value;
    final videoAspectRatio =
        value.aspectRatio > 0 ? value.aspectRatio : _landscapeAspectRatio;
    final isPlaying = value.isPlaying;

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
            aspectRatio: _landscapeAspectRatio,
            child: Stack(
              fit: StackFit.expand,
              children: [
                const ColoredBox(color: Colors.black),

                // Letterboxed video frame.
                Center(
                  child: AspectRatio(
                    aspectRatio: videoAspectRatio,
                    child: VideoPlayer(controller),
                  ),
                ),

                // Tap-to-toggle overlay.
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _togglePlayback(controller),
                  ),
                ),

                // Centre play icon when paused.
                if (!isPlaying)
                  IgnorePointer(
                    child: Center(
                      child: Icon(
                        Icons.play_circle_fill,
                        size: 64,
                        color: Colors.white.withValues(alpha: 0.9),
                        shadows: const [
                          Shadow(blurRadius: 12, color: Colors.black54),
                        ],
                      ),
                    ),
                  ),

                // Controls bar pinned to the bottom of the CARD.
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: ValueListenableBuilder<double>(
                    valueListenable: _speed,
                    builder: (context, speed, _) {
                      return _InlineControlsBar(
                        controller: controller,
                        speed: speed,
                        onTogglePlay: () => _togglePlayback(controller),
                        onCycleSpeed: _cycleSpeed,
                        onToggleFullscreen: _openFullscreen,
                      );
                    },
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

/// Bottom control bar for the inline player. Play/pause + current time + seek
/// + duration + speed + fullscreen toggle, all anchored inside the card.
class _InlineControlsBar extends StatelessWidget {
  final VideoPlayerController controller;
  final double speed;
  final VoidCallback onTogglePlay;
  final VoidCallback onCycleSpeed;
  final VoidCallback onToggleFullscreen;

  const _InlineControlsBar({
    required this.controller,
    required this.speed,
    required this.onTogglePlay,
    required this.onCycleSpeed,
    required this.onToggleFullscreen,
  });

  @override
  Widget build(BuildContext context) {
    final value = controller.value;
    return Container(
      color: Colors.black.withValues(alpha: 0.45),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        children: [
          IconButton(
            iconSize: 22,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            icon: Icon(
              value.isPlaying ? Icons.pause : Icons.play_arrow,
              color: Colors.white,
            ),
            onPressed: onTogglePlay,
          ),
          Text(
            _formatDuration(value.position),
            style: const TextStyle(color: Colors.white, fontSize: 11),
          ),
          Expanded(
            child: VideoProgressIndicator(
              controller,
              allowScrubbing: true,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
              colors: const VideoProgressColors(
                playedColor: Color(0xFFD4A843),
                bufferedColor: Colors.white54,
                backgroundColor: Colors.white24,
              ),
            ),
          ),
          Text(
            _formatDuration(value.duration),
            style: const TextStyle(color: Colors.white, fontSize: 11),
          ),
          const SizedBox(width: 4),
          TextButton(
            onPressed: onCycleSpeed,
            style: TextButton.styleFrom(
              minimumSize: const Size(40, 36),
              padding: EdgeInsets.zero,
              foregroundColor: Colors.white,
            ),
            child: Text(
              _formatSpeed(speed),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            iconSize: 20,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            icon: const Icon(Icons.fullscreen, color: Colors.white),
            onPressed: onToggleFullscreen,
          ),
        ],
      ),
    );
  }
}

/// Fullscreen page. Reuses the same [VideoPlayerController] so playback
/// position, play/pause state and speed survive the transition.
class _FullscreenVideoPage extends StatefulWidget {
  final VideoPlayerController controller;
  final ValueNotifier<double> speed;
  final String? title;

  const _FullscreenVideoPage({
    required this.controller,
    required this.speed,
    this.title,
  });

  @override
  State<_FullscreenVideoPage> createState() => _FullscreenVideoPageState();
}

class _FullscreenVideoPageState extends State<_FullscreenVideoPage> {
  bool _controlsVisible = true;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
    widget.speed.addListener(_onChanged);

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    widget.speed.removeListener(_onChanged);

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _togglePlayback() async {
    if (widget.controller.value.isPlaying) {
      await widget.controller.pause();
    } else {
      await widget.controller.play();
    }
    if (mounted) setState(() {});
  }

  Future<void> _cycleSpeed() async {
    final currentIndex = _kPlaybackSpeeds.indexOf(widget.speed.value);
    final nextIndex = (currentIndex + 1) % _kPlaybackSpeeds.length;
    final next = _kPlaybackSpeeds[nextIndex];
    widget.speed.value = next;
    try {
      await widget.controller.setPlaybackSpeed(next);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final value = controller.value;
    final isPlaying = value.isPlaying;
    final videoAspectRatio =
        value.aspectRatio > 0 ? value.aspectRatio : _landscapeAspectRatio;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Letterboxed video frame, always centred.
          Center(
            child: AspectRatio(
              aspectRatio: videoAspectRatio,
              child: VideoPlayer(controller),
            ),
          ),

          // Tap video toggles controls; separate tap zone to toggle playback
          // would fight with each other, so tap = toggle controls only.
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () =>
                  setState(() => _controlsVisible = !_controlsVisible),
            ),
          ),

          // Centre play icon when paused.
          if (!isPlaying && _controlsVisible)
            IgnorePointer(
              child: Center(
                child: Icon(
                  Icons.play_circle_fill,
                  size: 84,
                  color: Colors.white.withValues(alpha: 0.9),
                  shadows: const [
                    Shadow(blurRadius: 16, color: Colors.black54),
                  ],
                ),
              ),
            ),

          // Top bar: close + title.
          if (_controlsVisible)
            SafeArea(
              child: Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                      if (widget.title != null && widget.title!.isNotEmpty)
                        Expanded(
                          child: Text(
                            widget.title!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

          // Bottom controls bar.
          if (_controlsVisible)
            Align(
              alignment: Alignment.bottomCenter,
              child: SafeArea(
                child: ValueListenableBuilder<double>(
                  valueListenable: widget.speed,
                  builder: (context, speed, _) {
                    return Container(
                      color: Colors.black.withValues(alpha: 0.45),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            iconSize: 26,
                            icon: Icon(
                              isPlaying ? Icons.pause : Icons.play_arrow,
                              color: Colors.white,
                            ),
                            onPressed: _togglePlayback,
                          ),
                          Text(
                            _formatDuration(value.position),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                          Expanded(
                            child: VideoProgressIndicator(
                              controller,
                              allowScrubbing: true,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 16,
                              ),
                              colors: const VideoProgressColors(
                                playedColor: Color(0xFFD4A843),
                                bufferedColor: Colors.white54,
                                backgroundColor: Colors.white24,
                              ),
                            ),
                          ),
                          Text(
                            _formatDuration(value.duration),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: _cycleSpeed,
                            style: TextButton.styleFrom(
                              minimumSize: const Size(48, 40),
                              foregroundColor: Colors.white,
                            ),
                            child: Text(
                              _formatSpeed(speed),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          IconButton(
                            iconSize: 24,
                            icon: const Icon(
                              Icons.fullscreen_exit,
                              color: Colors.white,
                            ),
                            onPressed: () =>
                                Navigator.of(context).maybePop(),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}