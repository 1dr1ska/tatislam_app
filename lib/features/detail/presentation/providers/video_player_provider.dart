import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';

/// Manages the lifecycle of a [VideoPlayerController] and [ChewieController].
///
/// Dispose is called automatically when the provider is no longer listened to.
final videoPlayerProvider = Provider.family<VideoPlayerController?, String>(
  (ref, url) {
    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    ref.onDispose(() {
      controller.dispose();
    });
    return controller;
  },
);

/// Manages the lifecycle of a [ChewieController] tied to a [VideoPlayerController].
final chewieControllerProvider =
    Provider.family<ChewieController?, VideoPlayerController>(
  (ref, videoController) {
    final chewie = ChewieController(
      videoPlayerController: videoController,
      autoPlay: false,
      showControlsOnInitialize: true,
      aspectRatio: 16 / 9,
    );
    ref.onDispose(() {
      chewie.dispose();
    });
    return chewie;
  },
);