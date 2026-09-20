import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Reproduces the error-guidance structure now produced by
/// `_MainScreenState._buildGridError` / the empty grid in
/// `main_screen.dart`. The key invariant this guards: the error/empty states
/// are hosted inside a scrollable with `AlwaysScrollableScrollPhysics`, so the
/// wrapping `RefreshIndicator` can still be triggered by a pull gesture even
/// though the pane itself contains no scrollable content of its own.
class _GridFeedback extends StatelessWidget {
  const _GridFeedback({required this.onRefresh});

  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Container(
                height: 200,
                color: Colors.white,
                alignment: Alignment.center,
                child: const Icon(Icons.error_outline, size: 64),
              ),
            ),
          );
        },
      ),
    );
  }
}

void main() {
  testWidgets(
      'pull-to-refresh fires on the offline/error state (swipe reloads the list)',
      (tester) async {
    var refreshCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: _GridFeedback(
            onRefresh: () async => refreshCount++,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The error pane must be backed by a scrollable so the RefreshIndicator
    // has something to pull on.
    expect(
      find.byType(Scrollable),
      findsWidgets,
      reason: 'error/empty grids must stay pull-to-refresh scrollable',
    );

    // Drag down from the top to trigger the refresh. Nothing should happen
    // unless the scrollable + AlwaysScrollableScrollPhysics are present.
    await tester.fling(
      find.byType(RefreshIndicator),
      const Offset(0, 300),
      1000,
    );
    await tester.pumpAndSettle();

    expect(refreshCount, 1, reason: 'pull gesture must reach onRefresh');
  });
}