import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tatislam_app/core/constants/app_colors.dart';
import 'package:tatislam_app/core/constants/app_strings.dart';
import 'package:tatislam_app/features/detail/presentation/screens/image_viewer_screen.dart';
import 'package:tatislam_app/features/favorites/providers/favorites_provider.dart';
import 'package:tatislam_app/features/publications/domain/entities/video_provider_type.dart';
import 'package:tatislam_app/features/publications/domain/entities/audio_source_type.dart';
import 'package:tatislam_app/features/publications/domain/entities/content_block.dart';
import 'package:tatislam_app/features/publications/providers/publications_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio/just_audio.dart' show ProcessingState;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:tatislam_app/core/storage/storage_providers.dart';
import 'package:tatislam_app/core/storage/media_storage_repository.dart';
import 'package:webview_flutter/webview_flutter.dart';

class PublicationDetailScreen extends ConsumerStatefulWidget {
  final String publicationId;
  final String? sourceScreen;
  final String? selectedSectionId;
  final String? catalogMode;

  const PublicationDetailScreen({
    super.key, 
    required this.publicationId,
    this.sourceScreen,
    this.selectedSectionId,
    this.catalogMode,
  });

  @override
  ConsumerState<PublicationDetailScreen> createState() =>
      _PublicationDetailScreenState();
}

