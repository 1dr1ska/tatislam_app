import 'package:tatislam_app/features/publications/domain/entities/publication.dart';

/// Maps a `publications` table row to/from [Publication].
class PublicationModel {
  final String id;
  final String title;
  final String description;
  final String coverImagePath;
  final DateTime publishedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String type;
  final String? status;

  const PublicationModel({
    required this.id,
    required this.title,
    required this.description,
    required this.coverImagePath,
    required this.publishedAt,
    required this.createdAt,
    required this.updatedAt,
    required this.type,
    this.status,
  });

  factory PublicationModel.fromJson(Map<String, dynamic> json) {
    return PublicationModel(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      coverImagePath: json['cover_image_path'] as String? ?? '',
      publishedAt: json['published_at'] != null 
          ? DateTime.parse(json['published_at'] as String) 
          : DateTime.now(),
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'] as String) 
          : DateTime.now(),
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at'] as String) 
          : DateTime.now(),
      type: json['type'] as String? ?? 'article',
      status: json['status'] as String?,
    );
  }

  Map<String, dynamic> toInsertJson() => {
        'title': title,
        'description': description,
        'cover_image_path': coverImagePath,
        'published_at': publishedAt.toIso8601String(),
        'type': type,
        if (status != null) 'status': status,
      };

  Publication toEntity() => Publication(
        id: id,
        title: title,
        description: description,
        coverImagePath: coverImagePath,
        publishedAt: publishedAt,
        createdAt: createdAt,
        updatedAt: updatedAt,
        type: type,
        status: status,
      );
}