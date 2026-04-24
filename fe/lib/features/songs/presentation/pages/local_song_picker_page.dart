import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../game/presentation/pages/game_prototype_page.dart';

class LocalSongPickerPage extends StatefulWidget {
  const LocalSongPickerPage({super.key});

  @override
  State<LocalSongPickerPage> createState() => _LocalSongPickerPageState();
}

class _LocalSongPickerPageState extends State<LocalSongPickerPage> {
  late final Future<List<_LocalSongAsset>> _songsFuture = _loadSongs();

  Future<List<_LocalSongAsset>> _loadSongs() async {
    final assetManifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final assetPaths =
        assetManifest
            .listAssets()
            .where(
              (path) =>
                  path.startsWith('assets/mxl/') &&
                  path.toLowerCase().endsWith('.mxl'),
            )
            .toList()
          ..sort();

    return assetPaths
        .map(
          (path) => _LocalSongAsset(
            assetPath: path,
            title: path.split('/').last.replaceAll('.mxl', ''),
          ),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chon bai hat')),
      body: FutureBuilder<List<_LocalSongAsset>>(
        future: _songsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Khong doc duoc danh sach bai hat.\n${snapshot.error}',
                ),
              ),
            );
          }

          final songs = snapshot.data ?? const <_LocalSongAsset>[];
          if (songs.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Chua co file .mxl trong assets/mxl/.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: songs.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final song = songs[index];
              return ListTile(
                tileColor: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                leading: const Icon(Icons.library_music_outlined),
                title: Text(song.title),
                subtitle: Text(song.assetPath),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => GamePrototypePage(
                        assetMxlPath: song.assetPath,
                        songTitle: song.title,
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _LocalSongAsset {
  const _LocalSongAsset({required this.assetPath, required this.title});

  final String assetPath;
  final String title;
}
