import 'package:dio/dio.dart';

import '../../../../core/result/result.dart';
import '../../domain/entities/song_entity.dart';
import '../../domain/repositories/song_repository.dart';
import '../datasources/songs_remote_data_source.dart';

class SongRepositoryImpl implements SongRepository {
  final SongsRemoteDataSource _remote;

  SongRepositoryImpl(this._remote);

  @override
  Future<Result<List<SongEntity>>> getSongs({
    int page = 1,
    int pageSize = 20,
    String? search,
  }) async {
    try {
      final songs = await _remote.getSongs(
        page: page,
        pageSize: pageSize,
        search: search,
      );
      return Success<List<SongEntity>>(songs);
    } on DioException catch (e) {
      final responseMessage = e.response?.data is Map<String, dynamic>
          ? (e.response?.data['message'] as String?)
          : null;
      return Failure<List<SongEntity>>(
        responseMessage ?? 'Khong lay duoc danh sach bai hat.',
      );
    } catch (_) {
      return const Failure<List<SongEntity>>(
        'Co loi xay ra khi tai danh sach bai hat.',
      );
    }
  }
}
