import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Stands in for a text card: its height is intrinsic and depends on how much
/// content (title lines) it carries, pre-wrap.
class _ContentCard extends StatelessWidget {
  const _ContentCard({this.lines = 0, this.isPhoto = false});

  final int lines;
  final bool isPhoto;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[
      Container(
        color: Colors.blue,
        height: 60, // icon band equivalent
      ),
      for (var i = 0; i < lines; i++)
        const Padding(
          padding: EdgeInsets.all(4),
          child: Text('Title line', maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
    ];
    return Container(
      // Photos have no intrinsic height, so the grid gives them a fixed height.
      height: isPhoto ? 160 : null,
      color: Colors.white,
      child: isPhoto
          ? const SizedBox.expand(child: ColoredBox(color: Colors.black))
          : Column(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}

/// Mirrors the row-equal layout used by `main_screen.dart`: every card in a row
/// is as tall as the tallest card in that row, and short cards expand to fill.
Widget _buildRow(List<Widget> cards) {
  return IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < cards.length; i++) ...[
          if (i > 0) const SizedBox(width: 16),
          Expanded(child: cards[i]),
        ],
      ],
    ),
  );
}

void main() {
  testWidgets(
      'cards in a row are all the same height, matching the tallest content',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 600,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // A short card (1 title line) and a tall card (6 lines).
                  _buildRow([
                    _ContentCard(lines: 1),
                    _ContentCard(lines: 6),
                  ]),
                  SizedBox(height: 16),
                  // A fixed-height photo card next to a short text card.
                  _buildRow([
                    _ContentCard(lines: 1),
                    _ContentCard(isPhoto: true),
                  ]),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // No layout exceptions (overflow / intrinsic failure).
    expect(tester.takeException(), isNull);

    // Verify that inside each row the cards are equal to the row's tallest.
    final row1 = <double>[
      tester.getSize(find.byType(_ContentCard).at(0)).height,
      tester.getSize(find.byType(_ContentCard).at(1)).height,
    ];
    final row2 = <double>[
      tester.getSize(find.byType(_ContentCard).at(2)).height,
      tester.getSize(find.byType(_ContentCard).at(3)).height,
    ];

    expect(row1[0], row1[1]);
    expect(row2[0], row2[1]);
    // A row with a 6-line card is taller than the photo row.
    expect(row1[0], greaterThan(row2[0]));
  });
}