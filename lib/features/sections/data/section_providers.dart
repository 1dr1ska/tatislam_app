import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tatislam_app/core/services/supabase_service.dart';
import 'package:tatislam_app/features/sections/data/datasources/section_remote_data_source.dart';
import 'package:tatislam_app/features/sections/data/repositories/section_repository_impl.dart';
import 'package:tatislam_app/features/sections/domain/repositories/section_repository.dart';
import 'package:tatislam_app/features/sections/domain/entities/section.dart';

final sectionRemoteDataSourceProvider = Provider<SectionRemoteDataSource>((ref) {
  return SectionRemoteDataSource(SupabaseService.client);
});

final sectionRepositoryProvider = Provider<SectionRepository>((ref) {
  return SectionRepositoryImpl(ref.watch(sectionRemoteDataSourceProvider));
});

/// Provider for getting sections
final sectionsProvider = FutureProvider<List<Section>>((ref) async {
  debugPrint('Catalog: Starting to fetch sections');
  final repository = ref.watch(sectionRepositoryProvider);
  final result = await repository.getSections();
  debugPrint('Catalog: Finished fetching sections, count: ${result.length}');
  return result;
});
