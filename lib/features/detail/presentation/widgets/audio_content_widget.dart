import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart' show AudioPlayer, ProcessingState, UriAudioSource;
import 'package:tatislam_app/core/constants/app_localizations.dart';
import 'package:tatislam_app/core/providers/locale_provider.dart';
import 'package:tatislam_app/core/services/local_storage_service.dart';
import 'package:tatislam_app/core/storage/media_storage_repository.dart';
import 'package:tatislam_app/core/utils/responsive.dart';
import 'package:tatislam_app/features/detail/domain/services/file_transfer_service.dart';
import 'package:tatislam_app/features/detail/presentation/providers/audio_playback_speed_provider.dart';
import 'package:tatislam_app/features/detail/presentation/providers/audio_player_provider.dart';
import 'package:tatislam_app/features/detail/presentation/providers/file_transfer_provider.dart';
import 'package:tatislam_app/features/publications/domain/entities/audio_source_type.dart';
import 'package:tatislam_app/features/publications/domain/entities/content_block.dart';

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
  String? _positionKey;
  Duration _displayPosition = Duration.zero;
  StreamSubscription<dynamic>? _positionSub;
  AudioPlayer? _audioPlayer;
  bool _isDragging = false;
  double? _dragValue;
  int? _savedSeconds;
  bool _isRestoring = false;
  bool _isDownloading = false;
  bool _isSharing = false;

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

      // New audio always starts with the global app-wide speed.
      await audioPlayer.setSpeed(ref.read(audioPlaybackSpeedProvider));

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

      // Apply the global app-wide playback speed before starting playback.
      await audioPlayer.setSpeed(ref.read(audioPlaybackSpeedProvider));

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
      _buildActionBar(),
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
            Align(
              alignment: Alignment.centerLeft,
              child: _buildActionBar(),
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

  Widget _buildSpeedSelector() {
    final current = ref.watch(audioPlaybackSpeedProvider);

    return PopupMenuButton<double>(
      tooltip: AppLocalizations.of(ref).audioSpeedTooltip,
      onSelected: (speed) {
        ref.read(audioPlaybackSpeedProvider.notifier).setSpeed(speed);
      },
      itemBuilder: (context) => audioSpeedOptions.map((speed) {
        final isSelected = speed == current;
        return PopupMenuItem<double>(
          value: speed,
          height: 44,
          child: Row(
            children: [
              SizedBox(
                width: 24,
                child: Icon(
                  isSelected ? Icons.check : null,
                  size: 18,
                  color: _goldAccentDark,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                formatAudioSpeed(speed),
                style: TextStyle(
                  color: isSelected ? _goldAccentDark : Colors.white,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        );
      }).toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.20),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              formatAudioSpeed(current),
              style: TextStyle(
                color: _goldAccent,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down, size: 18, color: Colors.white70),
          ],
        ),
      ),
    );
  }

  /// Compact action bar: speed dropdown + download + share.
  Widget _buildActionBar() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _buildSpeedSelector(),
        _buildActionButton(
          tooltip: t.audioDownloadTooltip,
          icon: _isDownloading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _goldAccent,
                  ),
                )
              : const Icon(Icons.download, size: 20, color: Colors.white),
          onTap: _isDownloading || _isSharing ? null : _handleDownload,
        ),
        _buildActionButton(
          tooltip: t.audioShareTooltip,
          icon: _isSharing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _goldAccent,
                  ),
                )
              : const Icon(Icons.share, size: 20, color: Colors.white),
          onTap: _isDownloading || _isSharing ? null : _handleShare,
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required String tooltip,
    required Widget icon,
    VoidCallback? onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.20),
            ),
          ),
          child: Center(child: icon),
        ),
      ),
    );
  }

  AppLocalizations get t => AppLocalizations.fromLocale(
    ref.read(localeProvider),
  );

  Future<void> _handleDownload() async {
    final mediaUrl = _resolveMediaUrl();
    if (mediaUrl == null) return;

    setState(() => _isDownloading = true);
    try {
      final service = ref.read(fileTransferServiceProvider);
      final result = await service.saveFile(
        url: mediaUrl,
        fileName: deriveFileName(mediaUrl),
      );
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      switch (result.status) {
        case FileSaveStatus.saved:
          messenger.showSnackBar(
            SnackBar(content: Text(t.audioDownloaded)),
          );
        case FileSaveStatus.canceled:
          break; // User closed the dialog — no message needed.
        case FileSaveStatus.unavailable:
        case FileSaveStatus.error:
          messenger.showSnackBar(
            SnackBar(content: Text(t.audioDownloadError)),
          );
      }
    } catch (e) {
      debugPrint('Error downloading audio: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(t.audioDownloadError)));
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  Future<void> _handleShare() async {
    final mediaUrl = _resolveMediaUrl();
    if (mediaUrl == null) return;

    setState(() => _isSharing = true);
    try {
      final service = ref.read(fileTransferServiceProvider);
      final fileName = widget.block.audioPath?.split('/').last;
      final result = await service.shareFile(
        url: mediaUrl,
        fileName: fileName,
      );
      if (!mounted) return;
      if (!result.shared) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(t.audioShareError)));
      }
    } catch (e) {
      debugPrint('Error sharing audio: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(t.audioShareError)));
      }
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

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
                  t.audioUnavailable,
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
