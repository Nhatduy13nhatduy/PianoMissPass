import 'package:flutter_test/flutter_test.dart';
import 'package:pianomisspass_fe/features/game/application/judging/game_note_judge_engine.dart';
import 'package:pianomisspass_fe/features/game/domain/game_score.dart';

void main() {
  test('passes only detected notes in a two-staff chord', () {
    final engine = GameNoteJudgeEngine(hitWindowMs: 140);
    final score = _scoreWithNotes(
      const <MusicNote>[
        MusicNote(
          midi: 60,
          staffStep: 35,
          hitTimeMs: 1000,
          holdMs: 400,
          voice: 1,
          staffNumber: 1,
          measureIndex: 0,
        ),
        MusicNote(
          midi: 48,
          staffStep: 28,
          hitTimeMs: 1000,
          holdMs: 400,
          voice: 1,
          staffNumber: 2,
          measureIndex: 0,
        ),
      ],
    );
    engine.loadScore(score);

    final passed = engine.judgeDetectedNotes(
      currentMs: 1000,
      score: score,
      passedNoteIndexes: const <int>{},
      missedNoteIndexes: const <int>{},
      detectedMidis: const <int>{60},
    );

    expect(passed, const <int>{0});
  });

  test('keeps matching within the nearest unresolved chord', () {
    final engine = GameNoteJudgeEngine(hitWindowMs: 140);
    final score = _scoreWithNotes(
      const <MusicNote>[
        MusicNote(
          midi: 60,
          staffStep: 35,
          hitTimeMs: 930,
          holdMs: 200,
          voice: 1,
          staffNumber: 1,
          measureIndex: 0,
        ),
        MusicNote(
          midi: 60,
          staffStep: 35,
          hitTimeMs: 1080,
          holdMs: 200,
          voice: 1,
          staffNumber: 1,
          measureIndex: 0,
        ),
      ],
    );
    engine.loadScore(score);

    final passed = engine.judgeDetectedNotes(
      currentMs: 1000,
      score: score,
      passedNoteIndexes: const <int>{},
      missedNoteIndexes: const <int>{},
      detectedMidis: const <int>{60},
    );

    expect(passed, const <int>{0});
  });
}

ScoreData _scoreWithNotes(List<MusicNote> notes) {
  return ScoreData(
    bpm: 120,
    beatsPerMeasure: 4,
    beatUnit: 4,
    notes: notes,
    playbackNotes: const <MusicNote>[],
    slurs: const <SlurSpan>[],
    symbols: const <MusicSymbol>[],
    keySignatures: const <KeySignatureChange>[],
    colors: GameColorScheme.classic,
    minMidi: 48,
    maxMidi: 60,
  );
}
