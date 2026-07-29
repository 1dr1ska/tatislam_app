import 'package:equatable/equatable.dart';

/// Publication metadata only — used everywhere a publication is listed
/// (home feed/cards, catalog, search, favorites). The full body (content
/// blocks) and section memberships are loaded separately as
/// [PublicationDetail], only when a single publication is opened.
class Publication extends Equatable {
  final String id;
  final String title;
  final String description;

  /// Icon identifier (e.g. 'book', 'audio', 'video') — maps to a local asset.
  final String? icon;
  final DateTime publishedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String type;
  final String? status;

  /// The primary section that defines this publication's visual identity
  /// (background, icon, etc.).
  final String primarySectionId;

  const Publication({
    required this.id,
    required this.title,
    required this.description,
    this.icon,
    required this.publishedAt,
    required this.createdAt,
    required this.updatedAt,
    required this.type,
    this.status,
    required this.primarySectionId,
  });

  Publication copyWith({
    String? title,
    String? description,
    String? icon,
    DateTime? publishedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? type,
    String? status,
    String? primarySectionId,
  }) {
    return Publication(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      publishedAt: publishedAt ?? this.publishedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      type: type ?? this.type,
      status: status ?? this.status,
      primarySectionId: primarySectionId ?? this.primarySectionId,
    );
  }

  @override
  List<Object?> get props => [
        id,
        title,
        description,
        icon,
        publishedAt,
        createdAt,
        updatedAt,
        type,
        status,
        primarySectionId,
      ];
}