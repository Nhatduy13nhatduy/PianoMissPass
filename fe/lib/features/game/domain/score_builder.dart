part of 'game_score.dart';

// Duration-based spacing in quarter units.
// MusicXML durations are in divisions, where `measureDivisions` is divisions per
// quarter note. We convert duration to quarter-count first, then multiply by the
// fixed timeline factor below.
const bool _useDurationBasedTimeline = true;
const double _timelineMsPerDurationDivision = 800;

ScoreData buildScoreDataFromMxlDocument(MxlDocumentData document) {
  if (document.parts.isEmpty) {
    return const ScoreData(
      bpm: 100,
      beatsPerMeasure: 4,
      beatUnit: 4,
      notes: <MusicNote>[],
      slurs: <SlurSpan>[],
      symbols: <MusicSymbol>[],
      keySignatures: <KeySignatureChange>[],
      minMidi: 48,
      maxMidi: 72,
    );
  }

  final part = document.parts.first;

  var divisions = 1;
  var bpm = 100.0;
  var beats = 4;
  var beatType = 4;
  final staffClefIsTreble = <int, bool>{1: true, 2: false};

  final notes = <MusicNote>[];
  final symbols = <MusicSymbol>[];
  final keySignatures = <KeySignatureChange>[];
  final globalStaffByVoice = <int, int>{};
  int? globalLastExplicitStaff;
  var elapsedMs = 0;

  for (
    var measureIndex = 0;
    measureIndex < part.measures.length;
    measureIndex++
  ) {
    final measure = part.measures[measureIndex];

    // Update divisions from attributes first, so measure has correct divisions
    final attrs = _firstChildByName(measure.elements, 'attributes');
    if (attrs != null) {
      final divisionsText = _firstChildByName(
        attrs.children,
        'divisions',
      )?.innerText;
      if (divisionsText != null) {
        divisions = int.tryParse(divisionsText.trim()) ?? divisions;
      }
    }

    final measureDivisions = divisions;
    final measureBpm = bpm;
    final measureStartMs = elapsedMs;
    symbols.add(MusicSymbol(label: '|', timeMs: measureStartMs));

    if (attrs != null) {
      final keyFifths = _firstChildByName(
        _firstChildByName(attrs.children, 'key')?.children,
        'fifths',
      )?.innerText;
      if (keyFifths != null) {
        final fifths = int.tryParse(keyFifths);
        if (fifths != null) {
          keySignatures.add(
            KeySignatureChange(timeMs: measureStartMs, fifths: fifths),
          );
        }
        symbols.add(
          MusicSymbol(label: 'Key $keyFifths', timeMs: measureStartMs),
        );
      }

      final time = _firstChildByName(attrs.children, 'time');
      final beatsText = _firstChildByName(time?.children, 'beats')?.innerText;
      final beatTypeText = _firstChildByName(
        time?.children,
        'beat-type',
      )?.innerText;
      if (beatsText != null && beatTypeText != null) {
        beats = int.tryParse(beatsText.trim()) ?? beats;
        beatType = int.tryParse(beatTypeText.trim()) ?? beatType;
        symbols.add(
          MusicSymbol(label: '$beats/$beatType', timeMs: measureStartMs),
        );
      }
    }

    for (final direction in _childrenByName(measure.elements, 'direction')) {
      final tempoText = _firstDescendantByName(
        direction,
        'sound',
      )?.attributes['tempo'];
      if (tempoText != null) {
        bpm = double.tryParse(tempoText) ?? bpm;
        symbols.add(
          MusicSymbol(
            label: 'Tempo ${bpm.toStringAsFixed(0)}',
            timeMs: measureStartMs,
          ),
        );
      }

      final dynamics = _firstDescendantByName(direction, 'dynamics');
      final firstDynamic = dynamics?.children.firstOrNull;
      if (firstDynamic != null) {
        symbols.add(
          MusicSymbol(
            label: _localName(firstDynamic.name).toUpperCase(),
            timeMs: measureStartMs,
          ),
        );
      }
    }

    var measureCursorDiv = 0.0;
    var measureLastOnsetDiv = 0.0;
    var measureMaxDiv = 0.0;
    final expectedMeasureDivCurrent = divisions * beats * (4.0 / beatType);
    final staffByVoice = <int, int>{...globalStaffByVoice};
    int? lastExplicitStaff = globalLastExplicitStaff;

    var noteCursor = 0;
    final isMeasureAllRest =
        measure.notes.isNotEmpty && measure.notes.every((n) => n.isRest);
    final emittedWholeRestStaffs = <int>{};
    for (final element in measure.elements) {
      if (_nameEquals(element.name, 'attributes')) {
        final attributesTimeMs =
            measureStartMs +
            _divisionsToTimelineMs(
              measureCursorDiv,
              measureDivisions: measureDivisions,
              measureBpm: measureBpm,
            );
        _applyClefChangesFromAttributes(
          attributesNode: element,
          eventTimeMs: attributesTimeMs,
          staffClefIsTreble: staffClefIsTreble,
          symbols: symbols,
        );
        continue;
      }

      if (_nameEquals(element.name, 'backup')) {
        final duration =
            int.tryParse(
              _firstChildByName(
                    element.children,
                    'duration',
                  )?.innerText?.trim() ??
                  '0',
            ) ??
            0;
        measureCursorDiv = math.max(0.0, measureCursorDiv - duration);
        continue;
      }

      if (_nameEquals(element.name, 'forward')) {
        final duration =
            int.tryParse(
              _firstChildByName(
                    element.children,
                    'duration',
                  )?.innerText?.trim() ??
                  '0',
            ) ??
            0;
        measureCursorDiv += duration;
        if (measureCursorDiv > measureMaxDiv) {
          measureMaxDiv = measureCursorDiv;
        }
        continue;
      }

      if (!_nameEquals(element.name, 'note')) {
        continue;
      }

      if (noteCursor >= measure.notes.length) {
        continue;
      }
      final note = measure.notes[noteCursor++];
      final isGrace = note.raw.children.any(
        (child) => _localName(child.name).toLowerCase() == 'grace',
      );
      if (isGrace) {
        continue;
      }
      final isChord = note.isChord;
      final isRest = note.isRest;
      final duration = note.durationDivisions ?? 0;
      final voice = note.voice ?? 1;
      final notatedBeats = _notatedBeatsFromNoteNode(note);
      final primaryBeam = _primaryBeamFromNoteNode(note);
      final secondaryBeam = _secondaryBeamFromNoteNode(note);
      final tertiaryBeam = _tertiaryBeamFromNoteNode(note);
      final stemFromMxl = note.stem;

      final onsetInMeasureDiv = isChord
          ? measureLastOnsetDiv
          : measureCursorDiv;
      final onsetMs =
          measureStartMs +
          _divisionsToTimelineMs(
            onsetInMeasureDiv,
            measureDivisions: measureDivisions,
            measureBpm: measureBpm,
          );
      final holdMs = _divisionsToTimelineMs(
        duration.toDouble(),
        measureDivisions: measureDivisions,
        measureBpm: measureBpm,
      );
      final explicitStaff = note.staff;
      final staffNumber =
          explicitStaff ??
          staffByVoice[voice] ??
          globalStaffByVoice[voice] ??
          lastExplicitStaff ??
          globalLastExplicitStaff;
      if (explicitStaff != null) {
        staffByVoice[voice] = explicitStaff;
        lastExplicitStaff = explicitStaff;
        globalStaffByVoice[voice] = explicitStaff;
        globalLastExplicitStaff = explicitStaff;
      }

      if (!isRest) {
        final midi = pitchToMidiFromPitch(
          step: note.step,
          octave: note.octave,
          alter: note.alter ?? 0,
        );
        final step = note.step;
        final octave = note.octave;
        final isTrebleFromMxl = staffNumber == null
            ? null
            : (staffClefIsTreble[staffNumber] ?? (staffNumber == 1));
        final staffStep = staffStepFromPitch(step, octave);
        if (midi != null && staffStep != null) {
          final accidental = accidentalGlyph(
            note.alter?.toString(),
            note.accidental,
          );
          final dotCount = note.raw.children
              .where((child) => _nameEquals(child.name, 'dot'))
              .length;
          final isStaccato =
              _firstDescendantByName(note.raw, 'staccato') != null;
          notes.add(
            MusicNote(
              midi: midi,
              staffStep: staffStep,
              hitTimeMs: onsetMs,
              holdMs: holdMs,
              voice: voice,
              accidental: accidental,
              isTrebleFromMxl: isTrebleFromMxl,
              staffNumber: staffNumber,
              measureIndex: measureIndex,
              notatedBeats: notatedBeats,
              primaryBeam: primaryBeam,
              secondaryBeam: secondaryBeam,
              tertiaryBeam: tertiaryBeam,
              stemFromMxl: stemFromMxl,
              slurStarts: note.slurStarts,
              slurStops: note.slurStops,
              dotCount: dotCount,
              isStaccato: isStaccato,
            ),
          );
        }
      } else {
        final restStaff = staffNumber ?? 1;
        if (isMeasureAllRest && !emittedWholeRestStaffs.add(restStaff)) {
          continue;
        }

        final restType = isMeasureAllRest
            ? 'whole'
            : _restTypeFromNoteNode(
                note,
                expectedMeasureDiv: expectedMeasureDivCurrent,
              );
        final restTimeMs = isMeasureAllRest ? measureStartMs : onsetMs;
        symbols.add(
          MusicSymbol(label: 'Rest:$restStaff:$restType', timeMs: restTimeMs),
        );
      }

      if (!isChord) {
        measureLastOnsetDiv = onsetInMeasureDiv;
        measureCursorDiv += duration;
        if (measureCursorDiv > measureMaxDiv) {
          measureMaxDiv = measureCursorDiv;
        }
      }
    }

    final expectedMeasureDiv = divisions * beats * (4.0 / beatType);
    final shouldPadToExpectedMeasureLength =
        measureIndex > 0 || measureMaxDiv >= expectedMeasureDiv;
    if (shouldPadToExpectedMeasureLength &&
        measureMaxDiv < expectedMeasureDiv) {
      measureMaxDiv = expectedMeasureDiv;
    }
    elapsedMs =
        measureStartMs +
        _divisionsToTimelineMs(
          measureMaxDiv,
          measureDivisions: measureDivisions,
          measureBpm: measureBpm,
        );
  }

  notes.sort((a, b) => a.hitTimeMs.compareTo(b.hitTimeMs));
  final slurs = _buildSlurSpans(notes);
  symbols.sort((a, b) => a.timeMs.compareTo(b.timeMs));

  final midiValues = notes.map((note) => note.midi).toList();
  final minMidi = midiValues.isEmpty ? 48 : midiValues.reduce(math.min);
  final maxMidi = midiValues.isEmpty ? 72 : midiValues.reduce(math.max);

  return ScoreData(
    bpm: bpm,
    beatsPerMeasure: beats,
    beatUnit: beatType,
    notes: notes,
    slurs: slurs,
    symbols: symbols,
    keySignatures: keySignatures,
    minMidi: minMidi,
    maxMidi: maxMidi,
  );
}

