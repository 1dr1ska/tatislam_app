import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart' show ProcessingState;
import 'package:tatislam_app/core/constants/app_colors.dart';
import 'package:tatislam_app/core/storage/media_storage_repository.dart';
import 'package:tatislam_app/features/detail/presentation/providers/audio_player_provider.dart';
import 'package:tatislam_app/features/publications/domain/entities/audio_source_type.dart';
import 'package:tatislam_app/features/publications/domain/entities/content_block.dart';

/// Renders an [AudioContentBlock] with play/pause control and a seek slider.
class AudioContentWidget extends ConsumerWidget {
  final AudioContentBlock block;
  final MediaStorageRepository mediaStorage;

  const AudioContentWidget({
    super.key,
    required this.block,
    required this.mediaStorage,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audioPlayer = ref.watch(audioPlayerProvider);

    String? mediaUrl;
    if (block.source == AudioSourceType.upload && block.audioPath != null) {
      mediaUrl = mediaStorage.publicUrlFor(block.audioPath!);
    } else if (block.source == AudioSourceType.external &&
        block.audioUrl != null) {
      mediaUrl = block.audioUrl;
    }

    if (mediaUrl == null || mediaUrl.isEmpty || !_isValidUrl(mediaUrl)) {
      return _buildUnavailable(context);
    }

    // Set audio source (idempotent — safe to call on rebuild)
    audioPlayer.setUrl(mediaUrl).catchError((error) {
      debugPrint('Error setting audio URL: $error');
      return null;
    });

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
              onPressed: () async {
                try {
                  if (audioPlayer.playerState.playing) {
                    await audioPlayer.pause();
                  } else {
                    await audioPlayer.play();
                  }
                } catch (e) {
                  debugPrint('Error controlling audio playback: $e');
                }
              },
              icon: StreamBuilder(
                stream: audioPlayer.playerStateStream,
                builder: (context, snapshot) {
                  final state = snapshot.data;
                  if (state?.processingState == ProcessingState.completed) {
                    return const Icon(Icons.play_arrow);
                  }
                  return Icon(
                    state?.playing == true ? Icons.pause : Icons.play_arrow,
                  );
                },
              ),
              label: const Text('Уйнату'),
            ),
            const SizedBox(height: 16),
            StreamBuilder(
              stream: audioPlayer.positionStream,
              builder: (context, snapshot) {
                final position = snapshot.data ?? Duration.zero;
                final duration =
                    audioPlayer.duration ?? const Duration(seconds: 120);
                final positionSeconds = position.inSeconds.toDouble();
                final durationSeconds = duration.inSeconds.toDouble();
                return Slider(
                  value: positionSeconds > durationSeconds
                      ? durationSeconds
                      : positionSeconds,
                  max: durationSeconds,
                  onChanged: (value) {
                    audioPlayer.seek(Duration(seconds: value.toInt()));
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

  Widget _buildUnavailable(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: SizedBox(
        height: 150,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.music_off, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                'Аудио недоступно',
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

  bool _isValidUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (_) {
      return false;
    }
  }
}