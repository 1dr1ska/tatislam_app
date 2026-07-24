import 'package:equatable/equatable.dart';

/// Publication metadata only — used everywhere a publication is listed
/// (home feed/cards, catalog, search, favorites). The full body (content
/// blocks) and section memberships are loaded separately as
/// [PublicationDetail], only when a single publication is opened.
class Publication extends Equatable {
  final String id;
  final String title;
  final String description;

  /// Storage path (e.g. `covers/<id>.jpg`) — never a public URL.
  final String coverImagePath;
  final DateTime publishedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String type;
  final String? status;

  const Publication({
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

  Publication copyWith({
    String? title,
    String? description,
    String? coverImagePath,
    DateTime? publishedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? type,
    String? status,
  }) {
    return Publication(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      coverImagePath: coverImagePath ?? this.coverImagePath,
      publishedAt: publishedAt ?? this.publishedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      type: type ?? this.type,
      status: status ?? this.status,
    );
  }

  @override
  List<Object?> get props => [
        id,
        title,
        description,
        coverImagePath,
        publishedAt,
        createdAt,
        updatedAt,
        type,
        status,
      ];
}