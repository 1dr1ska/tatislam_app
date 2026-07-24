import 'package:tatislam_app/core/services/local_storage_service.dart';
import 'package:tatislam_app/features/home/domain/entities/home_layout_mode.dart';
import 'package:tatislam_app/features/home/domain/repositories/home_layout_preference_repository.dart';

class HomeLayoutPreferenceRepositoryImpl implements HomeLayoutPreferenceRepository {
  static const _key = 'home_layout_mode';

  @override
  HomeLayoutMode getLayoutMode() {
    final stored = LocalStorageService.settingsBox.get(_key) as String?;
    return HomeLayoutMode.fromWireValue(stored);
  }

  @override
  Future<void> setLayoutMode(HomeLayoutMode mode) {
    return LocalStorageService.settingsBox.put(_key, mode.wireValue);
  }
}
