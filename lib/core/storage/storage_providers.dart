import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tatislam_app/core/services/supabase_service.dart';
import 'package:tatislam_app/core/storage/media_storage_repository.dart';
import 'package:tatislam_app/core/storage/yandex_media_storage_repository.dart';

final mediaStorageRepositoryProvider = Provider<MediaStorageRepository>((ref) {
  return YandexMediaStorageRepository(SupabaseService.client);
});
