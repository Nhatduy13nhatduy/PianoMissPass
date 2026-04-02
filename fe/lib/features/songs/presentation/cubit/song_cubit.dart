import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/result/result.dart';
import '../../domain/entities/song_entity.dart';
import '../../domain/usecases/get_songs_use_case.dart';
import 'song_state.dart';

class SongCubit extends Cubit<SongState> {
  final GetSongsUseCase _getSongsUseCase;

  SongCubit(this._getSongsUseCase) : super(const SongInitial());

  Future<void> loadSongs({String? search}) async {
    emit(const SongLoading());

    final result = await _getSongsUseCase(search: search);

    switch (result) {
      case Success<List<SongEntity>>(:final data):
        emit(SongLoaded(data));
      case Failure<List<SongEntity>>(:final message):
        emit(SongError(message));
    }
  }
}
