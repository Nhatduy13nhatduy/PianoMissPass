import 'package:dio/dio.dart';

import '../../../../core/constants/api_routes.dart';
import '../models/song_model.dart';

abstract class SongsRemoteDataSource {
  Future<List<SongModel>> getSongs({int page, int pageSize, String? search});
}

class SongsRemoteDataSourceImpl implements SongsRemoteDataSource {
  final Dio _dio;

  SongsRemoteDataSourceImpl(this._dio);

  @override
  Future<List<SongModel>> getSongs({
    int page = 1,
    int pageSize = 20,
    String? search,
  }) async {
    final response = await _dio.get(
      ApiRoutes.songs,
      queryParameters: {
        'page': page,
        'pageSize': pageSize,
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      },
    );

    final data = response.data;
    if (data is List) {
      return data
          .map((e) => SongModel.fromJson(e as Map<String, dynamic>))
          .toList(growable: false);
    }

    if (data is Map<String, dynamic>) {
      final items = data['items'] ?? data['data'] ?? data['result'];
      if (items is List) {
        return items
            .map((e) => SongModel.fromJson(e as Map<String, dynamic>))
            .toList(growable: false);
      }
    }

    return const <SongModel>[];
  }
}
