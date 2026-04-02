import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/auth/data/datasources/auth_remote_data_source.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/domain/usecases/login_use_case.dart';
import '../../features/auth/presentation/cubit/auth_cubit.dart';
import '../../features/songs/data/datasources/songs_remote_data_source.dart';
import '../../features/songs/data/repositories/song_repository_impl.dart';
import '../../features/songs/domain/repositories/song_repository.dart';
import '../../features/songs/domain/usecases/get_songs_use_case.dart';
import '../../features/songs/presentation/cubit/song_cubit.dart';
import '../network/dio_client.dart';
import '../storage/token_storage.dart';

final sl = GetIt.instance;

Future<void> configureDependencies() async {
  final prefs = await SharedPreferences.getInstance();

  sl.registerLazySingleton<SharedPreferences>(() => prefs);
  sl.registerLazySingleton<TokenStorage>(() => TokenStorage(sl()));
  sl.registerLazySingleton<DioClient>(() => DioClient(sl()));
  sl.registerLazySingleton<Dio>(() => sl<DioClient>().instance);

  sl.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSourceImpl(sl()),
  );
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(sl(), sl()),
  );
  sl.registerLazySingleton<LoginUseCase>(() => LoginUseCase(sl()));
  sl.registerFactory<AuthCubit>(() => AuthCubit(sl()));

  sl.registerLazySingleton<SongsRemoteDataSource>(
    () => SongsRemoteDataSourceImpl(sl()),
  );
  sl.registerLazySingleton<SongRepository>(() => SongRepositoryImpl(sl()));
  sl.registerLazySingleton<GetSongsUseCase>(() => GetSongsUseCase(sl()));
  sl.registerFactory<SongCubit>(() => SongCubit(sl()));
}
