import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart' show ProcessingState;
import 'package:tatislam_app/core/constants/app_localizations.dart';
import 'package:tatislam_app/core/providers/locale_provider.dart';
import 'package:tatislam_app/core/storage/media_storage_repository.dart';
import 'package:tatislam_app/core/utils/responsive.dart';
import 'package:tatislam_app/features/audio/data/audio_position_store.dart';
import 'package:tatislam_app/features/audio/domain/audio_track.dart';
import 'package:tatislam_app/features/audio/presentation/providers/audio_playback_providers.dart';
import 'package:tatislam_app/features/detail/domain/services/file_transfer_service.dart';
import 'package:tatislam_app/features/detail/presentation/providers/audio_playback_speed_provider.dart';
import 'package:tatislam_app/features/detail/presentation/providers/file_transfer_provider.dart';
import 'package:tatislam_app/features/publications/domain/entities/audio_source_type.dart';
import 'package:tatislam_app/features/publications/domain/entities/content_block.dart';

const String _positionKeyPrefix = 'audio_position_';
const double _glassBlur = 12;
const double _glassOpacity = 0.30;
const double _glassBorderOpacity = 0.40;
const double _glassBorderWidth = 0.8;
const double _glassRadius = 12;
const Color _goldAccent = Color(0xFFE0B84A);
const Color _goldAccentDark = Color(0xFFC49A2E);
/// Dark opaque surface shared by the speed chip and its popup menu. The audio
/// card is translucent glass over an image backdrop, and the Material popup
/// surface is light, so translucent/theme colors make the gold/white text
/// unreadable. An opaque dark surface keeps the text legible in every state.
const Color _speedSurface = Color(0xFF262626);

class AudioContentWidget extends ConsumerStatefulWidget {
  final AudioContentBlock block;
  final MediaStorageRepository mediaStorage;

  /// Publication title — used as the track name in the Mini Player, the full
  /// player screen and the system media notification (audio blocks have no
  /// title of their own).
  final String? trackTitle;

  const AudioContentWidget({
    super.key,
    required this.block,
    required this.mediaStorage,
    this.trackTitle,
  });

  @override
  ConsumerState<AudioContentWidget> createState() => _AudioContentWidgetState();
}

class _AudioContentWidgetState extends ConsumerState<AudioContentWidget> {
  final AudioPositionStore _positionStore = const AudioPositionStore();
  bool _isDragging = false;
  double? _dragValue;
  int? _savedSeconds;
  bool _isDownloading = false;
  bool _isSharing = false;

