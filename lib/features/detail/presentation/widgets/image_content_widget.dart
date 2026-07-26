import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:tatislam_app/core/storage/media_storage_repository.dart';
import 'package:tatislam_app/features/detail/presentation/screens/image_viewer_screen.dart';
import 'package:tatislam_app/features/publications/domain/entities/content_block.dart';

/// Renders an [ImageContentBlock] with a tappable preview that opens
/// [ImageViewerScreen] on full screen.
///
/// The image is displayed in a fixed 3:2 container with [BoxFit.contain],
/// centered by default.
class ImageContentWidget extends StatelessWidget {
  final ImageContentBlock block;
  final MediaStorageRepository mediaStorage;

  const ImageContentWidget({
    super.key,
    required this.block,
    required this.mediaStorage,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = mediaStorage.publicUrlFor(block.imagePath);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: Column(
        children: [
          GestureDetector(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => ImageViewerScreen(
                    imageUrl: imageUrl,
                    caption: block.caption,
                  ),
                ),
              );
            },
            child: AspectRatio(
              aspectRatio: 3 / 2,
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                width: double.infinity,
                fit: BoxFit.contain,
                placeholder: (context, url) =>
                    const Center(child: CircularProgressIndicator()),
                errorWidget: (context, url, error) =>
                    const Icon(Icons.image, size: 64),
              ),
            ),
          ),
          if (block.caption != null && block.caption!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(block.caption!),
            ),
        ],
      ),
    );
  }
}