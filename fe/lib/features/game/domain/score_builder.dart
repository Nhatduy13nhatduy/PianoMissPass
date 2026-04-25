part of 'game_score.dart';

ScoreData buildScoreDataFromMxlDocument(MxlDocumentData document) {
  if (document.parts.isEmpty) {
    return const ScoreData(
      bpm: 100,
      beatsPerMeasure: 4,
      beatUnit: 4,
      notes: <MusicNote>[],
      playbackNotes: <MusicNote>[],
      slurs: <SlurSpan>[],
      symbols: <MusicSymbol>[],
      keySignatures: <KeySignatureChange>[],
      colors: GameColorScheme.classic,
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
  final playbackNotes = <MusicNote>[];
  final noteSourceOrders = <int>[];
  final rawSlurEvents = <_PendingSlurEvent>[];
  final symbols = <MusicSymbol>[];
  final keySignatures = <KeySignatureChange>[];
  final measureSpans = <_RepeatMeasureSpan>[];
  final globalStaffByVoice = <int, int>{};
  int? globalLastExplicitStaff;
  var elapsedMs = 0;
  var sourceNoteOrder = 0;
  int? previousRawMeasureNumber;
  var previousLogicalMeasureIndex = -1;

  for (
    var measureIndex = 0;
    measureIndex < part.measures.length;
    measureIndex++
  ) {
    final measure = part.measures[measureIndex];
    final logicalMeasureIndex = _resolveLogicalMeasureIndex(
      measure,
      fallbackSequentialIndex: measureIndex,
      previousRawMeasureNumber: previousRawMeasureNumber,
      previousLogicalMeasureIndex: previousLogicalMeasureIndex,
    );
    previousRawMeasureNumber = measure.number;
    previousLogicalMeasureIndex = logicalMeasureIndex;

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
    final measureStartMs = elapsedMs;
    symbols.add(
      MusicSymbol(
        label: '|',
        timeMs: measureStartMs,
        measureIndex: logicalMeasureIndex,
      ),
    );

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
          MusicSymbol(
            label: 'Key $keyFifths',
            timeMs: measureStartMs,
            measureIndex: logicalMeasureIndex,
          ),
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
          MusicSymbol(
            label: '$beats/$beatType',
            timeMs: measureStartMs,
            measureIndex: logicalMeasureIndex,
          ),
        );
      }
    }

    var measureBpm = bpm;
    for (final direction in _childrenByName(measure.elements, 'direction')) {
      final tempoText = _firstDescendantByName(
        direction,
        'sound',
      )?.attributes['tempo'];
      if (tempoText != null) {
        measureBpm = double.tryParse(tempoText) ?? measureBpm;
        bpm = measureBpm;
        symbols.add(
          MusicSymbol(
            label: 'Tempo ${measureBpm.toStringAsFixed(0)}',
            timeMs: measureStartMs,
            measureIndex: logicalMeasureIndex,
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
            measureIndex: logicalMeasureIndex,
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
    final pendingGraceNotes = <_PendingGracePlaybackNote>[];

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

      final midi = isRest
          ? null
          : pitchToMidiFromPitch(
              step: note.step,
              octave: note.octave,
              alter: note.alter ?? 0,
            );
      final step = note.step;
      final octave = note.octave;
      final isTrebleFromMxl = staffNumber == null
          ? null
          : (staffClefIsTreble[staffNumber] ?? (staffNumber == 1));
      final staffStep = isRest ? null : staffStepFromPitch(step, octave);

      if (isGrace) {
        if (!isRest && midi != null && staffStep != null) {
          pendingGraceNotes.add(
            _PendingGracePlaybackNote(
              midi: midi,
              staffStep: staffStep,
              voice: voice,
              staffNumber: staffNumber,
              measureIndex: logicalMeasureIndex,
              isTrebleFromMxl: isTrebleFromMxl,
              durationDivisions: duration,
              isChord: isChord,
            ),
          );
        }
        continue;
      }

      if (!isRest) {
        if (midi != null && staffStep != null) {
          if (pendingGraceNotes.isNotEmpty) {
            playbackNotes.addAll(
              _buildGracePlaybackNotes(
                pendingGraceNotes,
                principalOnsetMs: onsetMs,
                principalHoldMs: holdMs,
                measureStartMs: measureStartMs,
                measureBpm: measureBpm,
                measureDivisions: measureDivisions,
              ),
            );
            pendingGraceNotes.clear();
          }

          final accidental = accidentalGlyph(
            note.alter?.toString(),
            note.accidental,
          );
          final dotCount = note.raw.children
              .where((child) => _nameEquals(child.name, 'dot'))
              .length;
          final isStaccato =
              _firstDescendantByName(note.raw, 'staccato') != null;
          final fingering = _firstDescendantByName(
            note.raw,
            'fingering',
          )?.innerText?.trim();
          final normalizedFingering = (fingering == null || fingering.isEmpty)
              ? null
              : fingering;
          final builtNote = MusicNote(
            midi: midi,
            staffStep: staffStep,
            hitTimeMs: onsetMs,
            holdMs: holdMs,
            voice: voice,
            accidental: accidental,
            isTrebleFromMxl: isTrebleFromMxl,
            staffNumber: staffNumber,
            measureIndex: logicalMeasureIndex,
            notatedBeats: notatedBeats,
            primaryBeam: primaryBeam,
            secondaryBeam: secondaryBeam,
            tertiaryBeam: tertiaryBeam,
            stemFromMxl: stemFromMxl,
            dotCount: dotCount,
            isStaccato: isStaccato,
            fingering: normalizedFingering,
          );
          notes.add(builtNote);
          playbackNotes.add(builtNote);
          final noteSourceOrder = sourceNoteOrder++;
          noteSourceOrders.add(noteSourceOrder);
          for (final slur in note.slurs) {
            final slurEventType = _slurEventTypeFromMxl(slur.type);
            if (slurEventType == null) {
              continue;
            }
            rawSlurEvents.add(
              _PendingSlurEvent(
                sourceOrder: noteSourceOrder,
                partId: part.id ?? '',
                number: slur.number,
                eventType: slurEventType,
                timeMs: onsetMs,
                measureIndex: logicalMeasureIndex,
                voice: voice,
                staffNumber: staffNumber,
                staffStep: staffStep,
                isChord: isChord,
                placement: slur.placement,
                orientation: slur.orientation,
                defaultX: slur.defaultX,
                defaultY: slur.defaultY,
                relativeX: slur.relativeX,
                relativeY: slur.relativeY,
                bezierX: slur.bezierX,
                bezierY: slur.bezierY,
                bezierX2: slur.bezierX2,
                bezierY2: slur.bezierY2,
                lineType: slur.lineType,
                dashLength: slur.dashLength,
                spaceLength: slur.spaceLength,
              ),
            );
          }
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
          MusicSymbol(
            label: 'Rest:$restStaff:$restType',
            timeMs: restTimeMs,
            measureIndex: logicalMeasureIndex,
          ),
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

    elapsedMs =
        measureStartMs +
        _divisionsToTimelineMs(
          measureMaxDiv,
          measureDivisions: measureDivisions,
          measureBpm: measureBpm,
        );
    final measureEndMs = elapsedMs;

    if (pendingGraceNotes.isNotEmpty) {
      final fallbackPrincipalOnsetMs = elapsedMs;
      playbackNotes.addAll(
        _buildGracePlaybackNotes(
          pendingGraceNotes,
          principalOnsetMs: fallbackPrincipalOnsetMs,
          principalHoldMs: 0,
          measureStartMs: measureStartMs,
          measureBpm: measureBpm,
          measureDivisions: measureDivisions,
        ),
      );
      pendingGraceNotes.clear();
    }

    measureSpans.add(
      _RepeatMeasureSpan(
        measureIndex: logicalMeasureIndex,
        startTimeMs: measureStartMs,
        endTimeMs: measureEndMs,
        hasForwardRepeat: _hasForwardRepeatBarline(measure),
        hasBackwardRepeat: _hasBackwardRepeatBarline(measure),
      ),
    );
  }

  final sortedNoteEntries = notes.indexed
      .map((entry) => (note: entry.$2, sourceOrder: noteSourceOrders[entry.$1]))
      .toList();
  sortedNoteEntries.sort((a, b) {
    final timeComparison = a.note.hitTimeMs.compareTo(b.note.hitTimeMs);
    if (timeComparison != 0) {
      return timeComparison;
    }
    final measureComparison = a.note.measureIndex.compareTo(
      b.note.measureIndex,
    );
    if (measureComparison != 0) {
      return measureComparison;
    }
    final voiceComparison = a.note.voice.compareTo(b.note.voice);
    if (voiceComparison != 0) {
      return voiceComparison;
    }
    final staffComparison = (a.note.staffNumber ?? 0).compareTo(
      b.note.staffNumber ?? 0,
    );
    if (staffComparison != 0) {
      return staffComparison;
    }
    return a.note.staffStep.compareTo(b.note.staffStep);
  });
  notes
    ..clear()
    ..addAll(sortedNoteEntries.map((entry) => entry.note));
  symbols.sort((a, b) => a.timeMs.compareTo(b.timeMs));
  final slurs = _buildSlurSpans(
    notes: notes,
    rawEvents: rawSlurEvents,
    sortedNoteEntries: sortedNoteEntries,
  );
  final unfolded = _expandScoreForRepeats(
    notes: notes,
    playbackNotes: _sortPlaybackNotes(playbackNotes),
    slurs: slurs,
    symbols: symbols,
    keySignatures: keySignatures,
    measureSpans: measureSpans,
  );

  final midiValues = unfolded.notes.map((note) => note.midi).toList();
  final minMidi = midiValues.isEmpty ? 48 : midiValues.reduce(math.min);
  final maxMidi = midiValues.isEmpty ? 72 : midiValues.reduce(math.max);

  return ScoreData(
    bpm: bpm,
    beatsPerMeasure: beats,
    beatUnit: beatType,
    notes: unfolded.notes,
    playbackNotes: unfolded.playbackNotes,
    slurs: unfolded.slurs,
    symbols: unfolded.symbols,
    keySignatures: unfolded.keySignatures,
    colors: GameColorScheme.classic,
    minMidi: minMidi,
    maxMidi: maxMidi,
  );
}

List<MusicNote> _sortPlaybackNotes(List<MusicNote> notes) {
  final sorted = List<MusicNote>.from(notes);
  sorted.sort(_compareMusicNotes);
  return List<MusicNote>.unmodifiable(sorted);
}

int _resolveLogicalMeasureIndex(
  MxlMeasureNode measure, {
  required int fallbackSequentialIndex,
  required int? previousRawMeasureNumber,
  required int previousLogicalMeasureIndex,
}) {
  final rawNumber = measure.number;
  if (rawNumber == null) {
    return fallbackSequentialIndex;
  }

  if (previousRawMeasureNumber != null &&
      rawNumber == previousRawMeasureNumber) {
    return previousLogicalMeasureIndex;
  }

  if (rawNumber <= 0) {
    return -1;
  }

  return rawNumber - 1;
}

bool _hasBackwardRepeatBarline(MxlMeasureNode measure) {
  for (final element in measure.elements) {
    if (!_nameEquals(element.name, 'barline')) {
      continue;
    }
    final repeat = _firstChildByName(element.children, 'repeat');
    if (repeat?.attributes['direction']?.trim().toLowerCase() == 'backward') {
      return true;
    }
  }
  return false;
}

bool _hasForwardRepeatBarline(MxlMeasureNode measure) {
  for (final element in measure.elements) {
    if (!_nameEquals(element.name, 'barline')) {
      continue;
    }
    final repeat = _firstChildByName(element.children, 'repeat');
    if (repeat?.attributes['direction']?.trim().toLowerCase() == 'forward') {
      return true;
    }
  }
  return false;
}

_ExpandedScoreData _expandScoreForRepeats({
  required List<MusicNote> notes,
  required List<MusicNote> playbackNotes,
  required List<SlurSpan> slurs,
  required List<MusicSymbol> symbols,
  required List<KeySignatureChange> keySignatures,
  required List<_RepeatMeasureSpan> measureSpans,
}) {
  if (measureSpans.isEmpty) {
    return _ExpandedScoreData(
      notes: List<MusicNote>.unmodifiable(notes),
      playbackNotes: List<MusicNote>.unmodifiable(playbackNotes),
      slurs: List<SlurSpan>.unmodifiable(slurs),
      symbols: List<MusicSymbol>.unmodifiable(symbols),
      keySignatures: List<KeySignatureChange>.unmodifiable(keySignatures),
    );
  }

  final expandedNotes = List<MusicNote>.from(notes);
  final expandedPlaybackNotes = List<MusicNote>.from(playbackNotes);
  final expandedSymbols = List<MusicSymbol>.from(symbols);
  final expandedKeySignatures = List<KeySignatureChange>.from(keySignatures);
  final expandedSlurs = List<SlurSpan>.from(slurs);
  final expandedMeasureSpans = List<_RepeatMeasureSpan>.from(measureSpans);

  var repeatStartMeasureIndex = expandedMeasureSpans.first.measureIndex;

  for (var i = 0; i < expandedMeasureSpans.length; i++) {
    final span = expandedMeasureSpans[i];
    if (span.hasForwardRepeat) {
      repeatStartMeasureIndex = span.measureIndex;
    }
    if (!span.hasBackwardRepeat) {
      continue;
    }

    final repeatedMeasureSpans = expandedMeasureSpans
        .where(
          (candidate) =>
              candidate.measureIndex >= repeatStartMeasureIndex &&
              candidate.measureIndex <= span.measureIndex,
        )
        .toList();
    if (repeatedMeasureSpans.isEmpty) {
      continue;
    }

    final segmentStartMs = repeatedMeasureSpans.first.startTimeMs;
    final segmentEndMs = repeatedMeasureSpans.last.endTimeMs;
    final timeShiftMs = segmentEndMs - segmentStartMs;
    if (timeShiftMs <= 0) {
      continue;
    }

    final insertionTimeMs = segmentEndMs;
    final originalNoteCount = expandedNotes.length;
    final noteIndexMap = <int, int>{};
    for (var noteIndex = 0; noteIndex < originalNoteCount; noteIndex++) {
      final note = expandedNotes[noteIndex];
      if (note.hitTimeMs < segmentStartMs || note.hitTimeMs >= segmentEndMs) {
        continue;
      }
      final duplicated = _shiftMusicNote(note, timeShiftMs);
      noteIndexMap[noteIndex] = expandedNotes.length;
      expandedNotes.add(duplicated);
    }

    for (var noteIndex = 0; noteIndex < originalNoteCount; noteIndex++) {
      final note = expandedNotes[noteIndex];
      if (note.hitTimeMs >= insertionTimeMs) {
        expandedNotes[noteIndex] = _shiftMusicNote(note, timeShiftMs);
      }
    }

    final originalPlaybackCount = expandedPlaybackNotes.length;
    for (var iPlayback = 0; iPlayback < originalPlaybackCount; iPlayback++) {
      final note = expandedPlaybackNotes[iPlayback];
      if (note.hitTimeMs < segmentStartMs || note.hitTimeMs >= segmentEndMs) {
        if (note.hitTimeMs >= insertionTimeMs) {
          expandedPlaybackNotes[iPlayback] = _shiftMusicNote(note, timeShiftMs);
        }
        continue;
      }
      expandedPlaybackNotes.add(_shiftMusicNote(note, timeShiftMs));
    }

    final originalSymbolCount = expandedSymbols.length;
    final segmentSymbols = expandedSymbols
        .where(
          (symbol) =>
              symbol.timeMs >= segmentStartMs && symbol.timeMs < segmentEndMs,
        )
        .toList();
    for (var symbolIndex = 0; symbolIndex < originalSymbolCount; symbolIndex++) {
      final symbol = expandedSymbols[symbolIndex];
      if (symbol.timeMs >= insertionTimeMs) {
        expandedSymbols[symbolIndex] = MusicSymbol(
          label: symbol.label,
          timeMs: symbol.timeMs + timeShiftMs,
          measureIndex: symbol.measureIndex,
        );
      }
    }
    for (final symbol in segmentSymbols) {
      expandedSymbols.add(
        MusicSymbol(
          label: symbol.label,
          timeMs: symbol.timeMs + timeShiftMs,
          measureIndex: symbol.measureIndex,
        ),
      );
    }

    final originalKeyCount = expandedKeySignatures.length;
    for (var keyIndex = 0; keyIndex < originalKeyCount; keyIndex++) {
      final key = expandedKeySignatures[keyIndex];
      if (key.timeMs >= insertionTimeMs) {
        expandedKeySignatures[keyIndex] = KeySignatureChange(
          timeMs: key.timeMs + timeShiftMs,
          fifths: key.fifths,
        );
      }
    }

    final repeatedStartMs = insertionTimeMs;
    final keyAtSegmentStart = _activeKeySignatureAtTime(
      expandedKeySignatures,
      segmentStartMs,
    );
    if (keyAtSegmentStart != null) {
      expandedKeySignatures.add(
        KeySignatureChange(
          timeMs: repeatedStartMs,
          fifths: keyAtSegmentStart.fifths,
        ),
      );
    }
    final duplicatedKeys = expandedKeySignatures
        .where((key) => key.timeMs >= segmentStartMs && key.timeMs < segmentEndMs)
        .toList();
    for (final key in duplicatedKeys) {
      if (key.timeMs == repeatedStartMs && key.fifths == keyAtSegmentStart?.fifths) {
        continue;
      }
      if (key.timeMs >= insertionTimeMs) {
        continue;
      }
      expandedKeySignatures.add(
        KeySignatureChange(timeMs: key.timeMs + timeShiftMs, fifths: key.fifths),
      );
    }

    final originalSlurCount = expandedSlurs.length;
    for (var slurIndex = 0; slurIndex < originalSlurCount; slurIndex++) {
      expandedSlurs[slurIndex] = _shiftSlurSpanTimesAfter(
        expandedSlurs[slurIndex],
        insertionTimeMs: insertionTimeMs,
        timeShiftMs: timeShiftMs,
      );
    }

    for (var slurIndex = 0; slurIndex < originalSlurCount; slurIndex++) {
      final slur = expandedSlurs[slurIndex];
      if (!_slurInsideRepeatedSegment(
        slur,
        segmentStartMs,
        segmentEndMs,
        expandedNotes,
      )) {
        continue;
      }
      final duplicated = _duplicateSlurSpan(
        slur,
        noteIndexMap: noteIndexMap,
        timeShiftMs: timeShiftMs,
      );
      if (duplicated != null) {
        expandedSlurs.add(duplicated);
      }
    }

    for (var spanIndex = i + 1; spanIndex < expandedMeasureSpans.length; spanIndex++) {
      final futureSpan = expandedMeasureSpans[spanIndex];
      expandedMeasureSpans[spanIndex] = _RepeatMeasureSpan(
        measureIndex: futureSpan.measureIndex,
        startTimeMs: futureSpan.startTimeMs + timeShiftMs,
        endTimeMs: futureSpan.endTimeMs + timeShiftMs,
        hasForwardRepeat: futureSpan.hasForwardRepeat,
        hasBackwardRepeat: futureSpan.hasBackwardRepeat,
      );
    }
  }

  final indexedExpandedNotes = expandedNotes.indexed
      .map((entry) => (originalIndex: entry.$1, note: entry.$2))
      .toList();
  indexedExpandedNotes.sort((a, b) => _compareMusicNotes(a.note, b.note));
  final noteIndexRemap = <int, int>{};
  for (var i = 0; i < indexedExpandedNotes.length; i++) {
    noteIndexRemap[indexedExpandedNotes[i].originalIndex] = i;
  }
  final remappedSlurs = expandedSlurs
      .map((slur) => _remapSlurSpanNoteIndexes(slur, noteIndexRemap))
      .nonNulls
      .toList();

  expandedNotes
    ..clear()
    ..addAll(indexedExpandedNotes.map((entry) => entry.note));
  expandedPlaybackNotes.sort(_compareMusicNotes);
  expandedSymbols.sort((a, b) => a.timeMs.compareTo(b.timeMs));
  expandedKeySignatures.sort((a, b) => a.timeMs.compareTo(b.timeMs));
  remappedSlurs.sort((a, b) {
    final aTime = a.events.isEmpty ? 0 : a.events.first.timeMs;
    final bTime = b.events.isEmpty ? 0 : b.events.first.timeMs;
    return aTime.compareTo(bTime);
  });

  return _ExpandedScoreData(
    notes: List<MusicNote>.unmodifiable(expandedNotes),
    playbackNotes: List<MusicNote>.unmodifiable(expandedPlaybackNotes),
    slurs: List<SlurSpan>.unmodifiable(remappedSlurs),
    symbols: List<MusicSymbol>.unmodifiable(expandedSymbols),
    keySignatures: List<KeySignatureChange>.unmodifiable(expandedKeySignatures),
  );
}

int _compareMusicNotes(MusicNote a, MusicNote b) {
  final timeComparison = a.hitTimeMs.compareTo(b.hitTimeMs);
  if (timeComparison != 0) {
    return timeComparison;
  }
  final graceComparison = (a.isGrace ? 0 : 1).compareTo(b.isGrace ? 0 : 1);
  if (graceComparison != 0) {
    return graceComparison;
  }
  final measureComparison = a.measureIndex.compareTo(b.measureIndex);
  if (measureComparison != 0) {
    return measureComparison;
  }
  final voiceComparison = a.voice.compareTo(b.voice);
  if (voiceComparison != 0) {
    return voiceComparison;
  }
  final staffComparison = (a.staffNumber ?? 0).compareTo(b.staffNumber ?? 0);
  if (staffComparison != 0) {
    return staffComparison;
  }
  return a.staffStep.compareTo(b.staffStep);
}

MusicNote _shiftMusicNote(MusicNote note, int timeShiftMs) {
  return MusicNote(
    midi: note.midi,
    staffStep: note.staffStep,
    hitTimeMs: note.hitTimeMs + timeShiftMs,
    holdMs: note.holdMs,
    voice: note.voice,
    accidental: note.accidental,
    isTrebleFromMxl: note.isTrebleFromMxl,
    staffNumber: note.staffNumber,
    measureIndex: note.measureIndex,
    notatedBeats: note.notatedBeats,
    primaryBeam: note.primaryBeam,
    secondaryBeam: note.secondaryBeam,
    tertiaryBeam: note.tertiaryBeam,
    stemFromMxl: note.stemFromMxl,
    dotCount: note.dotCount,
    isStaccato: note.isStaccato,
    fingering: note.fingering,
    isGrace: note.isGrace,
  );
}

KeySignatureChange? _activeKeySignatureAtTime(
  List<KeySignatureChange> keySignatures,
  int timeMs,
) {
  KeySignatureChange? active;
  for (final key in keySignatures) {
    if (key.timeMs > timeMs) {
      break;
    }
    active = key;
  }
  return active;
}

bool _slurInsideRepeatedSegment(
  SlurSpan slur,
  int segmentStartMs,
  int segmentEndMs,
  List<MusicNote> sourceNotes,
) {
  if (slur.events.isEmpty) {
    return false;
  }
  for (final event in slur.events) {
    final noteIndex = event.noteIndex;
    if (noteIndex < 0 || noteIndex >= sourceNotes.length) {
      return false;
    }
    final noteTimeMs = sourceNotes[noteIndex].hitTimeMs;
    if (noteTimeMs < segmentStartMs || noteTimeMs >= segmentEndMs) {
      return false;
    }
  }
  return true;
}

SlurSpan? _duplicateSlurSpan(
  SlurSpan slur, {
  required Map<int, int> noteIndexMap,
  required int timeShiftMs,
}) {
  final duplicatedEvents = <SlurEvent>[];
  for (final event in slur.events) {
    final remappedNoteIndex = noteIndexMap[event.noteIndex];
    if (remappedNoteIndex == null) {
      return null;
    }
    duplicatedEvents.add(
      SlurEvent(
        partId: event.partId,
        number: event.number,
        eventType: event.eventType,
        noteIndex: remappedNoteIndex,
        timeMs: event.timeMs + timeShiftMs,
        measureIndex: event.measureIndex,
        voice: event.voice,
        staffNumber: event.staffNumber,
        staffStep: event.staffStep,
        isChord: event.isChord,
        placement: event.placement,
        orientation: event.orientation,
        defaultX: event.defaultX,
        defaultY: event.defaultY,
        relativeX: event.relativeX,
        relativeY: event.relativeY,
        bezierX: event.bezierX,
        bezierY: event.bezierY,
        bezierX2: event.bezierX2,
        bezierY2: event.bezierY2,
        lineType: event.lineType,
        dashLength: event.dashLength,
        spaceLength: event.spaceLength,
      ),
    );
  }

  final duplicatedSegments = slur.segments
      .map((segment) {
        final remappedStart = noteIndexMap[segment.startNoteIndex];
        final remappedEnd = noteIndexMap[segment.endNoteIndex];
        if (remappedStart == null || remappedEnd == null) {
          return null;
        }
        return SlurSegment(
          startEventIndex: segment.startEventIndex,
          endEventIndex: segment.endEventIndex,
          startNoteIndex: remappedStart,
          endNoteIndex: remappedEnd,
          isCrossSystemContinuation: segment.isCrossSystemContinuation,
        );
      })
      .nonNulls
      .toList();
  if (duplicatedSegments.length != slur.segments.length) {
    return null;
  }

  return SlurSpan(
    partId: slur.partId,
    number: slur.number,
    voice: slur.voice,
    staffNumber: slur.staffNumber,
    events: List<SlurEvent>.unmodifiable(duplicatedEvents),
    segments: List<SlurSegment>.unmodifiable(duplicatedSegments),
  );
}

SlurSpan _shiftSlurSpanTimesAfter(
  SlurSpan slur, {
  required int insertionTimeMs,
  required int timeShiftMs,
}) {
  final shiftedEvents = slur.events
      .map(
        (event) => SlurEvent(
          partId: event.partId,
          number: event.number,
          eventType: event.eventType,
          noteIndex: event.noteIndex,
          timeMs: event.timeMs >= insertionTimeMs
              ? event.timeMs + timeShiftMs
              : event.timeMs,
          measureIndex: event.measureIndex,
          voice: event.voice,
          staffNumber: event.staffNumber,
          staffStep: event.staffStep,
          isChord: event.isChord,
          placement: event.placement,
          orientation: event.orientation,
          defaultX: event.defaultX,
          defaultY: event.defaultY,
          relativeX: event.relativeX,
          relativeY: event.relativeY,
          bezierX: event.bezierX,
          bezierY: event.bezierY,
          bezierX2: event.bezierX2,
          bezierY2: event.bezierY2,
          lineType: event.lineType,
          dashLength: event.dashLength,
          spaceLength: event.spaceLength,
        ),
      )
      .toList();
  return SlurSpan(
    partId: slur.partId,
    number: slur.number,
    voice: slur.voice,
    staffNumber: slur.staffNumber,
    events: List<SlurEvent>.unmodifiable(shiftedEvents),
    segments: slur.segments,
  );
}

SlurSpan? _remapSlurSpanNoteIndexes(
  SlurSpan slur,
  Map<int, int> noteIndexRemap,
) {
  final remappedEvents = <SlurEvent>[];
  for (final event in slur.events) {
    final remappedNoteIndex = noteIndexRemap[event.noteIndex];
    if (remappedNoteIndex == null) {
      return null;
    }
    remappedEvents.add(
      SlurEvent(
        partId: event.partId,
        number: event.number,
        eventType: event.eventType,
        noteIndex: remappedNoteIndex,
        timeMs: event.timeMs,
        measureIndex: event.measureIndex,
        voice: event.voice,
        staffNumber: event.staffNumber,
        staffStep: event.staffStep,
        isChord: event.isChord,
        placement: event.placement,
        orientation: event.orientation,
        defaultX: event.defaultX,
        defaultY: event.defaultY,
        relativeX: event.relativeX,
        relativeY: event.relativeY,
        bezierX: event.bezierX,
        bezierY: event.bezierY,
        bezierX2: event.bezierX2,
        bezierY2: event.bezierY2,
        lineType: event.lineType,
        dashLength: event.dashLength,
        spaceLength: event.spaceLength,
      ),
    );
  }

  final remappedSegments = slur.segments
      .map((segment) {
        final remappedStart = noteIndexRemap[segment.startNoteIndex];
        final remappedEnd = noteIndexRemap[segment.endNoteIndex];
        if (remappedStart == null || remappedEnd == null) {
          return null;
        }
        return SlurSegment(
          startEventIndex: segment.startEventIndex,
          endEventIndex: segment.endEventIndex,
          startNoteIndex: remappedStart,
          endNoteIndex: remappedEnd,
          isCrossSystemContinuation: segment.isCrossSystemContinuation,
        );
      })
      .nonNulls
      .toList();
  if (remappedSegments.length != slur.segments.length) {
    return null;
  }

  return SlurSpan(
    partId: slur.partId,
    number: slur.number,
    voice: slur.voice,
    staffNumber: slur.staffNumber,
    events: List<SlurEvent>.unmodifiable(remappedEvents),
    segments: List<SlurSegment>.unmodifiable(remappedSegments),
  );
}

List<MusicNote> _buildGracePlaybackNotes(
  List<_PendingGracePlaybackNote> pendingGraceNotes, {
  required int principalOnsetMs,
  required int principalHoldMs,
  required int measureStartMs,
  required double measureBpm,
  required int measureDivisions,
}) {
  if (pendingGraceNotes.isEmpty) {
    return const <MusicNote>[];
  }

  final beatMs = measureBpm <= 0 ? 600 : (60000 / measureBpm).round();
  final defaultUnitMs = (beatMs * 0.18).round().clamp(45, 120).toInt();
  final availableWindowMs = math.max(0, principalOnsetMs - measureStartMs - 8);
  final preferredWindowMs = math
      .max(
        pendingGraceNotes.length * defaultUnitMs,
        math.min(
          principalHoldMs > 0 ? (principalHoldMs * 0.3).round() : defaultUnitMs,
          beatMs ~/ 2,
        ),
      )
      .toInt();
  final totalWindowMs = math
      .max(
        pendingGraceNotes.length * 28,
        math.min(
          availableWindowMs > 0 ? availableWindowMs : preferredWindowMs,
          preferredWindowMs,
        ),
      )
      .toInt();
  final graceUnitMs = math.max(
    28,
    (totalWindowMs / pendingGraceNotes.length).floor(),
  );
  final startMs = principalOnsetMs - graceUnitMs * pendingGraceNotes.length;

  return List<MusicNote>.generate(pendingGraceNotes.length, (index) {
    final grace = pendingGraceNotes[index];
    final explicitHoldMs = grace.durationDivisions > 0
        ? _divisionsToTimelineMs(
            grace.durationDivisions.toDouble(),
            measureDivisions: measureDivisions,
            measureBpm: measureBpm,
          )
        : 0;
    final holdMs = explicitHoldMs > 0
        ? explicitHoldMs.clamp(28, graceUnitMs).toInt()
        : math.max(28, math.min(graceUnitMs, 90));
    return MusicNote(
      midi: grace.midi,
      staffStep: grace.staffStep,
      hitTimeMs: startMs + index * graceUnitMs,
      holdMs: holdMs,
      voice: grace.voice,
      isTrebleFromMxl: grace.isTrebleFromMxl,
      staffNumber: grace.staffNumber,
      measureIndex: grace.measureIndex,
      isGrace: true,
    );
  });
}

List<SlurSpan> _buildSlurSpans({
  required List<MusicNote> notes,
  required List<_PendingSlurEvent> rawEvents,
  required List<({MusicNote note, int sourceOrder})> sortedNoteEntries,
}) {
  if (rawEvents.isEmpty || notes.isEmpty) {
    return const <SlurSpan>[];
  }

  final sourceOrderToSortedIndex = <int, int>{};
  for (var i = 0; i < sortedNoteEntries.length; i++) {
    sourceOrderToSortedIndex[sortedNoteEntries[i].sourceOrder] = i;
  }

  final sortedEvents = rawEvents
      .map((event) {
        final noteIndex = sourceOrderToSortedIndex[event.sourceOrder];
        if (noteIndex == null) {
          return null;
        }
        return SlurEvent(
          partId: event.partId,
          number: event.number,
          eventType: event.eventType,
          noteIndex: noteIndex,
          timeMs: event.timeMs,
          measureIndex: event.measureIndex,
          voice: event.voice,
          staffNumber: event.staffNumber,
          staffStep: event.staffStep,
          isChord: event.isChord,
          placement: event.placement,
          orientation: event.orientation,
          defaultX: event.defaultX,
          defaultY: event.defaultY,
          relativeX: event.relativeX,
          relativeY: event.relativeY,
          bezierX: event.bezierX,
          bezierY: event.bezierY,
          bezierX2: event.bezierX2,
          bezierY2: event.bezierY2,
          lineType: event.lineType,
          dashLength: event.dashLength,
          spaceLength: event.spaceLength,
        );
      })
      .nonNulls
      .toList();

  sortedEvents.sort((a, b) {
    final timeComparison = a.timeMs.compareTo(b.timeMs);
    if (timeComparison != 0) {
      return timeComparison;
    }
    final measureComparison = a.measureIndex.compareTo(b.measureIndex);
    if (measureComparison != 0) {
      return measureComparison;
    }
    final voiceComparison = a.voice.compareTo(b.voice);
    if (voiceComparison != 0) {
      return voiceComparison;
    }
    final staffComparison = (a.staffNumber ?? 0).compareTo(b.staffNumber ?? 0);
    if (staffComparison != 0) {
      return staffComparison;
    }
    final typeComparison = _slurEventTypePriority(
      a.eventType,
    ).compareTo(_slurEventTypePriority(b.eventType));
    if (typeComparison != 0) {
      return typeComparison;
    }
    final noteComparison = a.noteIndex.compareTo(b.noteIndex);
    if (noteComparison != 0) {
      return noteComparison;
    }
    return a.number.compareTo(b.number);
  });

  final activeSpanByKey = <String, _SlurSpanBuilder>{};
  final completedSpans = <SlurSpan>[];

  for (final event in sortedEvents) {
    final spanKey = _slurSpanKey(
      partId: event.partId,
      number: event.number,
      voice: event.voice,
      staffNumber: event.staffNumber,
    );

    switch (event.eventType) {
      case SlurEventType.start:
        final span = activeSpanByKey.putIfAbsent(
          spanKey,
          () => _SlurSpanBuilder(
            partId: event.partId,
            number: event.number,
            voice: event.voice,
            staffNumber: event.staffNumber,
          ),
        );
        span.pushStart(event);
        break;
      case SlurEventType.continuation:
        final span = activeSpanByKey.putIfAbsent(
          spanKey,
          () => _SlurSpanBuilder(
            partId: event.partId,
            number: event.number,
            voice: event.voice,
            staffNumber: event.staffNumber,
          ),
        );
        span.pushContinuation(event);
        break;
      case SlurEventType.stop:
        final span = activeSpanByKey[spanKey];
        if (span == null) {
          continue;
        }
        span.pushStop(event);
        if (span.isClosed) {
          completedSpans.add(span.build());
          activeSpanByKey.remove(spanKey);
        }
        break;
    }
  }

  return completedSpans;
}

SlurEventType? _slurEventTypeFromMxl(String type) {
  return switch (type) {
    'start' => SlurEventType.start,
    'stop' => SlurEventType.stop,
    'continue' => SlurEventType.continuation,
    _ => null,
  };
}

int _slurEventTypePriority(SlurEventType type) {
  return switch (type) {
    SlurEventType.stop => 0,
    SlurEventType.continuation => 1,
    SlurEventType.start => 2,
  };
}

String _slurSpanKey({
  required String partId,
  required int number,
  required int voice,
  required int? staffNumber,
}) {
  return '$partId|$number|$voice|${staffNumber ?? 0}';
}

class _PendingSlurEvent {
  const _PendingSlurEvent({
    required this.sourceOrder,
    required this.partId,
    required this.number,
    required this.eventType,
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

  final int sourceOrder;
  final String partId;
  final int number;
  final SlurEventType eventType;
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

class _PendingGracePlaybackNote {
  const _PendingGracePlaybackNote({
    required this.midi,
    required this.staffStep,
    required this.voice,
    required this.staffNumber,
    required this.measureIndex,
    required this.isTrebleFromMxl,
    required this.durationDivisions,
    required this.isChord,
  });

  final int midi;
  final int staffStep;
  final int voice;
  final int? staffNumber;
  final int measureIndex;
  final bool? isTrebleFromMxl;
  final int durationDivisions;
  final bool isChord;
}

class _RepeatMeasureSpan {
  const _RepeatMeasureSpan({
    required this.measureIndex,
    required this.startTimeMs,
    required this.endTimeMs,
    required this.hasForwardRepeat,
    required this.hasBackwardRepeat,
  });

  final int measureIndex;
  final int startTimeMs;
  final int endTimeMs;
  final bool hasForwardRepeat;
  final bool hasBackwardRepeat;
}

class _ExpandedScoreData {
  const _ExpandedScoreData({
    required this.notes,
    required this.playbackNotes,
    required this.slurs,
    required this.symbols,
    required this.keySignatures,
  });

  final List<MusicNote> notes;
  final List<MusicNote> playbackNotes;
  final List<SlurSpan> slurs;
  final List<MusicSymbol> symbols;
  final List<KeySignatureChange> keySignatures;
}

class _SlurSpanBuilder {
  _SlurSpanBuilder({
    required this.partId,
    required this.number,
    required this.voice,
    required this.staffNumber,
  });

  final String partId;
  final int number;
  final int voice;
  final int? staffNumber;
  final List<SlurEvent> _events = <SlurEvent>[];
  final List<SlurSegment> _segments = <SlurSegment>[];
  int? _lastAnchorEventIndex;
  bool _isClosed = false;

  bool get isClosed => _isClosed;

  void pushStart(SlurEvent event) {
    final eventIndex = _events.length;
    _events.add(event);
    _lastAnchorEventIndex = eventIndex;
    _isClosed = false;
  }

  void pushContinuation(SlurEvent event) {
    if (_events.isEmpty || _lastAnchorEventIndex == null) {
      final eventIndex = _events.length;
      _events.add(event);
      _lastAnchorEventIndex = eventIndex;
      return;
    }

    final eventIndex = _events.length;
    final previousAnchorIndex = _lastAnchorEventIndex!;
    final previousEvent = _events[previousAnchorIndex];
    _events.add(event);
    _segments.add(
      SlurSegment(
        startEventIndex: previousAnchorIndex,
        endEventIndex: eventIndex,
        startNoteIndex: previousEvent.noteIndex,
        endNoteIndex: event.noteIndex,
        isCrossSystemContinuation: true,
      ),
    );
    _lastAnchorEventIndex = eventIndex;
  }

  void pushStop(SlurEvent event) {
    if (_events.isEmpty || _lastAnchorEventIndex == null) {
      return;
    }

    final eventIndex = _events.length;
    final previousAnchorIndex = _lastAnchorEventIndex!;
    final previousEvent = _events[previousAnchorIndex];
    _events.add(event);
    _segments.add(
      SlurSegment(
        startEventIndex: previousAnchorIndex,
        endEventIndex: eventIndex,
        startNoteIndex: previousEvent.noteIndex,
        endNoteIndex: event.noteIndex,
        isCrossSystemContinuation:
            previousEvent.eventType == SlurEventType.continuation,
      ),
    );
    _lastAnchorEventIndex = eventIndex;
    _isClosed = true;
  }

  SlurSpan build() {
    return SlurSpan(
      partId: partId,
      number: number,
      voice: voice,
      staffNumber: staffNumber,
      events: List<SlurEvent>.unmodifiable(_events),
      segments: List<SlurSegment>.unmodifiable(_segments),
    );
  }
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