  @override
  void initState() {
    super.initState();
    if (_hasValidBlock()) {
      _savedSeconds = _positionStore.read(
        '$_positionKeyPrefix${widget.block.publicationId}_${widget.block.id}',
      );
      debugPrint(
        'AudioContentWidget init key='
        '$_positionKeyPrefix${widget.block.publicationId}_${widget.block.id} '
        'saved=$_savedSeconds',
      );
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

  AudioTrack _buildTrack(String mediaUrl) {
    return AudioTrack(
      id: widget.block.id,
      publicationId: widget.block.publicationId,
      url: mediaUrl,
      title: widget.trackTitle ?? widget.block.publicationId,
      source: widget.block.source,
      audioPath: widget.block.audioPath,
    );
  }

  Future<void> _togglePlayback() async {
    final mediaUrl = _resolveMediaUrl();
    if (mediaUrl == null) return;

    final service = ref.read(audioPlayerServiceProvider);
    final snapshot = ref.read(audioSnapshotProvider);
    final isCurrent = snapshot.track?.id == widget.block.id;

    // This same block is already playing back (or still loading it → pause.
    // Otherwise load (or resume) this block through the shared service.
    if (isCurrent &&
        (snapshot.isPlaying ||
            snapshot.processingState == ProcessingState.loading)) {
      await service.pause();
      return;
    }
    await service.loadTrack(_buildTrack(mediaUrl), autoplay: true);
  }

  Widget _buildPlayButton({double size = 72}) {
    final snapshot = ref.watch(audioSnapshotProvider);
    final isCurrent = snapshot.track?.id == widget.block.id;
    final isPlaying = isCurrent && snapshot.isPlaying;
    final isCompleted = isCurrent && snapshot.isCompleted;

    return GestureDetector(
      onTap: _togglePlayback,
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
  }

  @override
  Widget build(BuildContext context) {
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
                ? _buildLandscapePlayer()
                : _buildPortraitPlayer(),
          ),
        ),
      ),
    );
  }

  Widget _buildPortraitPlayer() => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      _buildPlayButton(),
      const SizedBox(height: 16),
      _buildSeekBar(),
      const SizedBox(height: 12),
      _buildActionBar(),
    ],
  );

  Widget _buildLandscapePlayer() => Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      _buildPlayButton(size: 80),
      const SizedBox(width: 16),
      Expanded(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSeekBar(),
            const SizedBox(height: 8),
            Align(alignment: Alignment.centerLeft, child: _buildActionBar()),
          ],
        ),
      ),
    ],
  );

  Widget _buildSeekBar() {
    final snapshot = ref.watch(audioSnapshotProvider);
    final isCurrent = snapshot.track?.id == widget.block.id;
    final duration = snapshot.duration ?? Duration.zero;
    final durationSeconds = duration.inSeconds.toDouble();

    // Prefer the live player position only when it is meaningful (playing, or
    // paused at a real spot). Otherwise fall back to the persisted resume
    // point — this also covers a «current» track whose player got reset to 0.
    final liveOK =
        isCurrent && (snapshot.isPlaying || snapshot.position > Duration.zero);
    final baseSeconds = liveOK
        ? snapshot.position.inSeconds.toDouble()
        : (_savedSeconds ?? 0).toDouble();
    final positionSeconds = _isDragging
        ? (_dragValue ?? 0.0).clamp(0.0, durationSeconds)
        : baseSeconds;
    final displayPosition = _isDragging
        ? Duration(seconds: (_dragValue ?? 0).round())
        : (liveOK ? snapshot.position : Duration(seconds: _savedSeconds ?? 0));

    // The duration is usually unknown before the first load (0 „max“), which
    // would pin the knob at the start even though a resume point exists. Give
    // the slider a max that accommodates the saved position so the knob rests
    // on the «remembered» time before the user presses play.
    final savedSeconds = (_savedSeconds ?? 0).toDouble();
    final sliderMax = durationSeconds > savedSeconds
        ? durationSeconds
        : (savedSeconds > 0 ? savedSeconds + 1.0 : 1.0);

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
            value: positionSeconds > sliderMax ? sliderMax : positionSeconds,
            max: sliderMax,
            onChanged: (value) {
              setState(() {
                _isDragging = true;
                _dragValue = value;
              });
            },
            onChangeEnd: (value) async {
              final wasCompleted = snapshot.isCompleted;
              setState(() {
                _isDragging = false;
                _dragValue = null;
              });

              final service = ref.read(audioPlayerServiceProvider);
              try {
                await service.seek(Duration(seconds: value.toInt()));
                // just_audio stays completed after the end; seeking back does
                // not necessarily resume playback.
                if (wasCompleted) {
                  await service.play();
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
      // Opaque dark menu surface: the Material popup surface is light and the
      // unselected items used white text, which was invisible. With a dark
      // surface the gold (selected) and white (unselected) text both read well.
      color: _speedSurface,
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
                  color: _goldAccent,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                formatAudioSpeed(speed),
                style: TextStyle(
                  color: isSelected ? _goldAccent : Colors.white,
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
          // Opaque dark chip (same surface as the menu): gold text stays
          // readable over any backdrop, including a light section image or
          // failed background image on the web.
          color: _speedSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _goldAccent.withValues(alpha: 0.55),
            width: 0.8,
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
            border: Border.all(color: Colors.white.withValues(alpha: 0.20)),
          ),
          child: Center(child: icon),
        ),
      ),
    );
  }

  AppLocalizations get t =>
      AppLocalizations.fromLocale(ref.read(localeProvider));

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
          messenger.showSnackBar(SnackBar(content: Text(t.audioDownloaded)));
        case FileSaveStatus.canceled:
          break; // User closed the dialog — no message needed.
        case FileSaveStatus.unavailable:
        case FileSaveStatus.error:
          messenger.showSnackBar(SnackBar(content: Text(t.audioDownloadError)));
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
      final result = await service.shareFile(url: mediaUrl, fileName: fileName);
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