void _applyClefChangesFromAttributes({
  required MxlElementNode attributesNode,
  required int eventTimeMs,
  required Map<int, bool> staffClefIsTreble,
  required List<MusicSymbol> symbols,
}) {
  for (final clef in _childrenByName(attributesNode.children, 'clef')) {
    final number = int.tryParse(clef.attributes['number'] ?? '1') ?? 1;
    final previousIsTreble = staffClefIsTreble[number];
    final sign = _firstChildByName(
      clef.children,
      'sign',
    )?.innerText?.trim().toUpperCase();
    bool? nextIsTreble;
    if (sign == 'G') {
      nextIsTreble = true;
      staffClefIsTreble[number] = true;
    } else if (sign == 'F') {
      nextIsTreble = false;
      staffClefIsTreble[number] = false;
    }
    if (sign != null &&
        (sign == 'G' || sign == 'F') &&
        (previousIsTreble == null || previousIsTreble != nextIsTreble)) {
      symbols.add(
        MusicSymbol(label: 'Clef:$number:$sign', timeMs: eventTimeMs),
      );
    }
  }
}

int _divisionsToTimelineMs(
  double divisions, {
  required int measureDivisions,
  required double measureBpm,
}) {
  if (_useDurationBasedTimeline) {
    if (measureDivisions <= 0) {
      return 0;
    }
    final quarterCount = divisions / measureDivisions;
    return (quarterCount * _timelineMsPerDurationDivision).round();
  }

  if (measureDivisions <= 0 || measureBpm <= 0) {
    return 0;
  }

  return (divisions / measureDivisions * 60000 / measureBpm).round();
}

