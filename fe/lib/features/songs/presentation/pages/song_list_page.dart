import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../cubit/song_cubit.dart';
import '../cubit/song_state.dart';

class SongListPage extends StatefulWidget {
  const SongListPage({super.key});

  @override
  State<SongListPage> createState() => _SongListPageState();
}

class _SongListPageState extends State<SongListPage> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<SongCubit>()..loadSongs(),
      child: Scaffold(
        appBar: AppBar(title: const Text('Danh sach bai hat')),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Tim bai hat...',
                    suffixIcon: IconButton(
                      onPressed: () {
                        context.read<SongCubit>().loadSongs(
                          search: _searchController.text.trim(),
                        );
                      },
                      icon: const Icon(Icons.search),
                    ),
                  ),
                  onSubmitted: (value) {
                    context.read<SongCubit>().loadSongs(search: value);
                  },
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: BlocBuilder<SongCubit, SongState>(
                    builder: (context, state) {
                      if (state is SongLoading) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (state is SongError) {
                        return Center(child: Text(state.message));
                      }

                      if (state is SongLoaded) {
                        if (state.songs.isEmpty) {
                          return const Center(
                            child: Text('Khong co bai hat nao.'),
                          );
                        }

                        return RefreshIndicator(
                          onRefresh: () => context.read<SongCubit>().loadSongs(
                            search: _searchController.text.trim(),
                          ),
                          child: ListView.separated(
                            itemCount: state.songs.length,
                            separatorBuilder: (_, index) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final song = state.songs[index];
                              return ListTile(
                                tileColor: Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHighest,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                title: Text(
                                  song.title.isEmpty
                                      ? '(Khong co ten)'
                                      : song.title,
                                ),
                                subtitle: Text('ID: ${song.id}'),
                              );
                            },
                          ),
                        );
                      }

                      return const SizedBox.shrink();
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
