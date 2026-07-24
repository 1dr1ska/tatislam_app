import 'package:tatislam_app/features/publications/domain/entities/video_provider_type.dart';

/// Detects the [VideoProviderType] from an arbitrary video URL, so the admin
/// never has to pick a provider manually — they just paste a link.
class VideoProviderDetector {
  VideoProviderDetector._();

  static VideoProviderType detect(String url) {
    final host = Uri.tryParse(url.trim())?.host.toLowerCase() ?? '';

    if (host.contains('youtube.com') || host.contains('youtu.be')) {
      return VideoProviderType.youtube;
    }
    if (host.contains('rutube.ru')) {
      return VideoProviderType.rutube;
    }
    if (host.contains('vk.com') || host.contains('vkvideo.ru')) {
      return VideoProviderType.vk;
    }
    return VideoProviderType.direct;
  }
}
