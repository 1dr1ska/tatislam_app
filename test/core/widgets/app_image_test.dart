import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tatislam_app/core/widgets/app_image.dart';

void main() {
  testWidgets('renders a local file:// URI from disk (offline copy)',
      (tester) async {
    late Uri fileUri;
    // Real dart:io must run inside runAsync — the widget-test FakeAsync zone
    // would otherwise never let the file write complete.
    await tester.runAsync(() async {
      final dir = await Directory.systemTemp.createTemp('app_image_test_');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}${Platform.pathSeparator}photo.jpg');
      await file.writeAsBytes(<int>[
        0xFF, 0xD8, 0xFF, 0xE0, // minimal JPEG header; not decoded in this test
      ]);
      fileUri = file.uri;
    });

    await tester.pumpWidget(
      MaterialApp(
        home: AppImage(imageUrl: fileUri.toString(), fit: BoxFit.cover),
      ),
    );
    await tester.pump();

    // Local copies must be decoded from disk, never handed to the HTTP cache.
    expect(find.byType(CachedNetworkImage), findsNothing);
    expect(find.byIcon(Icons.image), findsNothing);
    final image = tester.widget<Image>(find.byType(Image));
    expect(image.image, isA<FileImage>());
  });
}