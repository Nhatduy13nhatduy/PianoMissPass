import '../../domain/entities/song_entity.dart';

class SongModel extends SongEntity {
  const SongModel({
    required super.id,
    required super.title,
    super.authorId,
    super.createdAt,
  });

  factory SongModel.fromJson(Map<String, dynamic> json) {
    return SongModel(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      authorId: json['authorId']?.toString(),
      createdAt: json['createdAt']?.toString(),
    );
  }
}
