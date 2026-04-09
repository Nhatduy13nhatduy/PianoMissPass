import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

part 'score_builder.dart';

class ScoreData {
  const ScoreData({
    required this.bpm,
    required this.beatsPerMeasure,
    required this.beatUnit,
    required this.notes,
    required this.slurs,
    required this.symbols,
    required this.keySignatures,
    required this.minMidi,
    required this.maxMidi,
  });

  final double bpm;
  final int beatsPerMeasure;
  final int beatUnit;
  final List<MusicNote> notes;
  final List<SlurSpan> slurs;
  final List<MusicSymbol> symbols;
  final List<KeySignatureChange> keySignatures;
  final int minMidi;
  final int maxMidi;
}

class SlurSpan {
  const SlurSpan({required this.startNoteIndex, required this.endNoteIndex});

  final int startNoteIndex;
  final int endNoteIndex;
}

void logParsedMxlTrace(
  ScoreData score, {
  int startMeasure = 11,
  int endMeasure = 20,
}) {
  print('=== MXL PARSE TRACE ===');
  print(
    'bpm=${score.bpm}, time=${score.beatsPerMeasure}/${score.beatUnit}, notes=${score.notes.length}, keyChanges=${score.keySignatures.length}',
  );

  for (var measure = startMeasure; measure <= endMeasure; measure++) {
    final measureNotes = score.notes
        .where((note) => note.measureIndex + 1 == measure)
        .toList();
    if (measureNotes.isEmpty) {
      print('--- measure $measure: no notes ---');
      continue;
    }

    print('--- measure $measure: ${measureNotes.length} notes ---');
    for (final note in measureNotes) {
      final durationLabel = _durationLabelFromBeats(
        note.notatedBeats ?? (note.holdMs / (60000.0 / score.bpm)),
      );
      print(
        'm=$measure voice=${note.voice} staff=${note.staffNumber ?? (note.isTrebleFromMxl == true
                ? 1
                : note.isTrebleFromMxl == false
                ? 2
                : -1)} '
        'hit=${note.hitTimeMs} hold=${note.holdMs} beats=${note.notatedBeats?.toStringAsFixed(3) ?? 'null'} '
        'type=$durationLabel midi=${note.midi} step=${note.staffStep} accidental=${note.accidental ?? '-'}',
      );
    }
  }

  print('=== END MXL PARSE TRACE ===');
}

String _durationLabelFromBeats(double beats) {
  const entries = <(double, String)>[
    (4.0, 'whole'),
    (2.0, 'half'),
    (1.0, 'quarter'),
    (0.5, 'eighth'),
    (0.25, '16th'),
  ];

  var best = entries.first;
  var bestDelta = (beats - best.$1).abs();
  for (final entry in entries.skip(1)) {
    final delta = (beats - entry.$1).abs();
    if (delta < bestDelta) {
      best = entry;
      bestDelta = delta;
    }
  }
  return best.$2;
}

class KeySignatureChange {
  const KeySignatureChange({required this.timeMs, required this.fifths});

  final int timeMs;
  final int fifths;
}

class MusicNote {
  const MusicNote({
    required this.midi,
    required this.staffStep,
    required this.hitTimeMs,
    required this.holdMs,
    required this.voice,
    this.accidental,
    this.isTrebleFromMxl,
    this.staffNumber,
    required this.measureIndex,
    this.notatedBeats,
    this.primaryBeam,
    this.secondaryBeam,
    this.tertiaryBeam,
    this.stemFromMxl,
    this.slurStarts = const <int>[],
    this.slurStops = const <int>[],
    this.dotCount = 0,
  });

  final int midi;
  final int staffStep;
  final int hitTimeMs;
  final int holdMs;
  final int voice;
  final String? accidental;
  final bool? isTrebleFromMxl;
  final int? staffNumber;
  final int measureIndex;
  final double? notatedBeats;
  final String? primaryBeam;
  final String? secondaryBeam;
  final String? tertiaryBeam;
  final String? stemFromMxl;
  final List<int> slurStarts;
  final List<int> slurStops;
  final int dotCount;
}

