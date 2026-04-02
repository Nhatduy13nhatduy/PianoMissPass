import 'package:equatable/equatable.dart';

class SongEntity extends Equatable {
  final String id;
  final String title;
  final String? authorId;
  final String? createdAt;

  const SongEntity({
    required this.id,
    required this.title,
    this.authorId,
    this.createdAt,
  });

  @override
  List<Object?> get props => [id, title, authorId, createdAt];
}
