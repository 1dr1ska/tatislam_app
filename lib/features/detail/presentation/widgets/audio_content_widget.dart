import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart' show AudioPlayer, ProcessingState;
import 'package:tatislam_app/core/services/local_storage_service.dart';
import 'package:tatislam_app/core/storage/media_storage_repository.dart';
import 'package:tatislam_app/core/utils/responsive.dart';
import 'package:tatislam_app/features/detail/presentation/providers/audio_player_provider.dart';
import 'package:tatislam_app/features/publications/domain/entities/audio_source_type.dart';
import 'package:tatislam_app/features/publications/domain/entities/content_block.dart';

/// Available playback speed options.
const _speedOptions = [1.0, 1.25, 1.5, 2.0];

/// Prefix for Hive keys used to persist audio playback positions.
/// Key format: `audio_position_<publicationId>_<blockId>`
const _positionKeyPrefix = 'audio_position_';

/// Glassmorphism constants matching the design system.
const double _glassBlur = 12;
const double _glassOpacity = 0.30;
const double _glassBorderOpacity = 0.40;
const double _glassBorderWidth = 0.8;
const double _glassRadius = 12;
const Color _goldAccent = Color(0xFFE0B84A);
const Color _goldAccentDark = Color(0xFFC49A2E);

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

    final isLandscape = ResponsiveBreakpoints.isCompactLandscape(context) ||
        ResponsiveBreakpoints.isTablet(context);

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
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.all(16),
            child: isLandscape
                ? _buildLandscapePlayer(audioPlayer, context)
                : _buildPortraitPlayer(audioPlayer, context),
          ),
        ),
      ),
    );
  }

  Widget _buildPortraitPlayer(AudioPlayer audioPlayer, BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Play / Pause button — main visual accent, enlarged
        StreamBuilder(
          stream: audioPlayer.playerStateStream,
          builder: (context, snapshot) {
            final state = snapshot.data;
            final isPlaying = state?.playing == true;
            final isCompleted =
                state?.processingState == ProcessingState.completed;

            return GestureDetector(
              onTap: () async {
                try {
                  await audioPlayer.setSpeed(_speed);
                  if (isPlaying) {
                    _savePosition();
                    await audioPlayer.pause();
                  } else {
                    if (isCompleted) {
                      await audioPlayer.seek(Duration.zero);
                    }
                    await audioPlayer.play();
                  }
                } catch (e) {
                  debugPrint('Error controlling audio playback: $e');
                }
              },
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: _goldAccent.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(36),
                  border: Border.all(
                    color: _goldAccent.withValues(alpha: 0.6),
                    width: 2.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _goldAccent.withValues(alpha: 0.15),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Icon(
                  isCompleted
                      ? Icons.replay
                      : isPlaying
                          ? Icons.pause
                          : Icons.play_arrow,
                  color: _goldAccentDark,
                  size: 40,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        // Seek slider — more expressive
        _buildSeekBar(audioPlayer),
        const SizedBox(height: 12),
        // Playback speed selector — glassmorphism chips
        _buildSpeedSelector(audioPlayer),
        if (widget.block.caption != null &&
            widget.block.caption!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              widget.block.caption!,
              style: const TextStyle(
                color: Color(0xFF2D2D44),
                height: 1.5,
                fontSize: 14,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildLandscapePlayer(AudioPlayer audioPlayer, BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Large play button on the left
        StreamBuilder(
          stream: audioPlayer.playerStateStream,
          builder: (context, snapshot) {
            final state = snapshot.data;
            final isPlaying = state?.playing == true;
            final isCompleted =
                state?.processingState == ProcessingState.completed;

            return GestureDetector(
              onTap: () async {
                try {
                  await audioPlayer.setSpeed(_speed);
                  if (isPlaying) {
                    _savePosition();
                    await audioPlayer.pause();
                  } else {
                    if (isCompleted) {
                      await audioPlayer.seek(Duration.zero);
                    }
                    await audioPlayer.play();
                  }
                } catch (e) {
                  debugPrint('Error controlling audio playback: $e');
                }
              },
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: _goldAccent.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(40),
                  border: Border.all(
                    color: _goldAccent.withValues(alpha: 0.6),
                    width: 2.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _goldAccent.withValues(alpha: 0.15),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Icon(
                  isCompleted
                      ? Icons.replay
                      : isPlaying
                          ? Icons.pause
                          : Icons.play_arrow,
                  color: _goldAccentDark,
                  size: 44,
                ),
              ),
            );
          },
        ),
        const SizedBox(width: 16),
        // Right side: slider + controls
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSeekBar(audioPlayer),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSpeedSelector(audioPlayer),
                ],
              ),
              if (widget.block.caption != null &&
                  widget.block.caption!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    widget.block.caption!,
                    style: const TextStyle(
                      color: Color(0xFF2D2D44),
                      height: 1.5,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.start,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSeekBar(AudioPlayer audioPlayer) {
    return StreamBuilder(
      stream: audioPlayer.positionStream,
      builder: (context, snapshot) {
        final position = snapshot.data ?? Duration.zero;
        final duration =
            audioPlayer.duration ?? const Duration(seconds: 120);
        final positionSeconds = position.inSeconds.toDouble();
        final durationSeconds = duration.inSeconds.toDouble();

        return Column(
          children: [
            SliderTheme(
              data: SliderThemeData(
                activeTrackColor: _goldAccent,
                inactiveTrackColor:
                    Colors.white.withValues(alpha: 0.15),
                thumbColor: _goldAccent,
                overlayColor: _goldAccent.withValues(alpha: 0.15),
                trackHeight: 5,
                thumbShape:
                    const RoundSliderThumbShape(enabledThumbRadius: 10),
              ),
              child: Slider(
                value: positionSeconds > durationSeconds
                    ? durationSeconds
                    : positionSeconds,
                max: durationSeconds > 0 ? durationSeconds : 1,
                onChanged: (value) {
                  audioPlayer.seek(Duration(seconds: value.toInt()));
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatDuration(position),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    _formatDuration(duration),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSpeedSelector(AudioPlayer audioPlayer) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _speedOptions.map((speed) {
        final isSelected = speed == _speed;
        return GestureDetector(
          onTap: () {
            setState(() {
              _speed = speed;
            });
            audioPlayer.setSpeed(speed);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? _goldAccent.withValues(alpha: 0.30)
                  : Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected
                    ? _goldAccent
                    : Colors.white.withValues(alpha: 0.20),
                width: 1.0,
              ),
            ),
            child: Text(
              '${speed}x',
              style: TextStyle(
                color: isSelected
                    ? _goldAccentDark
                    : Colors.white.withValues(alpha: 0.90),
                fontWeight:
                    isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
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
            height: 120,
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
                  const Icon(Icons.music_off, size: 48, color: Colors.grey),
                  const SizedBox(height: 12),
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