import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/game_score.dart';
import '../cubit/game_prototype_cubit.dart';
import '../cubit/game_prototype_state.dart';
import '../painters/game_keyboard_painter.dart';
import '../painters/game_note_painter.dart';
import '../painters/game_staff_painter.dart';
import '../painters/game_text_painter.dart';

class GamePrototypePage extends StatelessWidget {
  const GamePrototypePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => GamePrototypeCubit()..initialize(),
      child: const _GamePrototypeChromeScope(),
    );
  }
}

class _GamePrototypeChromeScope extends StatefulWidget {
  const _GamePrototypeChromeScope();

  @override
  State<_GamePrototypeChromeScope> createState() =>
      _GamePrototypeChromeScopeState();
}

class _GamePrototypeChromeScopeState extends State<_GamePrototypeChromeScope> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocBuilder<GamePrototypeCubit, GamePrototypeState>(
        builder: (context, state) {
          if (state.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state.errorMessage != null) {
            return _ErrorView(
              error: state.errorMessage!,
              onRetry: () => context.read<GamePrototypeCubit>().retry(),
            );
          }

          final score = state.score;
          if (score == null) {
            return const SizedBox.shrink();
          }

          return CustomPaint(
            painter: _StaffScrollerPainter(
              score: score,
              currentMs: state.elapsedMs,
              passedNoteIndexes: state.passedNoteIndexes,
              missedNoteIndexes: state.missedNoteIndexes,
            ),
            child: const SizedBox.expand(),
          );
        },
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
          const SizedBox(height: 8),
          const Text('Khong tai duoc file MXL mau'),
          const SizedBox(height: 8),
          Text(
            error,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: const Text('Thu lai')),
        ],
      ),
    );
  }
}

class _StaffScrollerPainter extends CustomPainter {
  _StaffScrollerPainter({
    required this.score,
    required this.currentMs,
    required this.passedNoteIndexes,
    required this.missedNoteIndexes,
  });

  final ScoreData score;
  final int currentMs;
  final Set<int> passedNoteIndexes;
  final Set<int> missedNoteIndexes;

  final GameStaffPainter _staffPainter = GameStaffPainter();
  final GameTextPainter _textPainter = GameTextPainter();
  final GameNotePainter _notePainter = GameNotePainter();
  final GameKeyboardPainter _keyboardPainter = GameKeyboardPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final playheadX = size.width * 0.72;
    final topPadding = 32.0;
    final staffHeight = (size.height - 170 - topPadding - 16) / 2;

    final trebleTop = topPadding;
    final bassTop = trebleTop + staffHeight + 26;
    final lineSpacing = staffHeight / 4;

    _staffPainter.paint(
      canvas,
      Rect.fromLTWH(18, trebleTop, size.width - 36, staffHeight),
      lineSpacing,
    );
    _staffPainter.paint(
      canvas,
      Rect.fromLTWH(18, bassTop, size.width - 36, staffHeight),
      lineSpacing,
    );

    _textPainter.paintClef(
      canvas,
      Offset(28, trebleTop + lineSpacing * 0.2),
      '𝄞',
      72,
    );
    _textPainter.paintClef(
      canvas,
      Offset(30, bassTop + lineSpacing * 0.6),
      '𝄢',
      54,
    );

    final symbolPaint = Paint()
      ..color = const Color(0xFF0D3750)
      ..strokeWidth = 2.2;
    canvas.drawLine(
      Offset(playheadX, trebleTop),
      Offset(playheadX, bassTop + staffHeight),
      symbolPaint,
    );

    final visibleSymbols = score.symbols.where((symbol) {
      final delta = symbol.timeMs - currentMs;
      return delta <= GameNotePainter.previewWindowMs &&
          delta >= -GameNotePainter.cleanupWindowMs;
    });

    for (final symbol in visibleSymbols) {
      final x = playheadX + (symbol.timeMs - currentMs) * 0.10;
      if (x < 10 || x > size.width - 10) {
        continue;
      }
      _textPainter.paintText(
        canvas,
        Offset(x + 4, trebleTop - 16),
        symbol.label,
        color: const Color(0xFF0B2F44),
        fontSize: 14,
      );
    }

    _notePainter.paintNotes(
      canvas,
      size,
      score: score,
      currentMs: currentMs,
      passedNoteIndexes: passedNoteIndexes,
      missedNoteIndexes: missedNoteIndexes,
      playheadX: playheadX,
      trebleTop: trebleTop,
      bassTop: bassTop,
      lineSpacing: lineSpacing,
    );

    _keyboardPainter.paintKeyboard(
      canvas,
      size,
      score: score,
      currentMs: currentMs,
      keyboardTop: size.height - 92,
    );
  }

  @override
  bool shouldRepaint(covariant _StaffScrollerPainter oldDelegate) {
    return oldDelegate.currentMs != currentMs ||
        oldDelegate.score != score ||
        oldDelegate.passedNoteIndexes != passedNoteIndexes ||
        oldDelegate.missedNoteIndexes != missedNoteIndexes;
  }
}
