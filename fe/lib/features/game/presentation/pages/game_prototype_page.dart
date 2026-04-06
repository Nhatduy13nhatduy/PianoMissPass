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
  static const bool _debugHideLowerStaff = false;

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
    final topPadding = 48.0;
    final baseStaffHeight = (size.height - 170 - topPadding - 16) / 2;
    final staffHeight = baseStaffHeight * 0.7;
    const staffGap = 100;

    final trebleTop = topPadding;
    final bassTop = trebleTop + staffHeight + staffGap;
    final effectiveBassTop = _debugHideLowerStaff
        ? size.height + 1000
        : bassTop;
    final stavesBottomY = _debugHideLowerStaff
        ? trebleTop + staffHeight
        : bassTop + staffHeight;
    final lineSpacing = staffHeight / 4;

    _staffPainter.paint(
      canvas,
      Rect.fromLTWH(18, trebleTop, size.width - 36, staffHeight),
      lineSpacing,
    );
    if (!_debugHideLowerStaff) {
      _staffPainter.paint(
        canvas,
        Rect.fromLTWH(18, bassTop, size.width - 36, staffHeight),
        lineSpacing,
      );
    }

    final activeTrebleClef = _activeClefSign(
      score,
      currentMs: currentMs,
      staffNumber: 1,
      fallback: 'G',
    );
    final activeBassClef = _activeClefSign(
      score,
      currentMs: currentMs,
      staffNumber: 2,
      fallback: 'F',
    );

    _textPainter.paintClef(
      canvas,
      Offset(28, trebleTop + lineSpacing * 0.2),
      _glyphForClefSign(activeTrebleClef),
      72,
    );
    if (!_debugHideLowerStaff) {
      _textPainter.paintClef(
        canvas,
        Offset(30, bassTop + lineSpacing * 0.6),
        _glyphForClefSign(activeBassClef),
        54,
      );
    }

    final activeKeyFifths = _activeKeyFifths(score, currentMs);
    if (_shouldUseKeySignature(activeKeyFifths)) {
      _paintKeySignature(
        canvas,
        fifths: activeKeyFifths,
        trebleTop: trebleTop,
        bassTop: bassTop,
        lineSpacing: lineSpacing,
        drawBass: !_debugHideLowerStaff,
      );
    }

    final symbolPaint = Paint()
      ..color = const Color(0xFF0D3750)
      ..strokeWidth = 2.2;
    final measureLinePaint = Paint()
      ..color = const Color(0xFF506473)
      ..strokeWidth = 1.3;
    const measureLineOffsetX = -20.0;
    canvas.drawLine(
      Offset(playheadX, trebleTop),
      Offset(playheadX, stavesBottomY),
      symbolPaint,
    );

    final visibleSymbols = score.symbols.where((symbol) {
      final delta = symbol.timeMs - currentMs;
      return delta <= GameNotePainter.previewWindowMs &&
          delta >= -GameNotePainter.cleanupWindowMs;
    });

    for (final symbol in visibleSymbols) {
      final x =
          playheadX + (symbol.timeMs - currentMs) * GameNotePainter.notePxPerMs;
      if (x < 10 || x > size.width - 10) {
        continue;
      }

      if (symbol.label == '|') {
        final measureX = x + measureLineOffsetX;
        canvas.drawLine(
          Offset(measureX, trebleTop),
          Offset(measureX, stavesBottomY),
          measureLinePaint,
        );
        continue;
      }

      if (symbol.label.startsWith('Key ')) {
        continue;
      }

      if (symbol.label.startsWith('Clef:')) {
        final parsed = _parseClefSymbol(symbol.label);
        if (parsed == null) {
          continue;
        }
        final clefDeltaMs = symbol.timeMs - currentMs;
        if (clefDeltaMs < -900 || clefDeltaMs > 2200) {
          continue;
        }
        final isTrebleStaff = parsed.staffNumber == 1;
        if (!isTrebleStaff && _debugHideLowerStaff) {
          continue;
        }
        final proximity = (1 - (clefDeltaMs.abs() / 2200))
            .clamp(0.0, 1.0)
            .toDouble();
        final glyph = _glyphForClefSign(parsed.sign);
        final xOffset = -lineSpacing * (1.8 - proximity * 0.35);
        final y = isTrebleStaff
            ? trebleTop + lineSpacing * 0.16
            : bassTop + lineSpacing * 0.5;
        final fontSize = isTrebleStaff
            ? 30 + proximity * 9
            : 26 + proximity * 7;
        _textPainter.paintClef(canvas, Offset(x + xOffset, y), glyph, fontSize);
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
      bassTop: effectiveBassTop,
      lineSpacing: lineSpacing,
    );

    _keyboardPainter.paintKeyboard(
      canvas,
      size,
      score: score,
      currentMs: currentMs,
      keyboardTop: size.height - 50,
    );
  }

  @override
  bool shouldRepaint(covariant _StaffScrollerPainter oldDelegate) {
    return oldDelegate.currentMs != currentMs ||
        oldDelegate.score != score ||
        oldDelegate.passedNoteIndexes != passedNoteIndexes ||
        oldDelegate.missedNoteIndexes != missedNoteIndexes;
  }

  int _activeKeyFifths(ScoreData score, int timeMs) {
    var result = 0;
    for (final change in score.keySignatures) {
      if (change.timeMs <= timeMs) {
        result = change.fifths;
      } else {
        break;
      }
    }
    return result;
  }

  bool _shouldUseKeySignature(int fifths) {
    return fifths.abs() >= 2;
  }

  String _activeClefSign(
    ScoreData score, {
    required int currentMs,
    required int staffNumber,
    required String fallback,
  }) {
    var sign = fallback;
    for (final symbol in score.symbols) {
      if (symbol.timeMs > currentMs) {
        break;
      }
      final parsed = _parseClefSymbol(symbol.label);
      if (parsed == null || parsed.staffNumber != staffNumber) {
        continue;
      }
      sign = parsed.sign;
    }
    return sign;
  }

  _ClefSymbol? _parseClefSymbol(String label) {
    if (!label.startsWith('Clef:')) {
      return null;
    }
    final parts = label.split(':');
    if (parts.length != 3) {
      return null;
    }

    final staffNumber = int.tryParse(parts[1]);
    final sign = parts[2].trim().toUpperCase();
    if (staffNumber == null || (sign != 'G' && sign != 'F')) {
      return null;
    }

    return _ClefSymbol(staffNumber: staffNumber, sign: sign);
  }

  String _glyphForClefSign(String sign) {
    return sign == 'F' ? '𝄢' : '𝄞';
  }

  void _paintKeySignature(
    Canvas canvas, {
    required int fifths,
    required double trebleTop,
    required double bassTop,
    required double lineSpacing,
    bool drawBass = true,
  }) {
    if (fifths == 0) {
      return;
    }

    final count = fifths.abs().clamp(0, 7);
    final isSharp = fifths > 0;
    final glyph = isSharp ? '♯' : '♭';
    final fontSize = (lineSpacing * 2.2).clamp(15.0, 28.0);
    final startX = 74.0;
    final spacingX = (lineSpacing * 1.2).clamp(8.0, 13.0);

    final trebleSteps = isSharp
        ? const [38, 35, 39, 36, 33, 37, 34]
        : const [34, 37, 33, 36, 32, 35, 31];
    final bassSteps = isSharp
        ? const [24, 21, 25, 22, 19, 23, 20]
        : const [20, 23, 19, 22, 18, 21, 17];

    for (var i = 0; i < count; i++) {
      final x = startX + i * spacingX;
      final trebleY = _yForStaffStep(
        trebleSteps[i],
        isTreble: true,
        staffTop: trebleTop,
        spacing: lineSpacing,
      );
      final bassY = _yForStaffStep(
        bassSteps[i],
        isTreble: false,
        staffTop: bassTop,
        spacing: lineSpacing,
      );

      _textPainter.paintText(
        canvas,
        Offset(x, trebleY - fontSize * 0.62),
        glyph,
        color: const Color(0xFF0E1620),
        fontSize: fontSize,
        fontWeight: FontWeight.w700,
        maxWidth: 40,
      );
      if (drawBass) {
        _textPainter.paintText(
          canvas,
          Offset(x, bassY - fontSize * 0.62),
          glyph,
          color: const Color(0xFF0E1620),
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          maxWidth: 40,
        );
      }
    }
  }

  double _yForStaffStep(
    int staffStep, {
    required bool isTreble,
    required double staffTop,
    required double spacing,
  }) {
    final refStep = isTreble ? 30 : 18;
    final diff = staffStep - refStep;
    return staffTop + spacing * 4 - diff * (spacing / 2);
  }
}

class _ClefSymbol {
  const _ClefSymbol({required this.staffNumber, required this.sign});

  final int staffNumber;
  final String sign;
}
