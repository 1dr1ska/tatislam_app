import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart' show AudioPlayer, ProcessingState, UriAudioSource;
import 'package:tatislam_app/core/services/local_storage_service.dart';
import 'package:tatislam_app/core/storage/media_storage_repository.dart';
import 'package:tatislam_app/core/utils/responsive.dart';
import 'package:tatislam_app/features/detail/presentation/providers/audio_player_provider.dart';
import 'package:tatislam_app/features/publications/domain/entities/audio_source_type.dart';
import 'package:tatislam_app/features/publications/domain/entities/content_block.dart';

const _speedOptions = [1.0, 1.25, 1.5, 2.0];
const _positionKeyPrefix = 'audio_position_';
const double _glassBlur = 12;
const double _glassOpacity = 0.30;
const double _glassBorderOpacity = 0.40;
const double _glassBorderWidth = 0.8;
const double _glassRadius = 12;
const Color _goldAccent = Color(0xFFE0B84A);
const Color _goldAccentDark = Color(0xFFC49A2E);

class AudioContentWidget extends ConsumerStatefulWidget {
  final AudioContentBlock block;
  final MediaStorageRepository mediaStorage;

  const AudioContentWidget({
    super.key,
    required this.block,
    required this.mediaStorage,
  });

  @override
  ConsumerState<AudioContentWidget> createState() => _AudioContentWidgetState();
}

