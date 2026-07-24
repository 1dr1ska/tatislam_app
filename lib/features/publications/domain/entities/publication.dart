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
  final String? content;
  final String? imageUrl;
  final String? mediaUrl;
  final String? videoProvider;

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
    this.content,
    this.imageUrl,
    this.mediaUrl,
    this.videoProvider,
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
    String? content,
    String? imageUrl,
    String? mediaUrl,
    String? videoProvider,
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
      content: content ?? this.content,
      imageUrl: imageUrl ?? this.imageUrl,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      videoProvider: videoProvider ?? this.videoProvider,
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
        content,
        imageUrl,
        mediaUrl,
        videoProvider,
      ];
}