String _restTypeFromNoteNode(
  MxlNoteNode note, {
  required double expectedMeasureDiv,
}) {
  final restNode = _firstChildByName(note.raw.children, 'rest');
  final isMeasureRest =
      restNode?.attributes['measure']?.trim().toLowerCase() == 'yes';
  final durationDiv = (note.durationDivisions ?? 0).toDouble();
  if (isMeasureRest ||
      (expectedMeasureDiv > 0 && durationDiv >= expectedMeasureDiv)) {
    return 'whole';
  }

  final type = note.type?.trim().toLowerCase();
  return switch (type) {
    'whole' => 'whole',
    'half' => 'half',
    'quarter' => 'quarter',
    'eighth' => '8th',
    '16th' => '16th',
    '32nd' => '32th',
    _ => 'quarter',
  };
}

List<SlurSpan> _buildSlurSpans(List<MusicNote> notes) {
  final slurs = <SlurSpan>[];
  final open = <String, int>{};

  String keyFor(MusicNote note, int number) {
    return '${note.voice}:$number';
  }

  for (var i = 0; i < notes.length; i++) {
    final note = notes[i];

    for (final number in note.slurStops) {
      final key = keyFor(note, number);
      final startIndex = open.remove(key);
      if (startIndex != null && startIndex < i) {
        slurs.add(SlurSpan(startNoteIndex: startIndex, endNoteIndex: i));
      }
    }

    for (final number in note.slurStarts) {
      open[keyFor(note, number)] = i;
    }
  }

  return slurs;
}

