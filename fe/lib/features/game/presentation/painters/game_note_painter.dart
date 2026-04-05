import 'package:flutter/material.dart';

import '../../domain/game_score.dart';

class GameNotePainter {
  static const double previewWindowMs = 9000;
  static const double cleanupWindowMs = 2500;

  void paintNotes(
    Canvas canvas,
    Size size, {
    required ScoreData score,
    required int currentMs,
    required Set<int> passedNoteIndexes,
    required Set<int> missedNoteIndexes,
    required double playheadX,
    required double trebleTop,
    required double bassTop,
    required double lineSpacing,
  }) {
    for (var i = 0; i < score.notes.length; i++) {
      final note = score.notes[i];
      final delta = note.hitTimeMs - currentMs;
      if (delta > previewWindowMs || delta < -cleanupWindowMs) {
        continue;
      }

      final x = playheadX + delta * 0.10;
      if (x < -30 || x > size.width + 30) {
        continue;
      }

      final isTreble = note.midi >= 60;
      final staffTop = isTreble ? trebleTop : bassTop;
      final y = _yForMidi(note.midi, isTreble, staffTop, lineSpacing);
      final status = passedNoteIndexes.contains(i)
          ? _NoteJudge.pass
          : missedNoteIndexes.contains(i)
          ? _NoteJudge.miss
          : _NoteJudge.pending;

      _drawNoteHead(
        canvas,
        Offset(x, y),
        judge: status,
        isActive: delta.abs() <= 70,
      );
      _drawStem(canvas, Offset(x, y), isTreble: isTreble);
      if (note.accidental != null) {
        _drawSymbolText(
          canvas,
          Offset(x - 18, y - 10),
          note.accidental!,
          color: const Color(0xFF032235),
          fontSize: 18,
        );
      }
    }
  }

  double _yForMidi(int midi, bool isTreble, double staffTop, double spacing) {
    final refMidi = isTreble ? 64 : 43;
    final diff = midi - refMidi;
    return staffTop + spacing * 4 - diff * (spacing / 2);
  }

  void _drawNoteHead(
    Canvas canvas,
    Offset center, {
    required _NoteJudge judge,
    required bool isActive,
  }) {
    final headRect = Rect.fromCenter(center: center, width: 23, height: 16);
    final color = switch (judge) {
      _NoteJudge.pass => const Color(0xFF24A148),
      _NoteJudge.miss => const Color(0xFFD83A52),
      _NoteJudge.pending =>
        isActive ? const Color(0xFF003D5B) : const Color(0xFF14C7CE),
    };
    final fill = Paint()..color = color;
    canvas.drawOval(headRect, fill);
  }

  void _drawStem(Canvas canvas, Offset center, {required bool isTreble}) {
    final p = Paint()
      ..color = const Color(0xFF14C7CE)
      ..strokeWidth = 4;

    if (isTreble) {
      canvas.drawLine(
        Offset(center.dx + 10, center.dy),
        Offset(center.dx + 10, center.dy - 96),
        p,
      );
    } else {
      canvas.drawLine(
        Offset(center.dx - 10, center.dy),
        Offset(center.dx - 10, center.dy + 90),
        p,
      );
    }
  }

  void _drawSymbolText(
    Canvas canvas,
    Offset offset,
    String text, {
    required Color color,
    required double fontSize,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '...',
    )..layout(maxWidth: 140);
    tp.paint(canvas, offset);
  }
}

enum _NoteJudge { pending, pass, miss }