class MusicSymbol {
  const MusicSymbol({required this.label, required this.timeMs});

  final String label;
  final int timeMs;
}

class MxlDocumentData {
  const MxlDocumentData({
    required this.scorePath,
    required this.scoreXml,
    required this.root,
    required this.parts,
    required this.archiveEntries,
  });

  final String scorePath;
  final String scoreXml;
  final MxlElementNode root;
  final List<MxlPartNode> parts;
  final List<MxlArchiveEntry> archiveEntries;
}

class MxlArchiveEntry {
  const MxlArchiveEntry({
    required this.name,
    required this.isFile,
    required this.sizeBytes,
  });

  final String name;
  final bool isFile;
  final int sizeBytes;
}

class MxlElementNode {
  const MxlElementNode({
    required this.name,
    required this.attributes,
    required this.text,
    required this.innerText,
    required this.children,
    required this.rawXml,
  });

  final String name;
  final Map<String, String> attributes;
  final String? text;
  final String? innerText;
  final List<MxlElementNode> children;
  final String rawXml;
}

class MxlPartNode {
  const MxlPartNode({
    required this.id,
    required this.measures,
    required this.raw,
  });

  final String? id;
  final List<MxlMeasureNode> measures;
  final MxlElementNode raw;
}

class MxlMeasureNode {
  const MxlMeasureNode({
    required this.number,
    required this.width,
    required this.notes,
    required this.elements,
    required this.raw,
  });

  final int? number;
  final double? width;
  final List<MxlNoteNode> notes;
  final List<MxlElementNode> elements;
  final MxlElementNode raw;
}

class MxlNoteNode {
  const MxlNoteNode({
    required this.isChord,
    required this.isRest,
    required this.durationDivisions,
    required this.voice,
    required this.staff,
    required this.type,
    required this.step,
    required this.octave,
    required this.alter,
    required this.stem,
    required this.accidental,
    required this.beams,
    required this.slurStarts,
    required this.slurStops,
    required this.raw,
  });

  final bool isChord;
  final bool isRest;
  final int? durationDivisions;
  final int? voice;
  final int? staff;
  final String? type;
  final String? step;
  final int? octave;
  final int? alter;
  final String? stem;
  final String? accidental;
  final List<MxlBeamNode> beams;
  final List<int> slurStarts;
  final List<int> slurStops;
  final MxlElementNode raw;
}

class MxlBeamNode {
  const MxlBeamNode({required this.number, required this.value});

  final int? number;
  final String value;
}

