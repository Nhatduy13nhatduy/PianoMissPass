import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/game_score.dart';
import '../../domain/note_timing.dart';

class GameKeyboardPainter {
  static const int _activeWindowMs = 100;

  void paintKeyboard(
    Canvas canvas,
    Size size, {
    required ScoreData score,
    required int currentMs,
    required double keyboardTop,
  }) {
    const whiteHeight = 92.0 * 0.7;
    const blackHeight = 54.0 * 0.7;

    final startMidi = score.minMidi - 2;
    final endMidi = score.maxMidi + 2;

    final midiRange = <int>[
      for (var midi = startMidi; midi <= endMidi; midi++) midi,
    ];
    final whiteMidis = midiRange.where((m) => !_isBlack(m)).toList();

    final whiteWidth = size.width / math.max(whiteMidis.length, 1);
    final blackWidth = whiteWidth * 0.62;

    final active = <int>{};
    final startTime = currentMs - _activeWindowMs;
    final endTime = currentMs + _activeWindowMs;
    final startIndex = _lowerBoundHitTime(score.notes, startTime);
    final endIndex = _upperBoundHitTime(score.notes, endTime);
    for (var i = startIndex; i < endIndex; i++) {
      final note = score.notes[i];
      if ((NoteTiming.adjustedHitTimeMs(note) - currentMs).abs() <=
          _activeWindowMs) {
        active.add(note.midi);
      }
    }

    var whiteIndex = 0;
    for (final midi in midiRange) {
      if (_isBlack(midi)) {
        continue;
      }

      final x = whiteIndex * whiteWidth;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, keyboardTop, whiteWidth - 1, whiteHeight),
        const Radius.circular(6),
      );
      final isActive = active.contains(midi);
      final fill = Paint()
        ..color = isActive ? const Color(0xFF8A6DB8) : const Color(0xFFE7EBF0);
      final border = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = const Color(0xFF0F1720);

      canvas.drawRRect(rect, fill);
      canvas.drawRRect(rect, border);
      whiteIndex++;
    }

    whiteIndex = 0;
    for (final midi in midiRange) {
      if (_isBlack(midi)) {
        final x = whiteIndex * whiteWidth - blackWidth / 2;
        final rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(x, keyboardTop, blackWidth, blackHeight),
          const Radius.circular(5),
        );
        final isActive = active.contains(midi);
        final fill = Paint()
          ..color = isActive
              ? const Color(0xFF4E5BFF)
              : const Color(0xFF1A1A1C);
        canvas.drawRRect(rect, fill);
      } else {
        whiteIndex++;
      }
    }
  }

  bool _isBlack(int midi) {
    final pc = midi % 12;
    return pc == 1 || pc == 3 || pc == 6 || pc == 8 || pc == 10;
  }

  int _lowerBoundHitTime(List<MusicNote> notes, int targetMs) {
    var low = 0;
    var high = notes.length;
    while (low < high) {
      final mid = low + ((high - low) >> 1);
      if (notes[mid].hitTimeMs < targetMs) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    return low;
  }

  int _upperBoundHitTime(List<MusicNote> notes, int targetMs) {
    var low = 0;
    var high = notes.length;
    while (low < high) {
      final mid = low + ((high - low) >> 1);
      if (notes[mid].hitTimeMs <= targetMs) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    return low;
  }
}
