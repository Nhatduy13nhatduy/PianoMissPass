import '../../../../core/result/result.dart';
import '../entities/song_entity.dart';
import '../repositories/song_repository.dart';

class GetSongsUseCase {
  final SongRepository _repository;

  GetSongsUseCase(this._repository);

  Future<Result<List<SongEntity>>> call({
    int page = 1,
    int pageSize = 20,
    String? search,
  }) {
    return _repository.getSongs(page: page, pageSize: pageSize, search: search);
  }
}
