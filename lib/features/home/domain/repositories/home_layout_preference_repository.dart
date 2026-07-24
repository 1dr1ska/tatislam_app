import 'package:tatislam_app/features/home/domain/entities/home_layout_mode.dart';

abstract class HomeLayoutPreferenceRepository {
  HomeLayoutMode getLayoutMode();

  Future<void> setLayoutMode(HomeLayoutMode mode);
}
