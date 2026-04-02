import 'package:equatable/equatable.dart';

import '../../domain/entities/song_entity.dart';

abstract class SongState extends Equatable {
  const SongState();

  @override
  List<Object?> get props => [];
}

class SongInitial extends SongState {
  const SongInitial();
}

class SongLoading extends SongState {
  const SongLoading();
}

class SongLoaded extends SongState {
  final List<SongEntity> songs;

  const SongLoaded(this.songs);

  @override
  List<Object?> get props => [songs];
}

class SongError extends SongState {
  final String message;

  const SongError(this.message);

  @override
  List<Object?> get props => [message];
}
