import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tatislam_app/features/detail/presentation/screens/image_gallery_screen.dart';

void main() {
  testWidgets('ImageGalleryScreen displays images and captions correctly', (WidgetTester tester) async {
    // Sample data for testing
    final imageUrls = [
      'https://example.com/image1.jpg',
      'https://example.com/image2.jpg',
      'https://example.com/image3.jpg',
    ];
    
    final captions = [
      'First image caption',
      'Second image caption',
      'Third image caption',
    ];
    
    // Build the widget
    await tester.pumpWidget(
      MaterialApp(
        home: ImageGalleryScreen(
          imageUrls: imageUrls,
          captions: captions,
          initialIndex: 0,
        ),
      ),
    );
    
    // Verify that the gallery screen is displayed
    expect(find.byType(ImageGalleryScreen), findsOneWidget);
    
    // Verify that the first image is displayed
    expect(find.byType(PageView), findsOneWidget);
    
    // Verify that the close button is present
    expect(find.byIcon(Icons.close), findsOneWidget);
    
    // Verify that the image counter is displayed
    expect(find.text('1 / 3'), findsOneWidget);
    
    // Verify that the caption is displayed
    expect(find.text('First image caption'), findsOneWidget);
  });
  
  testWidgets('ImageGalleryScreen handles empty captions correctly', (WidgetTester tester) async {
    // Sample data with some empty captions
    final imageUrls = [
      'https://example.com/image1.jpg',
      'https://example.com/image2.jpg',
    ];
    
    final captions = [
      'First image caption',
      null, // Empty caption
    ];
    
    // Build the widget
    await tester.pumpWidget(
      MaterialApp(
        home: ImageGalleryScreen(
          imageUrls: imageUrls,
          captions: captions,
          initialIndex: 0,
        ),
      ),
    );
    
    // Verify that the first caption is displayed
    expect(find.text('First image caption'), findsOneWidget);
    
    // Navigate to the second image
    await tester.drag(find.byType(PageView), const Offset(-500, 0));
    await tester.pumpAndSettle();
    
    // Verify that the image counter updated
    expect(find.text('2 / 2'), findsOneWidget);
    
    // Verify that no caption is displayed for the second image
    expect(find.text('First image caption'), findsNothing);
  });
}