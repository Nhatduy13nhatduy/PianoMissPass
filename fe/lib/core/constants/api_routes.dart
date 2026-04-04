class ApiRoutes {
  static const String auth = '/api/auth';
  static const String register = '$auth/register';
  static const String login = '$auth/login';
  static const String refresh = '$auth/refresh';
  static const String revoke = '$auth/revoke';
  static const String verifyEmail = '$auth/verify-email';
  static const String resendVerification = '$auth/resend-verification';
  static const String forgotPassword = '$auth/forgot-password';
  static const String resetPassword = '$auth/reset-password';
  static const String changePassword = '$auth/change-password';

  static const String songs = '/api/songs';
  static const String songsDetail = '/api/songs/detail';
  static const String sheets = '/api/sheets';
  static const String users = '/api/users';
  static const String playlists = '/api/playlists';
  static const String dataAssets = '/api/dataassets';
  static const String dataAssetsUploadMxl = '/api/dataassets/upload/mxl';
  static const String dataAssetsUpload = '/api/dataassets/upload';
  static const String dataAssetsUploadMusicXml = '/api/dataassets/upload/musicxml';
  static const String genres = '/api/genres';
  static const String instruments = '/api/instruments';
  static const String userSheetPoints = '/api/usersheetpoints';
  static const String userSheetLikes = '/api/usersheetlikes';
  static const String genreSongs = '/api/genresongs';
  static const String userFavoriteSongs = '/api/userfavoritesongs';
  static const String playlistSongs = '/api/playlistsongs';
}
