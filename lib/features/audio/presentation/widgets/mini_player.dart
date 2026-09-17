import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tatislam_app/core/constants/app_colors.dart';
import 'package:tatislam_app/features/audio/application/audio_snapshot.dart';
import 'package:tatislam_app/features/audio/presentation/providers/audio_playback_providers.dart';

const double _glassBlur = 18;
const double _miniPlayerRadius = 16;
const double _barHeight = 50;

/// Compact bottom player: exactly three elements — play/pause, a seek
/// timeline and a close (stop) button.
///
/// No artwork, no title, no screen is opened from here. All state comes from
/// the single shared [audioSnapshotProvider]; callbacks talk only to the same
/// shared [AudioPlayerService].
class MiniPlayer extends ConsumerStatefulWidget {
  const MiniPlayer({
    super.key,
    this.onTogglePlayback,
    this.onClose,
    this.onSeek,
  });

  /// Play/pause toggle for the current track.
  final VoidCallback? onTogglePlayback;

  /// Closes the player: stops playback and hides the bar.
  final VoidCallback? onClose;

  /// Seeks to a new position chosen on the timeline.
  final void Function(Duration position)? onSeek;

  @override
  ConsumerState<MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends ConsumerState<MiniPlayer> {
  bool _isDragging = false;
  double? _dragValue;

  void _onSliderChanged(double value) {
    setState(() {
      _isDragging = true;
      _dragValue = value;
    });
  }

  void _onSliderChangeEnd(double value) {
    setState(() {
      _isDragging = false;
      _dragValue = null;
    });
    widget.onSeek?.call(Duration(seconds: value.round()));
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(audioSnapshotProvider);
    if (snapshot.track == null) return const SizedBox.shrink();

    final duration = snapshot.duration ?? Duration.zero;
    final durationSeconds = duration.inSeconds.toDouble();
    final positionSeconds = _isDragging
        ? (_dragValue ?? 0.0).clamp(0.0, durationSeconds)
        : snapshot.position.inSeconds.toDouble();

    return ClipRRect(
      borderRadius: BorderRadius.circular(_miniPlayerRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: _glassBlur, sigmaY: _glassBlur),
        child: Container(
          width: double.infinity,
          height: _barHeight,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.28),
            borderRadius: BorderRadius.circular(_miniPlayerRadius),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.45),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.14),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              const SizedBox(width: 8),
              // Close (stop) — intentionally kept on the left per UX request.
              _buildCloseButton(),
              const SizedBox(width: 4),
              // Seek timeline
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: SliderTheme(
                    data: SliderThemeData(
                      activeTrackColor: AppColors.gold,
                      inactiveTrackColor: Colors.white.withValues(alpha: 0.18),
                      thumbColor: AppColors.gold,
                      overlayColor: AppColors.gold.withValues(alpha: 0.15),
                      trackHeight: 4,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 8,
                      ),
                    ),
                    child: Slider(
                      value: positionSeconds > durationSeconds
                          ? durationSeconds
                          : positionSeconds,
                      max: durationSeconds > 0 ? durationSeconds : 1,
                      onChanged: _onSliderChanged,
                      onChangeEnd: _onSliderChangeEnd,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              // Play/pause
              _buildPlayPauseButton(snapshot),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlayPauseButton(AudioSnapshot snapshot) {
    final icon = snapshot.isCompleted
        ? Icons.replay
        : snapshot.isPlaying
        ? Icons.pause
        : Icons.play_arrow;
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.25),
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.gold.withValues(alpha: 0.6),
          width: 1.5,
        ),
      ),
      child: IconButton(
        icon: Icon(icon, color: AppColors.goldDark, size: 22),
        padding: EdgeInsets.zero,
        onPressed: widget.onTogglePlayback,
      ),
    );
  }

  Widget _buildCloseButton() {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: IconButton(
        icon: Icon(Icons.close, color: Colors.white, size: 18),
        padding: EdgeInsets.zero,
        onPressed: widget.onClose,
      ),
    );
  }
}

/// Global bottom overlay hosting [MiniPlayer].
///
/// Mounted in `MaterialApp.builder` so the player is visible on every screen.
/// Renders inside a local [MaterialTheme] + [Material] because the builder
/// context sits ABOVE the Navigator — material widgets (Slider) and anything
/// needing an Overlay ancestor otherwise throw «No material widget found» /
/// «No overlay ancestor» at runtime.
class MiniPlayerOverlay extends ConsumerWidget {
  const MiniPlayerOverlay({super.key, required this.child});

  /// The app content (the router's Navigator) rendered underneath the player.
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Overlay.wrap(
      // Two ancestors the builder context (above the Navigator) is missing:
      //  - `Material` → Material.of(context) for Slider ink/thumb/overlay;
      //  - `Overlay`  → OverlayPortal (the slider's value indicator).
      // Without them Slider throws «No Material widget found» / «No overlay
      // ancestor found» at runtime on the device.
      child: Material(
        color: Colors.transparent,
        child: Stack(
          children: [
            Positioned.fill(child: child),
            Positioned(
              left: 12,
              right: 12,
              bottom: bottom + 8,
              child: MiniPlayer(
                onTogglePlayback: () {
                  ref.read(audioPlayerServiceProvider).toggleCurrent();
                },
                onClose: () {
                  ref.read(audioPlayerServiceProvider).stop();
                },
                onSeek: (position) {
                  ref.read(audioPlayerServiceProvider).seek(position);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