class _PublicationDetailScreenState
    extends ConsumerState<PublicationDetailScreen> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  AudioPlayer? _audioPlayer;
  bool _isFavorite = false;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _loadPublication();
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _chewieController?.dispose();
    _audioPlayer?.dispose();
    super.dispose();
  }

  Future<void> _loadPublication() async {
    final asyncPublication = await ref.read(
      publicationDetailProvider(widget.publicationId).future,
    );

    if (asyncPublication != null) {
      // Check if publication is in favorites
      final favoritesAsync = ref.read(favoritesProvider);
      favoritesAsync.when(
        data: (favorites) {
          final isFav = favorites.any((p) => p.id == asyncPublication.publication.id);
          if (mounted) {
            setState(() {
              _isFavorite = isFav;
            });
          }
        },
        loading: () {},
        error: (error, stackTrace) {},
      );
    }
  }

  Future<void> _toggleFavorite() async {
    final toggleFavorite = ref.read(toggleFavoriteProvider);
    final newFavoriteState = await toggleFavorite(widget.publicationId);
    setState(() {
      _isFavorite = newFavoriteState;
    });
  }

  Future<void> _launchUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      
      // Try to launch with external application first
      if (await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      )) {
        return;
      }
      
      // If that fails, try with platform default
      if (await launchUrl(
        uri,
        mode: LaunchMode.platformDefault,
      )) {
        return;
      }
      
      // If both fail, show error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось открыть URL: $url\nПопробуйте открыть его вручную в браузере')),
        );
      }
    } catch (e) {
      // Use mounted check to safely access context after async gap
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка при открытии URL: $e')),
        );
      }
    }
  }

  String? _extractYouTubeId(String url) {
    final regex = RegExp(
      r'(?:youtube\.com\/(?:[^\/]+\/.+\/|(?:v|e(?:mbed)?)\/|.*[?&]v=)|youtu\.be\/)([^"&?\/\s]{11})',
    );
    final match = regex.firstMatch(url);
    return match?.group(1);
  }

  String? _extractRutubeId(String url) {
    // Handle different Rutube URL formats
    // https://rutube.ru/video/49a443785a1e267b0647015983d9ccbd/
    // https://rutube.ru/video/private/834f1d49933a0cb93aada0c4720b893e/?p=tMqBVCpeyoEfcmOEdl92UQ
    final publicRegex = RegExp(r'rutube\.ru\/video\/([a-f0-9]{32})');
    final privateRegex = RegExp(r'rutube\.ru\/video\/private\/([a-f0-9]{32})');
    
    final publicMatch = publicRegex.firstMatch(url);
    if (publicMatch != null) {
      return publicMatch.group(1);
    }
    
    final privateMatch = privateRegex.firstMatch(url);
    if (privateMatch != null) {
      return privateMatch.group(1);
    }
    
    return null;
  }

  Widget _buildRutubeMiniPlayer(String videoId, String url) {
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
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: () {
            // Show a dialog with the embedded player
            _showRutubePlayerDialog(videoId);
          },
          child: const Text('Воспроизвести'),
        ),
      ],
    );
  }

  void _showRutubePlayerDialog(String videoId) {
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
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Закрыть'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRutubeFallback(String url) {
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
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: () => _launchUrl(url),
          child: const Text('Открыть в браузере'),
        ),
      ],
    );
  }

  Widget _buildVideoPlayer(VideoContentBlock block) {
    // Check if url is empty or invalid
    if (block.url.isEmpty) {
      return _buildVideoUnavailable();
    }

    if (block.provider == VideoProviderType.youtube) {
      final videoId = _extractYouTubeId(block.url);
      if (videoId != null) {
        return _buildYouTubePlayer(videoId, block.caption);
      }
    } else if (block.provider == VideoProviderType.rutube) {
      return _buildRuTubePlayer(block.url, block.caption);
    } else {
      // Check if it's a valid URL for direct video
      if (_isValidVideoUrl(block.url)) {
        _initializeVideoPlayer(block.url);
        return _buildVideoPlayerWidget();
      } else {
        return _buildVideoUnavailable();
      }
    }
    return _buildVideoUnavailable();
  }

  bool _isValidVideoUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (e) {
      return false;
    }
  }

  Widget _buildVideoUnavailable() {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: SizedBox(
        height: 200,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.videocam_off,
                size: 64,
                color: Colors.grey,
              ),
              const SizedBox(height: 16),
              Text(
                'Видео недоступно',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.grey,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildYouTubePlayer(String videoId, String? caption) {
    // Try to play YouTube video directly using the video player
    final videoUrl = 'https://www.youtube.com/watch?v=$videoId';
    
    // Initialize the video player with the YouTube URL
    _initializeVideoPlayer(videoUrl);
    return _buildVideoPlayerWidget();
  }

  Widget _buildRuTubePlayer(String url, String? caption) {
    // Extract video ID from URL
    final videoId = _extractRutubeId(url);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: Column(
        children: [
          Container(
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.videoColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: videoId != null
                ? _buildRutubeMiniPlayer(videoId, url)
                : _buildRutubeFallback(url),
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

  void _initializeVideoPlayer(String url) {
    _videoController = VideoPlayerController.networkUrl(Uri.parse(url))
      ..initialize().then((_) {
        _chewieController = ChewieController(
          videoPlayerController: _videoController!,
          autoPlay: false,
          showControlsOnInitialize: true,
          aspectRatio: 16 / 9,
          errorBuilder: (context, errorMessage) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, color: AppColors.error, size: 48),
                  const SizedBox(height: 16),
                  Text(errorMessage),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => _launchUrl(url),
                    child: const Text('Браузерда ачу'),
                  ),
                ],
              ),
            );
          },
        );
        if (mounted) {
          setState(() {});
        }
      });
  }

  Widget _buildVideoPlayerWidget() {
    if (_chewieController == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: Chewie(controller: _chewieController!),
    );
  }

  Widget _buildAudioPlayer(AudioContentBlock block, MediaStorageRepository mediaStorage) {
    String? mediaUrl;
    if (block.source == AudioSourceType.upload && block.audioPath != null) {
      // For uploaded audio, get the public URL from storage
      mediaUrl = mediaStorage.publicUrlFor(block.audioPath!);
    } else if (block.source == AudioSourceType.external &&
        block.audioUrl != null) {
      mediaUrl = block.audioUrl;
    }

    // Check if mediaUrl is empty or invalid
    if (mediaUrl == null || mediaUrl.isEmpty || !_isValidAudioUrl(mediaUrl)) {
      return _buildAudioUnavailable();
    }

    // Initialize audio player with the URL if not already set
    if (_audioPlayer != null) {
      _audioPlayer!.setUrl(mediaUrl).catchError((error) {
        debugPrint('Error setting audio URL: $error');
        return null;
      });
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Icon(Icons.audiotrack,
                size: 48, color: AppColors.audioColor),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _audioPlayer == null
                  ? null
                  : () async {
                      try {
                        if (_audioPlayer!.playerState.playing) {
                          await _audioPlayer!.pause();
                        } else {
                          await _audioPlayer!.play();
                        }
                      } catch (e) {
                        debugPrint('Error controlling audio playback: $e');
                      }
                    },
              icon: _audioPlayer == null
                  ? const Icon(Icons.play_arrow)
                  : StreamBuilder(
                      stream: _audioPlayer!.playerStateStream,
                      builder: (context, snapshot) {
                        final state = snapshot.data;
                        // Check if player is processing or has completed
                        if (state?.processingState == ProcessingState.completed) {
                          return const Icon(Icons.play_arrow);
                        }
                        return Icon(
                          state?.playing == true
                              ? Icons.pause
                              : Icons.play_arrow,
                        );
                      },
                    ),
              label: const Text('Уйнату'),
            ),
            const SizedBox(height: 16),
            if (_audioPlayer != null)
              StreamBuilder(
                stream: _audioPlayer!.positionStream,
                builder: (context, snapshot) {
                  final position = snapshot.data ?? Duration.zero;
                  // Get the duration, fallback to 120 seconds if not available
                  final duration = _audioPlayer!.duration ?? const Duration(seconds: 120);
                  // Ensure position doesn't exceed duration
                  final positionSeconds = position.inSeconds.toDouble();
                  final durationSeconds = duration.inSeconds.toDouble();
                  return Slider(
                    value: positionSeconds > durationSeconds ? durationSeconds : positionSeconds,
                    max: durationSeconds,
                    onChanged: (value) {
                      _audioPlayer?.seek(Duration(seconds: value.toInt()));
                    },
                  );
                },
              ),
            if (block.caption != null && block.caption!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(block.caption!),
              ),
          ],
        ),
      ),
    );
  }

  bool _isValidAudioUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (e) {
      return false;
    }
  }

  Widget _buildAudioUnavailable() {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: SizedBox(
        height: 150,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.music_off,
                size: 64,
                color: Colors.grey,
              ),
              const SizedBox(height: 16),
              Text(
                'Аудио недоступно',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.grey,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextContent(TextContentBlock block) {
    // Parse simple HTML tags manually
    final text = block.text
        .replaceAll('<h1>', '\n\n')
        .replaceAll('</h1>', '\n\n')
        .replaceAll('<h2>', '\n\n')
        .replaceAll('</h2>', '\n\n')
        .replaceAll('<h3>', '\n\n')
        .replaceAll('</h3>', '\n\n')
        .replaceAll('<p>', '')
        .replaceAll('</p>', '\n\n')
        .replaceAll('<br>', '\n')
        .replaceAll('<br/>', '\n')
        .replaceAll('<ul>', '')
        .replaceAll('</ul>', '\n\n')
        .replaceAll('<ol>', '')
        .replaceAll('</ol>', '\n\n')
        .replaceAll('<li>', '• ')
        .replaceAll('</li>', '\n')
        .replaceAll('<blockquote>', '“')
        .replaceAll('</blockquote>', '”')
        .replaceAll('<strong>', '*')
        .replaceAll('</strong>', '*')
        .replaceAll('<em>', '_')
        .replaceAll('</em>', '_')
        .replaceAll('<img[^>]*>', '');

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyLarge,
        textAlign: TextAlign.justify,
      ),
    );
  }

  Widget _buildImageContent(ImageContentBlock block, MediaStorageRepository mediaStorage) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: Column(
        children: [
          GestureDetector(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => ImageViewerScreen(
                    imageUrl: mediaStorage.publicUrlFor(block.imagePath),
                    caption: block.caption,
                  ),
                ),
              );
            },
            child: CachedNetworkImage(
              imageUrl: mediaStorage.publicUrlFor(block.imagePath),
              width: double.infinity,
              fit: BoxFit.contain,
              placeholder: (context, url) => const CircularProgressIndicator(),
              errorWidget: (context, url, error) =>
                  const Icon(Icons.image, size: 64),
            ),
          ),
          if (block.caption != null && block.caption!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(block.caption!),
            ),
        ],
      ),
    );
  }

  Widget _buildContentBlock(ContentBlock block, MediaStorageRepository mediaStorage) {
    return switch (block) {
      TextContentBlock() => _buildTextContent(block),
      ImageContentBlock() => _buildImageContent(block, mediaStorage),
      VideoContentBlock() => _buildVideoPlayer(block),
      AudioContentBlock() => _buildAudioPlayer(block, mediaStorage),
    };
  }

  /// Safely navigate back, falling back to go to home if pop fails
  void _navigateBackSafely(BuildContext context) {
    try {
      // Try to pop from navigation stack first
      if (GoRouter.of(context).canPop()) {
        GoRouter.of(context).pop();
      } else {
        // If we can't pop, go to home screen as fallback
        GoRouter.of(context).go('/');
      }
    } catch (e) {
      // If any error occurs, go to home screen as ultimate fallback
      GoRouter.of(context).go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncPublication = ref.watch(
      publicationDetailProvider(widget.publicationId),
    );
    final mediaStorage = ref.watch(mediaStorageRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // Navigate back based on source context
            if (widget.sourceScreen != null) {
              switch (widget.sourceScreen) {
                case 'catalog':
                  // Navigate to catalog with section and mode if provided
                  String route = '/catalog';
                  if (widget.selectedSectionId != null && widget.selectedSectionId!.isNotEmpty) {
                    route += '?section=${widget.selectedSectionId}';
                  }
                  if (widget.catalogMode != null && widget.catalogMode!.isNotEmpty) {
                    route += '${route.contains('?') ? '&' : '?'}mode=${widget.catalogMode}';
                  }
                  GoRouter.of(context).go(route);
                  break;
                case 'search':
                  GoRouter.of(context).go('/search');
                  break;
                case 'favorites':
                  GoRouter.of(context).go('/favorites');
                  break;
                default:
                  _navigateBackSafely(context);
              }
            } else {
              // Default behavior - try to go back in navigation stack
              _navigateBackSafely(context);
            }
          },
        ),
        title: Text(AppStrings.catalogTab),
        actions: [
          IconButton(
            icon: Icon(_isFavorite ? Icons.favorite : Icons.favorite_border),
            onPressed: _toggleFavorite,
          ),
        ],
      ),
      body: asyncPublication.when(
        data: (publication) {
          if (publication == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 64,
                    color: AppColors.error,
                  ),
                  const SizedBox(height: 16),
                  Text(AppStrings.errorLoading),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Text(
                  publication.publication.title,
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),

                // Content blocks
                ...publication.blocks.map((block) => _buildContentBlock(block, mediaStorage)),

                const SizedBox(height: 24),

                // Description
                if (publication.publication.description.isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Тасвирлама',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(publication.publication.description),
                    ],
                  ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline,
                  size: 64, color: AppColors.error),
              const SizedBox(height: 16),
              Text(AppStrings.errorLoading),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => _loadPublication(),
                child: Text(AppStrings.retry),
              ),
            ],
          ),
        ),
      ),
    );
  }
}