MxlDocumentData parseMxlDocument(Uint8List bytes) {
  final source = _decodeMxlSource(bytes);
  final doc = XmlDocument.parse(source.scoreXml);
  final root = _mapXmlElement(doc.rootElement);

  final parts = <MxlPartNode>[];
  for (final partElement in doc.findAllElements('part')) {
    final measures = <MxlMeasureNode>[];
    for (final measureElement in partElement.findElements('measure')) {
      final noteNodes = <MxlNoteNode>[];
      for (final noteElement in measureElement.findElements('note')) {
        final beams = noteElement
            .findElements('beam')
            .map(
              (beam) => MxlBeamNode(
                number: int.tryParse(beam.getAttribute('number') ?? ''),
                value: beam.innerText.trim().toLowerCase(),
              ),
            )
            .toList();

        final pitch = noteElement.getElement('pitch');
        final slurStarts = <int>[];
        final slurStops = <int>[];
        for (final slur in noteElement.findAllElements('slur')) {
          final type = slur.getAttribute('type')?.trim().toLowerCase();
          final number = int.tryParse(slur.getAttribute('number') ?? '') ?? 1;
          if (type == 'start') {
            slurStarts.add(number);
          } else if (type == 'stop') {
            slurStops.add(number);
          }
        }
        noteNodes.add(
          MxlNoteNode(
            isChord: noteElement.getElement('chord') != null,
            isRest: noteElement.getElement('rest') != null,
            durationDivisions: int.tryParse(
              noteElement.getElement('duration')?.innerText.trim() ?? '',
            ),
            voice: int.tryParse(
              noteElement.getElement('voice')?.innerText.trim() ?? '',
            ),
            staff: int.tryParse(
              noteElement.getElement('staff')?.innerText.trim() ?? '',
            ),
            type: noteElement.getElement('type')?.innerText.trim(),
            step: pitch?.getElement('step')?.innerText.trim(),
            octave: int.tryParse(
              pitch?.getElement('octave')?.innerText.trim() ?? '',
            ),
            alter: int.tryParse(
              pitch?.getElement('alter')?.innerText.trim() ?? '',
            ),
            stem: noteElement
                .getElement('stem')
                ?.innerText
                .trim()
                .toLowerCase(),
            accidental: noteElement
                .getElement('accidental')
                ?.innerText
                .trim()
                .toLowerCase(),
            beams: beams,
            slurStarts: slurStarts,
            slurStops: slurStops,
            raw: _mapXmlElement(noteElement),
          ),
        );
      }

      final elements = measureElement.children
          .whereType<XmlElement>()
          .map(_mapXmlElement)
          .toList();

      measures.add(
        MxlMeasureNode(
          number: int.tryParse(measureElement.getAttribute('number') ?? ''),
          width: double.tryParse(measureElement.getAttribute('width') ?? ''),
          notes: noteNodes,
          elements: elements,
          raw: _mapXmlElement(measureElement),
        ),
      );
    }

    parts.add(
      MxlPartNode(
        id: partElement.getAttribute('id'),
        measures: measures,
        raw: _mapXmlElement(partElement),
      ),
    );
  }

  return MxlDocumentData(
    scorePath: source.scorePath,
    scoreXml: source.scoreXml,
    root: root,
    parts: parts,
    archiveEntries: source.archiveEntries,
  );
}

void logMxlMeasureNode(
  MxlDocumentData document, {
  int measureNumber = 11,
  int partIndex = 0,
}) {
  if (document.parts.isEmpty) {
    print('=== MXL MEASURE TRACE ===');
    print('No parts found in document');
    print('=== END MXL MEASURE TRACE ===');
    return;
  }

  final safePartIndex = partIndex.clamp(0, document.parts.length - 1);
  final part = document.parts[safePartIndex];
  final measure = part.measures
      .where((m) => m.number == measureNumber)
      .firstOrNull;

  print('=== MXL MEASURE TRACE ===');
  print(
    'scorePath=${document.scorePath} partIndex=$safePartIndex partId=${part.id ?? '-'} targetMeasure=$measureNumber',
  );

  if (measure == null) {
    print(
      'Measure $measureNumber not found. Total measures=${part.measures.length}',
    );
    print('=== END MXL MEASURE TRACE ===');
    return;
  }

  print(
    'measure number=${measure.number ?? -1} width=${measure.width?.toStringAsFixed(2) ?? '-'} elements=${measure.elements.length} notes=${measure.notes.length}',
  );

  for (var i = 0; i < measure.notes.length; i++) {
    final note = measure.notes[i];
    final beams = note.beams
        .map((beam) => '${beam.number ?? 1}:${beam.value}')
        .join(',');
    print(
      'note[$i] chord=${note.isChord} rest=${note.isRest} dur=${note.durationDivisions ?? -1} '
      'voice=${note.voice ?? -1} staff=${note.staff ?? -1} '
      'pitch=${note.step ?? '-'}${note.alter == null || note.alter == 0 ? '' : note.alter} ${note.octave ?? -1} '
      'type=${note.type ?? '-'} stem=${note.stem ?? '-'} acc=${note.accidental ?? '-'} '
      'beams=[${beams.isEmpty ? '-' : beams}]',
    );
  }

  print('=== END MXL MEASURE TRACE ===');
}