class _AudioContentWidgetState extends ConsumerState<AudioContentWidget>
    with WidgetsBindingObserver {
  double _speed = 1.0;
  String? _positionKey;
  Duration _displayPosition = Duration.zero;
  StreamSubscription<dynamic>? _positionSub;
  AudioPlayer? _audioPlayer;
  bool _isDragging = false;
  double? _dragValue;
  int? _savedSeconds;
  bool _isRestoring = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    if (_hasValidBlock()) {
      _positionKey =
          '$_positionKeyPrefix${widget.block.publicationId}_${widget.block.id}';

      _savedSeconds = LocalStorageService.settingsBox.get(
        _positionKey!,
        defaultValue: 0,
      );
      if (_savedSeconds is int && _savedSeconds! > 0) {
        _displayPosition = Duration(seconds: _savedSeconds!);
      }

      _isRestoring = true;
      _audioPlayer = ref.read(audioPlayerProvider);

      _positionSub = _audioPlayer!.positionStream.listen((pos) {
        if (_isDragging || _isRestoring) return;
        _displayPosition = pos;
        if (mounted) setState(() {});
      });

      // Start immediately instead of waiting for the first frame.
      unawaited(_restorePosition());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _positionSub?.cancel();
    _audioPlayer?.pause();
    _savePosition();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _savePosition();
    }
  }

  bool _hasValidBlock() {
    if (widget.block.source == AudioSourceType.upload &&
        widget.block.audioPath != null) {
      return true;
    }
    if (widget.block.source == AudioSourceType.external &&
        widget.block.audioUrl != null) {
      return true;
    }
    return false;
  }

  void _savePosition() {
    if (_positionKey == null) return;
    try {
      if (_displayPosition.inSeconds > 0) {
        LocalStorageService.settingsBox.put(
          _positionKey!,
          _displayPosition.inSeconds,
        );
      }
    } catch (e) {
      debugPrint('Error saving audio position: $e');
    }
  }

  Future<void> _restorePosition() async {
    try {
      if (_positionKey == null) return;

      final audioPlayer = ref.read(audioPlayerProvider);
      final mediaUrl = _resolveMediaUrl();
      if (mediaUrl == null) return;

      final currentSource = audioPlayer.audioSource;
      if (currentSource is! UriAudioSource ||
          currentSource.uri.toString() != mediaUrl) {
        await audioPlayer.setUrl(mediaUrl);
        await audioPlayer.load();
      }

      if (_savedSeconds != null && _savedSeconds! > 0) {
        final saved = Duration(seconds: _savedSeconds!);
        if ((audioPlayer.position - saved).inSeconds.abs() > 1) {
          await audioPlayer.seek(saved);
        }
      }
    } catch (e) {
      debugPrint('Error restoring audio position: $e');
    } finally {
      _isRestoring = false;
      if (_savedSeconds != null && _savedSeconds! > 0) {
        _displayPosition = Duration(seconds: _savedSeconds!);
      }
      if (mounted) setState(() {});
    }
  }

  String? _resolveMediaUrl() {
    if (!_hasValidBlock()) return null;
    if (widget.block.source == AudioSourceType.upload &&
        widget.block.audioPath != null) {
      return widget.mediaStorage.publicUrlFor(widget.block.audioPath!);
    }
    if (widget.block.source == AudioSourceType.external &&
        widget.block.audioUrl != null) {
      return widget.block.audioUrl;
    }
    return null;
  }

  Future<void> _togglePlayback(AudioPlayer audioPlayer) async {
    try {
      final mediaUrl = _resolveMediaUrl();
      if (mediaUrl == null) return;

      await audioPlayer.setSpeed(_speed);

      final state = audioPlayer.playerState;
      if (state.playing) {
        _savePosition();
        await audioPlayer.pause();
        return;
      }

      if (_isRestoring) {
        await Future.doWhile(() async {
          await Future.delayed(const Duration(milliseconds: 50));
          return _isRestoring;
        });
      }

      if (state.processingState == ProcessingState.completed) {
        await audioPlayer.seek(Duration.zero);
      } else if (_savedSeconds != null &&
          _savedSeconds! > 0 &&
          audioPlayer.position.inSeconds < 1) {
        await audioPlayer.seek(Duration(seconds: _savedSeconds!));
      }

      await audioPlayer.play();
    } catch (e) {
      debugPrint('Error controlling audio playback: $e');
    }
  }

  Widget _buildPlayButton(AudioPlayer audioPlayer, {double size = 72}) {
    return StreamBuilder(
      stream: audioPlayer.playerStateStream,
      builder: (context, snapshot) {
        final state = snapshot.data;
        final isPlaying = state?.playing == true;
        final isCompleted =
            state?.processingState == ProcessingState.completed;

        return GestureDetector(
          onTap: () => _togglePlayback(audioPlayer),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: _goldAccent.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(size / 2),
              border: Border.all(
                color: _goldAccent.withValues(alpha: 0.6),
                width: 2,
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
              size: size * 0.56,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final audioPlayer = ref.watch(audioPlayerProvider);
    if (!_hasValidBlock()) return _buildUnavailable(context);

    final isLandscape =
        ResponsiveBreakpoints.isCompactLandscape(context) ||
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
                ? _buildLandscapePlayer(audioPlayer)
                : _buildPortraitPlayer(audioPlayer),
          ),
        ),
      ),
    );
  }

  Widget _buildPortraitPlayer(AudioPlayer audioPlayer) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      _buildPlayButton(audioPlayer),
      const SizedBox(height: 16),
      _buildSeekBar(audioPlayer),
      const SizedBox(height: 12),
      _buildSpeedSelector(audioPlayer),
    ],
  );

  Widget _buildLandscapePlayer(AudioPlayer audioPlayer) => Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      _buildPlayButton(audioPlayer, size: 80),
      const SizedBox(width: 16),
      Expanded(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSeekBar(audioPlayer),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [_buildSpeedSelector(audioPlayer)],
            ),
          ],
        ),
      ),
    ],
  );

  Widget _buildSeekBar(AudioPlayer audioPlayer) {
    final duration = audioPlayer.duration ?? Duration.zero;
    final durationSeconds = duration.inSeconds.toDouble();
    final positionSeconds = _isDragging
        ? (_dragValue ?? 0).clamp(0.0, durationSeconds)
        : _displayPosition.inSeconds.toDouble();
    final displayPosition = _isDragging
        ? Duration(seconds: (_dragValue ?? 0).round())
        : _displayPosition;

    return Column(
      children: [
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: _goldAccent,
            inactiveTrackColor: Colors.white.withValues(alpha: 0.15),
            thumbColor: _goldAccent,
            overlayColor: _goldAccent.withValues(alpha: 0.15),
            trackHeight: 5,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
          ),
          child: Slider(
            value: positionSeconds > durationSeconds
                ? durationSeconds
                : positionSeconds,
            max: durationSeconds > 0 ? durationSeconds : 1,
            onChanged: (value) {
              setState(() {
                _isDragging = true;
                _dragValue = value;
              });
            },
            onChangeEnd: (value) async {
              final wasCompleted =
                  audioPlayer.playerState.processingState ==
                  ProcessingState.completed;

              setState(() {
                _isDragging = false;
                _dragValue = null;
                _displayPosition = Duration(seconds: value.toInt());
              });

              try {
                await audioPlayer.seek(Duration(seconds: value.toInt()));

                // just_audio can stay in completed state after reaching
                // the end. Seeking backwards does not necessarily resume.
                if (wasCompleted) {
                  await audioPlayer.play();
                }
              } catch (e) {
                debugPrint('Error seeking audio: $e');
              }
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDuration(displayPosition),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                _formatDuration(duration),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSpeedSelector(AudioPlayer audioPlayer) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: _speedOptions.map((speed) {
      final isSelected = speed == _speed;
      return GestureDetector(
        onTap: () {
          setState(() => _speed = speed);
          audioPlayer.setSpeed(speed);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? _goldAccent.withValues(alpha: 0.30)
                : Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? _goldAccent
                  : Colors.white.withValues(alpha: 0.20),
            ),
          ),
          child: Text(
            '${speed}x',
            style: TextStyle(
              color: isSelected
                  ? _goldAccentDark
                  : Colors.white.withValues(alpha: 0.90),
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ),
      );
    }).toList(),
  );

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Widget _buildUnavailable(BuildContext context) => Padding(
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
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
