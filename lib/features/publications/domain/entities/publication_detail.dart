import 'package:equatable/equatable.dart';
import 'package:tatislam_app/features/publications/domain/entities/content_block.dart';
import 'package:tatislam_app/features/publications/domain/entities/publication.dart';

/// A publication together with its full body and section memberships.
///
/// Loaded only when a single publication is opened (detail screen, admin
/// editor) — lists use the lighter [Publication] instead, avoiding N+1
/// fetches of blocks that are never rendered.
class PublicationDetail extends Equatable {
  final Publication publication;

  /// Ordered by [ContentBlock.orderIndex].
  final List<ContentBlock> blocks;

  final List<String> sectionIds;

  const PublicationDetail({
    required this.publication,
    required this.blocks,
    required this.sectionIds,
  });

  @override
  List<Object?> get props => [publication, blocks, sectionIds];
}