String? _secondaryBeamFromNoteNode(MxlNoteNode note) {
  MxlBeamNode? secondary;
  for (final beam in note.beams) {
    if (beam.number == 2) {
      secondary = beam;
      break;
    }
  }

  if (secondary == null) {
    return null;
  }

  final value = secondary.value.trim().toLowerCase();
  if (value == 'begin' ||
      value == 'continue' ||
      value == 'end' ||
      value == 'forward hook' ||
      value == 'backward hook') {
    return value;
  }

  return null;
}

String? _tertiaryBeamFromNoteNode(MxlNoteNode note) {
  MxlBeamNode? tertiary;
  for (final beam in note.beams) {
    if (beam.number == 3) {
      tertiary = beam;
      break;
    }
  }

  if (tertiary == null) {
    return null;
  }

  final value = tertiary.value.trim().toLowerCase();
  if (value == 'begin' ||
      value == 'continue' ||
      value == 'end' ||
      value == 'forward hook' ||
      value == 'backward hook') {
    return value;
  }

  return null;
}

String? _primaryBeamFromNoteNode(MxlNoteNode note) {
  MxlBeamNode? primary;
  for (final beam in note.beams) {
    if (beam.number == null || beam.number == 1) {
      primary = beam;
      break;
    }
    primary ??= beam;
  }

  if (primary == null) {
    return null;
  }

  final value = primary.value.trim().toLowerCase();
  if (value == 'begin' ||
      value == 'continue' ||
      value == 'end' ||
      value == 'forward hook' ||
      value == 'backward hook') {
    return value;
  }

  return null;
}

double? _notatedBeatsFromNoteNode(MxlNoteNode note) {
  final type = note.type?.trim().toLowerCase();
  if (type == null || type.isEmpty) {
    return null;
  }

  final baseBeats = switch (type) {
    'whole' => 4.0,
    'half' => 2.0,
    'quarter' => 1.0,
    'eighth' => 0.5,
    '16th' => 0.25,
    '32nd' => 0.125,
    _ => -1.0,
  };
  if (baseBeats < 0) {
    return null;
  }

  final dotCount = note.raw.children
      .where((child) => _nameEquals(child.name, 'dot'))
      .length;
  if (dotCount == 0) {
    return baseBeats;
  }

  var beats = baseBeats;
  var add = baseBeats / 2;
  for (var i = 0; i < dotCount; i++) {
    beats += add;
    add /= 2;
  }
  return beats;
}

MxlElementNode? _firstChildByName(
  Iterable<MxlElementNode>? nodes,
  String name,
) {
  if (nodes == null) {
    return null;
  }
  return nodes.where((node) => _nameEquals(node.name, name)).firstOrNull;
}

Iterable<MxlElementNode> _childrenByName(
  Iterable<MxlElementNode> nodes,
  String name,
) {
  return nodes.where((node) => _nameEquals(node.name, name));
}

MxlElementNode? _firstDescendantByName(MxlElementNode node, String name) {
  for (final child in node.children) {
    if (_nameEquals(child.name, name)) {
      return child;
    }
    final nested = _firstDescendantByName(child, name);
    if (nested != null) {
      return nested;
    }
  }
  return null;
}

bool _nameEquals(String fullName, String targetLocalName) {
  return _localName(fullName) == targetLocalName;
}

String _localName(String fullName) {
  final idx = fullName.indexOf(':');
  return idx >= 0 ? fullName.substring(idx + 1) : fullName;
}
