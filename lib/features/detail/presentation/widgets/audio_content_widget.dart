import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart' show AudioPlayer, ProcessingState;
import 'package:tatislam_app/core/services/local_storage_service.dart';
import 'package:tatislam_app/core/storage/media_storage_repository.dart';
import 'package:tatislam_app/features/detail/presentation/providers/audio_player_provider.dart';
import 'package:tatislam_app/features/publications/domain/entities/audio_source_type.dart';
import 'package:tatislam_app/features/publications/domain/entities/content_block.dart';

/// Available playback speed options.
const _speedOptions = [1.0, 1.25, 1.5, 2.0];

/// Prefix for Hive keys used to persist audio playback positions.
/// Key format: `audio_position_<publicationId>_<blockId>`
const _positionKeyPrefix = 'audio_position_';

/// Renders an [AudioContentBlock] with play/pause control, seek slider,
/// playback speed selector, and persisted playback position.
class AudioContentWidget extends ConsumerStatefulWidget {
  final AudioContentBlock block;
  final MediaStorageRepository mediaStorage;

  const AudioContentWidget({
    super.key,
    required this.block,
    required this.mediaStorage,
  });

  @override
  ConsumerState<AudioContentWidget> createState() =>
      _AudioContentWidgetState();
}

class _AudioContentWidgetState extends ConsumerState<AudioContentWidget> {
  double _speed = 1.0;
  String? _mediaUrl;
  String? _positionKey;
  Duration _lastPosition = Duration.zero;
  StreamSubscription<Duration>? _positionSub;
  AudioPlayer? _audioPlayer;

  @override
  void initState() {
    super.initState();

    // Resolve media URL once
    if (widget.block.source == AudioSourceType.upload &&
        widget.block.audioPath != null) {
      _mediaUrl = widget.mediaStorage.publicUrlFor(widget.block.audioPath!);
    } else if (widget.block.source == AudioSourceType.external &&
        widget.block.audioUrl != null) {
      _mediaUrl = widget.block.audioUrl;
    }

    if (_mediaUrl != null && _mediaUrl!.isNotEmpty && _isValidUrl(_mediaUrl!)) {
      // Key based on publication + block id for uniqueness
      _positionKey =
          '$_positionKeyPrefix${widget.block.publicationId}_${widget.block.id}';

      // Keep a reference to the player for safe access in dispose()
      _audioPlayer = ref.read(audioPlayerProvider);
      _positionSub = _audioPlayer!.positionStream.listen((pos) {
        _lastPosition = pos;
      });

      // Restore saved position after the audio source is set
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _restorePosition();
      });
    }
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _audioPlayer?.pause();
    _savePosition();
    super.dispose();
  }

  /// Saves the current playback position to Hive.
  void _savePosition() {
    if (_positionKey == null) return;

    try {
      if (_lastPosition.inSeconds > 0) {
        LocalStorageService.settingsBox
            .put(_positionKey!, _lastPosition.inSeconds);
        debugPrint('Saved audio position: ${_lastPosition.inSeconds}s');
      }
    } catch (e) {
      debugPrint('Error saving audio position: $e');
    }
  }

  /// Restores the saved playback position after the audio source is loaded.
  Future<void> _restorePosition() async {
    if (_positionKey == null || _mediaUrl == null) return;

    try {
      final audioPlayer = ref.read(audioPlayerProvider);

      // Check if the player already has this source loaded
      final currentSource = audioPlayer.audioSource;
      final currentUrl = currentSource?.toString() ?? '';
      final needsReload = !currentUrl.contains(_mediaUrl!);

      if (needsReload) {
        await audioPlayer.setUrl(_mediaUrl!);
        // Wait for the audio to be loaded before seeking
        await audioPlayer.load();
      }

      final savedSeconds =
          LocalStorageService.settingsBox.get(_positionKey, defaultValue: 0);
      if (savedSeconds is int && savedSeconds > 0) {
        await audioPlayer.seek(Duration(seconds: savedSeconds));
        debugPrint('Restored audio position: ${savedSeconds}s');
      }
    } catch (e) {
      debugPrint('Error restoring audio position: $e');
    } finally {
      if (mounted) {
        setState(() {});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final audioPlayer = ref.watch(audioPlayerProvider);

    if (_mediaUrl == null || _mediaUrl!.isEmpty || !_isValidUrl(_mediaUrl!)) {
      return _buildUnavailable(context);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.35),
                width: 0.8,
              ),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Icon(Icons.audiotrack,
                    size: 48, color: Color(0xFFD4A843)),
                const SizedBox(height: 16),
                // Play / Pause button
                ElevatedButton.icon(
                  onPressed: () async {
                    try {
                      // Apply current speed before playing
                      await audioPlayer.setSpeed(_speed);
                      if (audioPlayer.playerState.playing) {
                        _savePosition();
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
                // Playback speed selector
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _speedOptions.map((speed) {
                    final isSelected = speed == _speed;
                    if (isSelected) {
                      return ChoiceChip(
                        label: Text('${speed}x',
                            style: const TextStyle(color: Colors.black87)),
                        selected: true,
                        selectedColor: const Color(0xFFD4A843),
                        backgroundColor: Colors.white.withValues(alpha: 0.22),
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              _speed = speed;
                            });
                            audioPlayer.setSpeed(speed);
                          }
                        },
                        side: const BorderSide(
                          color: Color(0xFFD4A843),
                          width: 0.8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      );
                    }
                    return ChoiceChip(
                      label: Text('${speed}x',
                          style: const TextStyle(color: Colors.white)),
                      selected: false,
                      selectedColor: const Color(0xFFD4A843),
                      backgroundColor: Colors.white.withValues(alpha: 0.22),
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _speed = speed;
                          });
                          audioPlayer.setSpeed(speed);
                        }
                      },
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.35),
                        width: 0.8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                // Seek slider
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
                if (widget.block.caption != null &&
                    widget.block.caption!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(
                      widget.block.caption!,
                      style: const TextStyle(
                        color: Color(0xFF2D2D44),
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
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            width: double.infinity,
            height: 150,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.35),
                width: 0.8,
              ),
            ),
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