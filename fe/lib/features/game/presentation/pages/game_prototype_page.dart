import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:async';

import 'package:archive/archive.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_midi_command/flutter_midi_command.dart';
import 'package:xml/xml.dart';

class GamePrototypePage extends StatefulWidget {
  const GamePrototypePage({super.key});

  @override
  State<GamePrototypePage> createState() => _GamePrototypePageState();
}

class _GamePrototypePageState extends State<GamePrototypePage>
    with SingleTickerProviderStateMixin {
  static const String _sampleMxlUrl =
      'https://res.cloudinary.com/dnx5e59hz/raw/upload/v1775314886/pianomisspass/canon-in-d-johann-pachelbel_ece4o3.mxl';

  late final Ticker _ticker;
  final Stopwatch _stopwatch = Stopwatch();

  ScoreData? _score;
  String? _error;
  bool _isLoading = true;
  bool _isPlaying = false;
  int _baseElapsedMs = 0;

  final MidiCommand _midiCommand = MidiCommand();
  StreamSubscription<MidiPacket>? _midiSub;
  StreamSubscription<String>? _midiSetupSub;
  MidiDevice? _connectedDevice;
  final Set<int> _passedNoteIndexes = <int>{};
  final Set<int> _missedNoteIndexes = <int>{};

  static const int _hitWindowMs = 180;
  static const int _missWindowMs = 220;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _ticker = createTicker((_) {
      if (!mounted || !_isPlaying) {
        return;
      }

      _updateMisses();

      if (_currentMs >= _maxDurationMs) {
        _pause();
      }
      setState(() {});
    });
    _setupMidi();
    _loadMxl();
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
    _midiSub?.cancel();
    _midiSetupSub?.cancel();
    if (_connectedDevice != null) {
      _midiCommand.disconnectDevice(_connectedDevice!);
    }
    _ticker.dispose();
    _stopwatch
      ..stop()
      ..reset();
    super.dispose();
  }

  int get _currentMs {
    if (!_isPlaying) {
      return _baseElapsedMs;
    }
    return _baseElapsedMs + _stopwatch.elapsedMilliseconds;
  }

  int get _maxDurationMs {
    final score = _score;
    if (score == null || score.notes.isEmpty) {
      return 10000;
    }

    final last = score.notes
        .map((e) => e.hitTimeMs + math.max(e.holdMs, 180))
        .reduce(math.max);
    return last.toInt() + 2400;
  }

  Future<void> _setupMidi() async {
    try {
      await _connectFirstMidiDevice();
      _midiSetupSub = _midiCommand.onMidiSetupChanged?.listen((_) {
        _connectFirstMidiDevice();
      });

      _midiSub = _midiCommand.onMidiDataReceived?.listen((packet) {
        _handleMidiPacket(packet.data);
      });
    } catch (_) {
      // Keep gameplay running even if MIDI is unavailable on the device.
    }
  }

  Future<void> _connectFirstMidiDevice() async {
    try {
      final devices = await _midiCommand.devices ?? const <MidiDevice>[];
      if (devices.isEmpty) {
        _connectedDevice = null;
        return;
      }

      if (_connectedDevice != null &&
          devices.any((d) => d.id == _connectedDevice!.id)) {
        return;
      }

      final target = devices.first;
      await _midiCommand.connectToDevice(target);
      _connectedDevice = target;
    } catch (_) {
      _connectedDevice = null;
    }
  }

  void _handleMidiPacket(List<int> data) {
    if (data.length < 3 || _score == null || !_isPlaying) {
      return;
    }

    final status = data[0] & 0xF0;
    final note = data[1];
    final velocity = data[2];

    // Note-on message with velocity > 0.
    if (status != 0x90 || velocity == 0) {
      return;
    }

    _judgeNoteInput(note);
  }

  void _judgeNoteInput(int midiNote) {
    final score = _score;
    if (score == null) {
      return;
    }

    var bestIndex = -1;
    var bestDelta = 1 << 30;

    for (var i = 0; i < score.notes.length; i++) {
      if (_passedNoteIndexes.contains(i) || _missedNoteIndexes.contains(i)) {
        continue;
      }

      final expected = score.notes[i];
      if (expected.midi != midiNote) {
        continue;
      }

      final delta = (expected.hitTimeMs - _currentMs).abs();
      if (delta <= _hitWindowMs && delta < bestDelta) {
        bestDelta = delta;
        bestIndex = i;
      }
    }

    if (bestIndex >= 0) {
      _passedNoteIndexes.add(bestIndex);
      setState(() {});
    }
  }

  void _updateMisses() {
    final score = _score;
    if (score == null) {
      return;
    }

    var changed = false;
    for (var i = 0; i < score.notes.length; i++) {
      if (_passedNoteIndexes.contains(i) || _missedNoteIndexes.contains(i)) {
        continue;
      }

      final note = score.notes[i];
      if (_currentMs - note.hitTimeMs > _missWindowMs) {
        _missedNoteIndexes.add(i);
        changed = true;
      }
    }

    if (changed) {
      setState(() {});
    }
  }

  Future<void> _loadMxl() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _isPlaying = false;
      _baseElapsedMs = 0;
      _passedNoteIndexes.clear();
      _missedNoteIndexes.clear();
      _ticker.stop();
      _stopwatch
        ..stop()
        ..reset();
    });

    try {
      final response = await Dio().get<List<int>>(
        _sampleMxlUrl,
        options: Options(responseType: ResponseType.bytes),
      );
      final bytes = response.data;
      if (bytes == null || bytes.isEmpty) {
        throw Exception('Khong tai duoc MXL mau.');
      }

      final score = _parseMxl(Uint8List.fromList(bytes));

      if (!mounted) {
        return;
      }

      setState(() {
        _score = score;
        _isLoading = false;
      });

      _play();
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _play() {
    if (_isPlaying) {
      return;
    }

    _isPlaying = true;
    _stopwatch
      ..reset()
      ..start();
    _ticker.start();
    setState(() {});
  }

  void _pause() {
    if (!_isPlaying) {
      return;
    }

    _baseElapsedMs += _stopwatch.elapsedMilliseconds;
    _stopwatch
      ..stop()
      ..reset();
    _isPlaying = false;
    _ticker.stop();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final score = _score;

    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _ErrorView(error: _error!, onRetry: _loadMxl)
          : CustomPaint(
              painter: _StaffScrollerPainter(
                score: score!,
                currentMs: _currentMs,
                passedNoteIndexes: Set<int>.from(_passedNoteIndexes),
                missedNoteIndexes: Set<int>.from(_missedNoteIndexes),
              ),
              child: const SizedBox.expand(),
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

  static const double _pxPerMs = 0.10;
  static const int _previewWindowMs = 9000;
  static const int _cleanupWindowMs = 2500;

  @override
  void paint(Canvas canvas, Size size) {
    final playheadX = size.width * 0.72;
    final topPadding = 32.0;
    final staffHeight = (size.height - 170 - topPadding - 16) / 2;

    final trebleTop = topPadding;
    final bassTop = trebleTop + staffHeight + 26;
    final lineSpacing = staffHeight / 4;

    _drawStaff(
      canvas,
      Rect.fromLTWH(18, trebleTop, size.width - 36, staffHeight),
      lineSpacing,
    );
    _drawStaff(
      canvas,
      Rect.fromLTWH(18, bassTop, size.width - 36, staffHeight),
      lineSpacing,
    );

    _drawClef(canvas, Offset(28, trebleTop + lineSpacing * 0.2), '𝄞', 72);
    _drawClef(canvas, Offset(30, bassTop + lineSpacing * 0.6), '𝄢', 54);

    final symbolPaint = Paint()
      ..color = const Color(0xFF0D3750)
      ..strokeWidth = 2.2;
    canvas.drawLine(
      Offset(playheadX, trebleTop),
      Offset(playheadX, bassTop + staffHeight),
      symbolPaint,
    );

    final visibleSymbols = score.symbols.where((s) {
      final delta = s.timeMs - currentMs;
      return delta <= _previewWindowMs && delta >= -_cleanupWindowMs;
    });

    for (final s in visibleSymbols) {
      final x = playheadX + (s.timeMs - currentMs) * _pxPerMs;
      if (x < 10 || x > size.width - 10) {
        continue;
      }
      _drawSymbolText(
        canvas,
        Offset(x + 4, trebleTop - 16),
        s.label,
        color: const Color(0xFF0B2F44),
        fontSize: 14,
      );
    }

    for (var i = 0; i < score.notes.length; i++) {
      final note = score.notes[i];
      final delta = note.hitTimeMs - currentMs;
      if (delta > _previewWindowMs || delta < -_cleanupWindowMs) {
        continue;
      }

      final x = playheadX + delta * _pxPerMs;
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

    _drawKeyboard(canvas, size, score, currentMs);
  }

  void _drawStaff(Canvas canvas, Rect rect, double spacing) {
    final boxPaint = Paint()..color = const Color(0xE6F4F4F4);
    final border = Paint()
      ..color = const Color(0xFF111111)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final linePaint = Paint()
      ..color = const Color(0xFF111111)
      ..strokeWidth = 1.1;

    canvas.drawRect(rect, boxPaint);
    canvas.drawRect(rect, border);

    for (var i = 0; i < 5; i++) {
      final y = rect.top + i * spacing;
      canvas.drawLine(Offset(rect.left, y), Offset(rect.right, y), linePaint);
    }
  }

  void _drawClef(Canvas canvas, Offset offset, String text, double fontSize) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: const Color(0xFF111111),
          fontSize: fontSize,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, offset);
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

  void _drawKeyboard(Canvas canvas, Size size, ScoreData score, int currentMs) {
    final keyboardTop = size.height - 92;
    final startMidi = score.minMidi - 2;
    final endMidi = score.maxMidi + 2;

    final midiRange = <int>[
      for (var midi = startMidi; midi <= endMidi; midi++) midi,
    ];
    final whiteMidis = midiRange.where((m) => !_isBlack(m)).toList();

    final whiteWidth = size.width / math.max(whiteMidis.length, 1);
    final blackWidth = whiteWidth * 0.62;
    final blackHeight = 54.0;

    final active = <int>{};
    for (final note in score.notes) {
      if ((note.hitTimeMs - currentMs).abs() <= 100) {
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
        Rect.fromLTWH(x, keyboardTop, whiteWidth - 1, 92),
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

  @override
  bool shouldRepaint(covariant _StaffScrollerPainter oldDelegate) {
    return oldDelegate.currentMs != currentMs ||
        oldDelegate.score != score ||
        oldDelegate.passedNoteIndexes != passedNoteIndexes ||
        oldDelegate.missedNoteIndexes != missedNoteIndexes;
  }
}

enum _NoteJudge { pending, pass, miss }

class ScoreData {
  const ScoreData({
    required this.bpm,
    required this.beatsPerMeasure,
    required this.beatUnit,
    required this.notes,
    required this.symbols,
    required this.minMidi,
    required this.maxMidi,
  });

  final double bpm;
  final int beatsPerMeasure;
  final int beatUnit;
  final List<MusicNote> notes;
  final List<MusicSymbol> symbols;
  final int minMidi;
  final int maxMidi;
}

class MusicNote {
  const MusicNote({
    required this.midi,
    required this.hitTimeMs,
    required this.holdMs,
    this.accidental,
  });

  final int midi;
  final int hitTimeMs;
  final int holdMs;
  final String? accidental;
}

class MusicSymbol {
  const MusicSymbol({required this.label, required this.timeMs});

  final String label;
  final int timeMs;
}

ScoreData _parseMxl(Uint8List bytes) {
  final archive = ZipDecoder().decodeBytes(bytes, verify: true);

  String? scoreXml;
  final containerEntry = archive.findFile('META-INF/container.xml');
  if (containerEntry != null) {
    final containerText = utf8.decode(containerEntry.content as List<int>);
    final containerDoc = XmlDocument.parse(containerText);
    final rootPath = containerDoc
        .findAllElements('rootfile')
        .firstOrNull
        ?.getAttribute('full-path');

    if (rootPath != null) {
      final scoreEntry = archive.findFile(rootPath);
      if (scoreEntry != null) {
        scoreXml = utf8.decode(scoreEntry.content as List<int>);
      }
    }
  }

  scoreXml ??= utf8.decode(
    archive.files
            .where((f) => f.isFile)
            .firstWhere(
              (f) =>
                  f.name.endsWith('.musicxml') ||
                  (f.name.endsWith('.xml') &&
                      !f.name.endsWith('container.xml')),
            )
            .content
        as List<int>,
  );

  final doc = XmlDocument.parse(scoreXml);
  final part = doc.findAllElements('part').first;

  var divisions = 1;
  var bpm = 100.0;
  var beats = 4;
  var beatType = 4;
  var currentDiv = 0.0;
  var lastOnset = 0.0;

  final notes = <MusicNote>[];
  final symbols = <MusicSymbol>[];

  for (final measure in part.findElements('measure')) {
    final measureStartMs = (currentDiv / divisions * 60000 / bpm).round();
    symbols.add(MusicSymbol(label: '|', timeMs: measureStartMs));

    final attrs = measure.getElement('attributes');
    if (attrs != null) {
      final divisionsText = attrs.getElement('divisions')?.innerText;
      if (divisionsText != null) {
        divisions = int.tryParse(divisionsText) ?? divisions;
      }

      final keyFifths = attrs
          .getElement('key')
          ?.getElement('fifths')
          ?.innerText;
      if (keyFifths != null) {
        symbols.add(
          MusicSymbol(label: 'Key $keyFifths', timeMs: measureStartMs),
        );
      }

      final beatsText = attrs
          .getElement('time')
          ?.getElement('beats')
          ?.innerText;
      final beatTypeText = attrs
          .getElement('time')
          ?.getElement('beat-type')
          ?.innerText;
      if (beatsText != null && beatTypeText != null) {
        beats = int.tryParse(beatsText) ?? beats;
        beatType = int.tryParse(beatTypeText) ?? beatType;
        symbols.add(
          MusicSymbol(label: '$beats/$beatType', timeMs: measureStartMs),
        );
      }

      final clefSign = attrs.getElement('clef')?.getElement('sign')?.innerText;
      if (clefSign != null) {
        symbols.add(
          MusicSymbol(label: 'Clef $clefSign', timeMs: measureStartMs),
        );
      }
    }

    for (final direction in measure.findElements('direction')) {
      final tempoText = direction
          .findAllElements('sound')
          .firstOrNull
          ?.getAttribute('tempo');
      if (tempoText != null) {
        bpm = double.tryParse(tempoText) ?? bpm;
        symbols.add(
          MusicSymbol(
            label: 'Tempo ${bpm.toStringAsFixed(0)}',
            timeMs: measureStartMs,
          ),
        );
      }

      final dynamics = direction.findAllElements('dynamics').firstOrNull;
      final firstDynamic = dynamics?.children
          .whereType<XmlElement>()
          .firstOrNull;
      if (firstDynamic != null) {
        symbols.add(
          MusicSymbol(
            label: firstDynamic.name.local.toUpperCase(),
            timeMs: measureStartMs,
          ),
        );
      }
    }

    for (final note in measure.findElements('note')) {
      final isChord = note.getElement('chord') != null;
      final isRest = note.getElement('rest') != null;
      final duration =
          int.tryParse(note.getElement('duration')?.innerText ?? '0') ?? 0;

      final onsetDiv = isChord ? lastOnset : currentDiv;
      final onsetMs = (onsetDiv / divisions * 60000 / bpm).round();
      final holdMs = ((duration / divisions) * 60000 / bpm).round();

      if (!isRest) {
        final pitch = note.getElement('pitch');
        final midi = _pitchToMidi(pitch);
        if (midi != null) {
          final accidental = _accidentalGlyph(
            pitch?.getElement('alter')?.innerText,
          );
          notes.add(
            MusicNote(
              midi: midi,
              hitTimeMs: onsetMs,
              holdMs: holdMs,
              accidental: accidental,
            ),
          );
        }
      } else {
        symbols.add(MusicSymbol(label: 'rest', timeMs: onsetMs));
      }

      if (!isChord) {
        lastOnset = onsetDiv;
        currentDiv += duration;
      }
    }
  }

  notes.sort((a, b) => a.hitTimeMs.compareTo(b.hitTimeMs));
  symbols.sort((a, b) => a.timeMs.compareTo(b.timeMs));

  final midiValues = notes.map((n) => n.midi).toList();
  final minMidi = midiValues.isEmpty ? 48 : midiValues.reduce(math.min);
  final maxMidi = midiValues.isEmpty ? 72 : midiValues.reduce(math.max);

  return ScoreData(
    bpm: bpm,
    beatsPerMeasure: beats,
    beatUnit: beatType,
    notes: notes,
    symbols: symbols,
    minMidi: minMidi,
    maxMidi: maxMidi,
  );
}

int? _pitchToMidi(XmlElement? pitch) {
  if (pitch == null) {
    return null;
  }

  final step = pitch.getElement('step')?.innerText;
  final octave = int.tryParse(pitch.getElement('octave')?.innerText ?? '');
  final alter = int.tryParse(pitch.getElement('alter')?.innerText ?? '0') ?? 0;
  if (step == null || octave == null) {
    return null;
  }

  final semitone = switch (step) {
    'C' => 0,
    'D' => 2,
    'E' => 4,
    'F' => 5,
    'G' => 7,
    'A' => 9,
    'B' => 11,
    _ => 0,
  };

  return (octave + 1) * 12 + semitone + alter;
}

String? _accidentalGlyph(String? alterText) {
  final alter = int.tryParse(alterText ?? '0') ?? 0;
  if (alter == 1) {
    return '♯';
  }
  if (alter == -1) {
    return '♭';
  }
  if (alter == 2) {
    return '𝄪';
  }
  if (alter == -2) {
    return '𝄫';
  }
  return null;
}

extension _FirstOrNullExt<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
