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

void logParsedMxlTrace(
  ScoreData score, {
  int startMeasure = 11,
  int endMeasure = 20,
}) {
  for (var measure = startMeasure; measure <= endMeasure; measure++) {
    final measureNotes = score.notes
        .where((note) => note.measureIndex + 1 == measure)
        .toList();
    if (measureNotes.isEmpty) {
      continue;
    }

    for (final note in measureNotes) {
      _durationLabelFromBeats(
        note.notatedBeats ?? (note.holdMs / (60000.0 / score.bpm)),
      );
    }
  }
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
    this.dotCount = 0,
    this.isStaccato = false,
    this.fingering,
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
  final int dotCount;
  final bool isStaccato;
  final String? fingering;
}

class MusicSymbol {
  const MusicSymbol({required this.label, required this.timeMs});

  final String label;
  final int timeMs;
}

enum SlurEventType { start, stop, continuation }

class SlurEvent {
  const SlurEvent({
    required this.partId,
    required this.number,
    required this.eventType,
    required this.noteIndex,
    required this.timeMs,
    required this.measureIndex,
    required this.voice,
    required this.staffNumber,
    required this.staffStep,
    required this.isChord,
    this.placement,
    this.orientation,
    this.defaultX,
    this.defaultY,
    this.relativeX,
    this.relativeY,
    this.bezierX,
    this.bezierY,
    this.bezierX2,
    this.bezierY2,
    this.lineType,
    this.dashLength,
    this.spaceLength,
  });

  final String partId;
  final int number;
  final SlurEventType eventType;
  final int noteIndex;
  final int timeMs;
  final int measureIndex;
  final int voice;
  final int? staffNumber;
  final int staffStep;
  final bool isChord;
  final String? placement;
  final String? orientation;
  final double? defaultX;
  final double? defaultY;
  final double? relativeX;
  final double? relativeY;
  final double? bezierX;
  final double? bezierY;
  final double? bezierX2;
  final double? bezierY2;
  final String? lineType;
  final double? dashLength;
  final double? spaceLength;
}

class SlurSegment {
  const SlurSegment({
    required this.startEventIndex,
    required this.endEventIndex,
    required this.startNoteIndex,
    required this.endNoteIndex,
    required this.isCrossSystemContinuation,
  });

  final int startEventIndex;
  final int endEventIndex;
  final int startNoteIndex;
  final int endNoteIndex;
  final bool isCrossSystemContinuation;
}

class SlurSpan {
  const SlurSpan({
    required this.partId,
    required this.number,
    required this.voice,
    required this.staffNumber,
    required this.events,
    required this.segments,
  });

  final String partId;
  final int number;
  final int voice;
  final int? staffNumber;
  final List<SlurEvent> events;
  final List<SlurSegment> segments;
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
    required this.slurs,
    required this.beams,
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
  final List<MxlSlurNode> slurs;
  final List<MxlBeamNode> beams;
  final MxlElementNode raw;
}

class MxlSlurNode {
  const MxlSlurNode({
    required this.type,
    required this.number,
    this.placement,
    this.orientation,
    this.defaultX,
    this.defaultY,
    this.relativeX,
    this.relativeY,
    this.bezierX,
    this.bezierY,
    this.bezierX2,
    this.bezierY2,
    this.lineType,
    this.dashLength,
    this.spaceLength,
  });

  final String type;
  final int number;
  final String? placement;
  final String? orientation;
  final double? defaultX;
  final double? defaultY;
  final double? relativeX;
  final double? relativeY;
  final double? bezierX;
  final double? bezierY;
  final double? bezierX2;
  final double? bezierY2;
  final String? lineType;
  final double? dashLength;
  final double? spaceLength;
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
        final slurs = _extractSlurs(noteElement);
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
            slurs: slurs,
            beams: beams,
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
    return;
  }

  final safePartIndex = partIndex.clamp(0, document.parts.length - 1);
  final part = document.parts[safePartIndex];
  final measure = part.measures
      .where((m) => m.number == measureNumber)
      .firstOrNull;

  if (measure == null) {
    return;
  }

  for (var i = 0; i < measure.notes.length; i++) {
    final note = measure.notes[i];
    note.beams.map((beam) => '${beam.number ?? 1}:${beam.value}').join(',');
  }
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

List<MxlSlurNode> _extractSlurs(XmlElement noteElement) {
  final slurs = noteElement
      .findElements('notations')
      .expand((notations) => notations.findElements('slur'))
      .map(
        (slur) => MxlSlurNode(
          type: (slur.getAttribute('type') ?? '').trim().toLowerCase(),
          number: int.tryParse(slur.getAttribute('number') ?? '') ?? 1,
          placement: slur.getAttribute('placement')?.trim().toLowerCase(),
          orientation: slur.getAttribute('orientation')?.trim().toLowerCase(),
          defaultX: double.tryParse(slur.getAttribute('default-x') ?? ''),
          defaultY: double.tryParse(slur.getAttribute('default-y') ?? ''),
          relativeX: double.tryParse(slur.getAttribute('relative-x') ?? ''),
          relativeY: double.tryParse(slur.getAttribute('relative-y') ?? ''),
          bezierX: double.tryParse(slur.getAttribute('bezier-x') ?? ''),
          bezierY: double.tryParse(slur.getAttribute('bezier-y') ?? ''),
          bezierX2: double.tryParse(slur.getAttribute('bezier-x2') ?? ''),
          bezierY2: double.tryParse(slur.getAttribute('bezier-y2') ?? ''),
          lineType: slur.getAttribute('line-type')?.trim().toLowerCase(),
          dashLength: double.tryParse(slur.getAttribute('dash-length') ?? ''),
          spaceLength: double.tryParse(slur.getAttribute('space-length') ?? ''),
        ),
      )
      .where((slur) => slur.type.isNotEmpty)
      .toList();

  slurs.sort((a, b) {
    final typeComparison = _slurTypePriority(
      a.type,
    ).compareTo(_slurTypePriority(b.type));
    if (typeComparison != 0) {
      return typeComparison;
    }
    return a.number.compareTo(b.number);
  });
  return slurs;
}

int _slurTypePriority(String type) {
  return switch (type) {
    'stop' => 0,
    'continue' => 1,
    'start' => 2,
    _ => 3,
  };
}
