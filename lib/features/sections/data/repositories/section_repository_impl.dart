import 'package:tatislam_app/features/sections/data/datasources/section_remote_data_source.dart';
import 'package:tatislam_app/features/sections/domain/entities/section.dart';
import 'package:tatislam_app/features/sections/domain/repositories/section_repository.dart';

class SectionRepositoryImpl implements SectionRepository {
  final SectionRemoteDataSource _remote;

  SectionRepositoryImpl(this._remote);

  @override
  Future<List<Section>> getSections({bool includeHidden = false}) async {
    final models = await _remote.getSections(includeHidden: includeHidden);
    return models.map((m) => m.toEntity()).toList();
  }

  @override
  Future<Section> createSection(String name) async {
    final model = await _remote.createSection(name);
    return model.toEntity();
  }

  @override
  Future<Section> renameSection(String id, String name) async {
    final model = await _remote.renameSection(id, name);
    return model.toEntity();
  }

  @override
  Future<Section> setVisibility(String id, bool isVisible) async {
    final model = await _remote.setVisibility(id, isVisible);
    return model.toEntity();
  }

  @override
  Future<void> deleteSection(String id) => _remote.deleteSection(id);

  @override
  Future<void> reorderSections(List<String> orderedIds) =>
      _remote.reorderSections(orderedIds);
  
  @override
  Future<Section?> moveSectionUp(Section section) async {
    final model = await _remote.moveSectionUp(section.id, section.sortOrder);
    return model?.toEntity();
  }
  
  @override
  Future<Section?> moveSectionDown(Section section) async {
    final model = await _remote.moveSectionDown(section.id, section.sortOrder);
    return model?.toEntity();
  }

  @override
  Future<Section> setBackgroundImage(String id, String? backgroundImage) async {
    final model = await _remote.updateBackground(id, backgroundImage);
    return model.toEntity();
  }
}