ScoreData parseMxl(Uint8List bytes) {
  final document = parseMxlDocument(bytes);
  return buildScoreDataFromMxlDocument(document);
}

int? staffStepFromPitch(String? step, int? octave) {
  if (step == null || octave == null) {
    return null;
  }

  final letterIndex = switch (step) {
    'C' => 0,
    'D' => 1,
    'E' => 2,
    'F' => 3,
    'G' => 4,
    'A' => 5,
    'B' => 6,
    _ => -1,
  };
  if (letterIndex < 0) {
    return null;
  }

  return octave * 7 + letterIndex;
}

int? pitchToMidi(XmlElement? pitch) {
  if (pitch == null) {
    return null;
  }

  final step = pitch.getElement('step')?.innerText;
  final octave = int.tryParse(pitch.getElement('octave')?.innerText ?? '');
  final alter = int.tryParse(pitch.getElement('alter')?.innerText ?? '0') ?? 0;
  return pitchToMidiFromPitch(step: step, octave: octave, alter: alter);
}

int? pitchToMidiFromPitch({
  required String? step,
  required int? octave,
  required int alter,
}) {
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

String? accidentalGlyph(String? alterText, String? accidentalText) {
  final accidental = accidentalText?.trim().toLowerCase();
  if (accidental != null && accidental.isNotEmpty) {
    if (accidental == 'natural') {
      return '♮';
    }
    if (accidental == 'sharp' || accidental == 'sharp-up') {
      return '♯';
    }
    if (accidental == 'flat' || accidental == 'flat-down') {
      return '♭';
    }
    if (accidental == 'double-sharp') {
      return '𝄪';
    }
    if (accidental == 'flat-flat' || accidental == 'double-flat') {
      return '𝄫';
    }
  }

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

class _DecodedMxlSource {
  const _DecodedMxlSource({
    required this.scorePath,
    required this.scoreXml,
    required this.archiveEntries,
  });

  final String scorePath;
  final String scoreXml;
  final List<MxlArchiveEntry> archiveEntries;
}

_DecodedMxlSource _decodeMxlSource(Uint8List bytes) {
  final archive = ZipDecoder().decodeBytes(bytes, verify: true);
  final archiveEntries = archive.files
      .map(
        (file) => MxlArchiveEntry(
          name: file.name,
          isFile: file.isFile,
          sizeBytes: file.size,
        ),
      )
      .toList();

  String? scorePath;
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
        scorePath = rootPath;
        scoreXml = utf8.decode(scoreEntry.content as List<int>);
      }
    }
  }

  if (scoreXml == null) {
    final fallback = archive.files
        .where((file) => file.isFile)
        .firstWhere(
          (file) =>
              file.name.endsWith('.musicxml') ||
              (file.name.endsWith('.xml') &&
                  !file.name.endsWith('container.xml')),
        );
    scorePath = fallback.name;
    scoreXml = utf8.decode(fallback.content as List<int>);
  }

  return _DecodedMxlSource(
    scorePath: scorePath ?? '',
    scoreXml: scoreXml,
    archiveEntries: archiveEntries,
  );
}

MxlElementNode _mapXmlElement(XmlElement element) {
  final attributes = <String, String>{
    for (final attr in element.attributes) attr.name.toString(): attr.value,
  };
  final directText = element.children
      .whereType<XmlText>()
      .map((node) => node.text)
      .join()
      .trim();
  final innerText = element.innerText.trim();

  return MxlElementNode(
    name: element.name.toString(),
    attributes: attributes,
    text: directText.isEmpty ? null : directText,
    innerText: innerText.isEmpty ? null : innerText,
    children: element.children
        .whereType<XmlElement>()
        .map(_mapXmlElement)
        .toList(),
    rawXml: element.toXmlString(pretty: false),
  );
}
