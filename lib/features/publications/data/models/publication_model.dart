import 'package:tatislam_app/features/publications/domain/entities/publication.dart';

/// Maps a `publications` table row to/from [Publication].
class PublicationModel {
  final String id;
  final String title;
  final String? icon;
  final DateTime publishedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String type;
  final String? status;
  final String primarySectionId;

  const PublicationModel({
    required this.id,
    required this.title,
    this.icon,
    required this.publishedAt,
    required this.createdAt,
    required this.updatedAt,
    required this.type,
    this.status,
    required this.primarySectionId,
  });

  factory PublicationModel.fromJson(Map<String, dynamic> json) {
    return PublicationModel(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      icon: json['icon'] as String?,
      publishedAt: json['published_at'] != null
          ? (DateTime.parse(json['published_at'] as String).toLocal())
          : DateTime.now(),
      createdAt: json['created_at'] != null
          ? (DateTime.parse(json['created_at'] as String).toLocal())
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? (DateTime.parse(json['updated_at'] as String).toLocal())
          : DateTime.now(),
      type: json['type'] as String? ?? 'article',
      status: json['status'] as String?,
      primarySectionId: json['primary_section_id'] as String? ?? '',
    );
  }

  Map<String, dynamic> toInsertJson() => {
    'title': title,
    'published_at': publishedAt.toUtc().toIso8601String(),
    'type': type,
    'primary_section_id': primarySectionId,
    if (icon != null) 'icon': icon,
    if (status != null) 'status': status,
  };

  Publication toEntity() => Publication(
    id: id,
    title: title,
    icon: icon,
    publishedAt: publishedAt,
    createdAt: createdAt,
    updatedAt: updatedAt,
    type: type,
    status: status,
    primarySectionId: primarySectionId,
  );
}
