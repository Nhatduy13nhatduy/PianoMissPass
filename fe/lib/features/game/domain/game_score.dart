import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

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

ScoreData parseMxl(Uint8List bytes) {
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
            .where((file) => file.isFile)
            .firstWhere(
              (file) =>
                  file.name.endsWith('.musicxml') ||
                  (file.name.endsWith('.xml') &&
                      !file.name.endsWith('container.xml')),
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
        final midi = pitchToMidi(pitch);
        if (midi != null) {
          final accidental = accidentalGlyph(
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

  final midiValues = notes.map((note) => note.midi).toList();
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

int? pitchToMidi(XmlElement? pitch) {
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

String? accidentalGlyph(String? alterText) {
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

extension FirstOrNullExt<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
