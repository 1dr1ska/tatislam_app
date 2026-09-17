import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart' show ProcessingState;
import 'package:tatislam_app/features/audio/application/audio_snapshot.dart';
import 'package:tatislam_app/features/audio/domain/audio_track.dart';
import 'package:tatislam_app/features/audio/presentation/providers/audio_playback_providers.dart';
import 'package:tatislam_app/features/audio/presentation/widgets/mini_player.dart';

const AudioTrack _track = AudioTrack(
  id: 'b1',
  publicationId: 'p1',
  url: 'https://example.com/audio/b1.mp3',
  title: 'Татарская песня',
);

/// Notifier override that always reports the same fixed snapshot.
class _FakeSnapshotNotifier extends AudioSnapshotNotifier {
  final AudioSnapshot _initial;

  _FakeSnapshotNotifier(this._initial);

  @override
  AudioSnapshot build() => _initial;
}

Widget _miniPlayerTree({
  required AudioSnapshot snapshot,
  VoidCallback? onTogglePlayback,
  VoidCallback? onClose,
  void Function(Duration)? onSeek,
}) {
  return ProviderScope(
    overrides: [
      audioSnapshotProvider.overrideWith(() => _FakeSnapshotNotifier(snapshot)),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: MiniPlayer(
          onTogglePlayback: onTogglePlayback ?? () {},
          onClose: onClose ?? () {},
          onSeek: onSeek ?? (_) {},
        ),
      ),
    ),
  );
}

void main() {
  AudioSnapshot stoppedSnapshot() => AudioSnapshot(
    track: _track,
    isPlaying: false,
    processingState: ProcessingState.ready,
    position: Duration.zero,
    duration: const Duration(seconds: 60),
  );

  AudioSnapshot playingSnapshot() => AudioSnapshot(
    track: _track,
    isPlaying: true,
    processingState: ProcessingState.ready,
    position: const Duration(seconds: 12),
    duration: const Duration(seconds: 60),
  );

  testWidgets('is empty without a current track', (tester) async {
    await tester.pumpWidget(
      _miniPlayerTree(snapshot: const AudioSnapshot(track: null)),
    );

    // The bar widget exists but renders nothing interactive.
    expect(find.byType(Slider), findsNothing);
    expect(find.byIcon(Icons.play_arrow), findsNothing);
    expect(find.byIcon(Icons.pause), findsNothing);
    expect(find.byIcon(Icons.close), findsNothing);
  });

  testWidgets('shows play button, close button and timeline when stopped', (
    tester,
  ) async {
    await tester.pumpWidget(_miniPlayerTree(snapshot: stoppedSnapshot()));

    expect(find.byType(MiniPlayer), findsOneWidget);
    expect(find.byType(Slider), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    expect(find.byIcon(Icons.pause), findsNothing);
    expect(find.byIcon(Icons.close), findsOneWidget);
  });

  testWidgets('shows the pause button while playing', (tester) async {
    await tester.pumpWidget(_miniPlayerTree(snapshot: playingSnapshot()));

    expect(find.byType(MiniPlayer), findsOneWidget);
    expect(find.byIcon(Icons.pause), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow), findsNothing);
    expect(find.byIcon(Icons.close), findsOneWidget);
  });

  testWidgets('shows the replay button after completion', (tester) async {
    await tester.pumpWidget(
      _miniPlayerTree(
        snapshot: AudioSnapshot(
          track: _track,
          isPlaying: false,
          processingState: ProcessingState.completed,
          position: const Duration(seconds: 60),
          duration: const Duration(seconds: 60),
        ),
      ),
    );

    expect(find.byIcon(Icons.replay), findsOneWidget);
  });

  testWidgets('tapping the play button toggles playback', (tester) async {
    var toggled = false;
    await tester.pumpWidget(
      _miniPlayerTree(
        snapshot: playingSnapshot(),
        onTogglePlayback: () => toggled = true,
      ),
    );

    await tester.tap(find.byIcon(Icons.pause));

    expect(toggled, isTrue);
  });

  testWidgets('tapping the close button stops playback', (tester) async {
    var closed = false;
    await tester.pumpWidget(
      _miniPlayerTree(
        snapshot: playingSnapshot(),
        onClose: () => closed = true,
      ),
    );

    await tester.tap(find.byIcon(Icons.close));

    expect(closed, isTrue);
  });

  testWidgets('dragging the timeline seeks to a new position', (tester) async {
    final seeks = <Duration>[];
    await tester.pumpWidget(
      _miniPlayerTree(
        snapshot: stoppedSnapshot(),
        onSeek: (position) => seeks.add(position),
      ),
    );

    await tester.drag(find.byType(Slider), const Offset(120, 0));
    await tester.pump();

    expect(seeks, isNotEmpty);
  });
}
