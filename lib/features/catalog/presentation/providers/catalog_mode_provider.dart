import 'package:flutter_riverpod/legacy.dart';
import 'package:tatislam_app/features/catalog/domain/entities/catalog_mode.dart';

final catalogModeProvider = StateProvider<CatalogMode>((ref) {
  return CatalogMode.all;
});
