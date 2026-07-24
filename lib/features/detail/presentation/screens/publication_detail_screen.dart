import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tatislam_app/core/constants/app_colors.dart';
import 'package:tatislam_app/core/constants/app_strings.dart';
import 'package:tatislam_app/features/favorites/providers/favorites_provider.dart';
import 'package:tatislam_app/features/catalog/providers/catalog_favorites_provider.dart';
import 'package:tatislam_app/features/publications/domain/entities/video_provider_type.dart';
import 'package:tatislam_app/features/publications/domain/entities/audio_source_type.dart';
import 'package:tatislam_app/features/publications/domain/entities/content_block.dart';
import 'package:tatislam_app/features/publications/providers/publications_provider.dart';
import 'package:tatislam_app/features/detail/presentation/screens/image_viewer_screen.dart';
import 'package:tatislam_app/features/detail/presentation/screens/image_gallery_screen.dart';
import 'package:tatislam_app/features/detail/presentation/screens/skeleton_loader.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:just_audio/just_audio.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:tatislam_app/core/storage/storage_providers.dart';
import 'package:tatislam_app/core/storage/media_storage_repository.dart';

class PublicationDetailScreen extends ConsumerStatefulWidget {
  final String publicationId;

  const PublicationDetailScreen({super.key, required this.publicationId});

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
    try {
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
    } catch (e) {
      // Handle error when loading publication
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Публикацияне табылмады: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _toggleFavorite() async {
    try {
      final toggleFavorite = ref.read(toggleFavoriteProvider);
      final newFavoriteState = await toggleFavorite(widget.publicationId);
      setState(() {
        _isFavorite = newFavoriteState;
      });
      
      // Show snackbar with result
      if (mounted) {
        final message = newFavoriteState 
            ? 'Публикация яратучыларга кушылды' 
            : 'Публикация яратучылардан чыгарылды';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
      
      // Invalidate related providers after a short delay to avoid build conflicts
      Future.microtask(() {
        ref.invalidate(favoritesProvider);
        ref.invalidate(catalogFavoritesProvider);
      });
    } catch (e) {
      // Handle error when toggling favorite
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Хата: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _launchUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        // Use mounted check to safely access context after async gap
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(AppStrings.errorLoading)));
        }
      }
    } catch (e) {
      // Handle error when launching URL
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Сылтаманы ачып булмады: $e'),
            backgroundColor: AppColors.error,
          ),
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
    final thumbnailUrl = 'https://img.youtube.com/vi/$videoId/hqdefault.jpg';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: Column(
        children: [
          InkWell(
            onTap: () => _launchUrl('https://www.youtube.com/watch?v=$videoId'),
            child: CachedNetworkImage(
              imageUrl: thumbnailUrl,
              height: 200,
              width: double.infinity,
              fit: BoxFit.cover,
              placeholder: (context, url) => const CircularProgressIndicator(),
              errorWidget: (context, url, error) =>
                  const Icon(Icons.play_circle, size: 64),
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
                Text('Видео', style: Theme.of(context).textTheme.titleMedium),
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

  Widget _buildRuTubePlayer(String url, String? caption) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: Column(
        children: [
          InkWell(
            onTap: () => _launchUrl(url),
            child: const Icon(
              Icons.play_circle,
              size: 64,
              color: AppColors.videoColor,
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
                Text('Видео', style: Theme.of(context).textTheme.titleMedium),
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
    try {
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
        }).catchError((error) {
          // Handle error when initializing video player
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Видеоны йөкләп булмады: $error'),
                backgroundColor: AppColors.error,
              ),
            );
          }
        });
    } catch (e) {
      // Handle error when creating video controller
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Видео контроллерын ясап булмады: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
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

  Widget _buildAudioPlayer(AudioContentBlock block) {
    try {
      String? mediaUrl;
      if (block.source == AudioSourceType.upload && block.audioPath != null) {
        // For uploaded audio, we need to get the public URL from storage
        // This would require accessing MediaStorageRepository
        // For now, we'll just show an unavailable state
        return _buildAudioUnavailable();
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
          // Handle error when setting audio URL
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Аудио URL адресын урнаштырып булмады: $error'),
                backgroundColor: AppColors.error,
              ),
            );
          }
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
                          // Handle error when controlling audio playback
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Аудионы уйнатып булмады: $e'),
                                backgroundColor: AppColors.error,
                              ),
                            );
                          }
                        }
                      },
                icon: _audioPlayer == null
                    ? const Icon(Icons.play_arrow)
                    : StreamBuilder(
                        stream: _audioPlayer!.playerStateStream,
                        builder: (context, snapshot) {
                          final state = snapshot.data;
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
                    return Slider(
                      value: position.inSeconds.toDouble(),
                      max: 120,
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
    } catch (e) {
      // Handle any other error when building audio player
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Аудио плеерны ясап булмады: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return _buildAudioUnavailable();
    }
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
    // Check if this is a gallery (multiple images) or single image
    if (block.isGallery) {
      // For galleries, show a grid of images that opens the gallery viewer
      return Card(
        margin: const EdgeInsets.only(bottom: 16),
        elevation: 2,
        child: Column(
          children: [
            // Show first image as a preview
            GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => ImageGalleryScreen(
                      imageUrls: block.imagePaths,
                      captions: block.captions,
                      initialIndex: 0,
                    ),
                  ),
                );
              },
              child: CachedNetworkImage(
                imageUrl: mediaStorage.publicUrlFor(block.imagePaths.first),
                width: double.infinity,
                fit: BoxFit.contain,
                placeholder: (context, url) => const CircularProgressIndicator(),
                errorWidget: (context, url, error) =>
                    const Icon(Icons.image, size: 64),
              ),
            ),
            // Show indicator that there are more images
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${block.imagePaths.length} изображений'),
                  const Icon(Icons.collections),
                ],
              ),
            ),
            if (block.caption != null && block.caption!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(block.caption!),
              ),
          ],
        ),
      );
    } else {
      // For single images, show fullscreen viewer as before
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
                      imageUrl: block.imagePath,
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
  }

  Widget _buildContentBlock(ContentBlock block, MediaStorageRepository mediaStorage) {
    return switch (block) {
      TextContentBlock() => _buildTextContent(block),
      ImageContentBlock() => _buildImageContent(block, mediaStorage),
      VideoContentBlock() => _buildVideoPlayer(block),
      AudioContentBlock() => _buildAudioPlayer(block),
    };
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
            // Try to pop first, if that doesn't work navigate to catalog as default
            final router = GoRouter.of(context);
            if (!router.canPop()) {
              // If we can't pop, go to catalog as a safe default
              router.go('/catalog');
            } else {
              // Otherwise try to pop
              router.pop();
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
                const SizedBox(height: 24),

                // Cover image (if exists)
                if (publication.publication.coverImagePath.isNotEmpty)
                  CachedNetworkImage(
                    imageUrl: mediaStorage.publicUrlFor(publication.publication.coverImagePath),
                    width: double.infinity,
                    fit: BoxFit.contain,
                    placeholder: (context, url) =>
                        const CircularProgressIndicator(),
                    errorWidget: (context, url, error) =>
                        const Icon(Icons.image, size: 64),
                  ),
                const SizedBox(height: 24),

                // Content blocks
                ...publication.blocks.map((block) => _buildContentBlock(block, mediaStorage)),

                const SizedBox(height: 24),

              ],
            ),
          );
        },
        loading: () => const PublicationDetailSkeleton(), // Используем skeleton loader
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
