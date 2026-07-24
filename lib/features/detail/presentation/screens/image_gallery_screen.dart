import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';

class ImageGalleryScreen extends StatefulWidget {
  final List<String> imageUrls;
  final List<String?> captions;
  final int initialIndex;

  const ImageGalleryScreen({
    super.key,
    required this.imageUrls,
    required this.captions,
    this.initialIndex = 0,
  }) : assert(imageUrls.length == captions.length);

  @override
  State<ImageGalleryScreen> createState() => _ImageGalleryScreenState();
}

class _ImageGalleryScreenState extends State<ImageGalleryScreen> {
  late PageController _pageController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    debugPrint('ImageGalleryScreen.initState: imageUrls.length = ${widget.imageUrls.length}');
    debugPrint('ImageGalleryScreen.initState: initialIndex = ${widget.initialIndex}');
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
    debugPrint('ImageGalleryScreen.initState: _currentIndex = $_currentIndex');
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            if (kDebugMode)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  color: Colors.red.withValues(alpha: 0.8),
                  padding: const EdgeInsets.all(4),
                  child: Text(
                    'DEBUG: currentIndex=$_currentIndex, total=${widget.imageUrls.length}',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            // Image gallery
            PageView.builder(
              controller: _pageController,
              itemCount: widget.imageUrls.length,
              onPageChanged: (index) {
                debugPrint('ImageGalleryScreen.onPageChanged: index = $index');
                setState(() {
                  _currentIndex = index;
                });
                debugPrint('ImageGalleryScreen.onPageChanged: _currentIndex = $_currentIndex');
              },
              itemBuilder: (context, index) {
                debugPrint('ImageGalleryScreen.itemBuilder: building item at index $index');
                debugPrint('ImageGalleryScreen.itemBuilder: imageUrl = ${widget.imageUrls[index]}');
                return InteractiveViewer(
                  panEnabled: true,
                  minScale: 0.5,
                  maxScale: 3.0,
                  child: Center(
                    child: CachedNetworkImage(
                      imageUrl: widget.imageUrls[index],
                      fit: BoxFit.contain,
                      placeholder: (context, url) {
                        debugPrint('ImageGalleryScreen.itemBuilder: loading image at index $index');
                        return const CircularProgressIndicator();
                      },
                      errorWidget: (context, url, error) {
                        debugPrint('ImageGalleryScreen.itemBuilder: error loading image at index $index: $error');
                        return const Icon(
                          Icons.broken_image,
                          color: Colors.white,
                          size: 48,
                        );
                      },
                    ),
                  ),
                );
              },
            ),
            
            // Close button
            Positioned(
              top: 16,
              right: 16,
              child: IconButton(
                icon: const Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 32,
                ),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            
            // Image counter
            Positioned(
              top: 16,
              left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_currentIndex + 1} / ${widget.imageUrls.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            
            // Caption (if exists)
            if (widget.captions[_currentIndex] != null && 
                widget.captions[_currentIndex]!.isNotEmpty)
              Positioned(
                bottom: 16,
                left: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    widget.captions[_currentIndex]!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}