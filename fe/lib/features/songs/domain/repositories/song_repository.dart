import '../../../../core/result/result.dart';
import '../entities/song_entity.dart';

abstract class SongRepository {
  Future<Result<List<SongEntity>>> getSongs({
    int page,
    int pageSize,
    String? search,
  });
}
