part of 'game_note_painter.dart';

class _RenderNote {
  _RenderNote({
    required this.index,
    required this.x,
    required this.y,
    required this.isTreble,
    required this.noteStep,
    required this.note,
    required this.adjustedHitMs,
    required this.status,
    required this.durationType,
    required this.stemDirection,
  });

  final int index;
  final double x;
  final double y;
  final bool isTreble;
  final int noteStep;
  final MusicNote note;
  final int adjustedHitMs;
  final _NoteJudge status;
  final _DurationType durationType;
  _StemDirection stemDirection;
  Offset? stemTip;
}

class _ExplicitBeamTrackState {
  final List<int> current = <int>[];
  int measureIndex = -1;
}

class _ProjectedBeamGroup {
  const _ProjectedBeamGroup({
    required this.indexes,
    required this.lockedSlope,
    required this.lockedReferenceStemTip,
  });

  final List<int> indexes;
  final double lockedSlope;
  final Offset lockedReferenceStemTip;
}

class _LockedBeamGeometry {
  const _LockedBeamGeometry({
    required this.slope,
    required this.referenceStemTip,
  });

  final double slope;
  final Offset referenceStemTip;
}

class _ChordLayout {
  const _ChordLayout({
    required this.stemDirectionByVisibleIndex,
    required this.headDxByVisibleIndex,
    required this.stemAnchorVisibleIndexes,
    required this.chordMemberVisibleIndexes,
    required this.chordKeyByVisibleIndex,
    required this.stemExtraHeightByAnchorVisibleIndex,
  });

  final Map<int, _StemDirection> stemDirectionByVisibleIndex;
  final Map<int, double> headDxByVisibleIndex;
  final Set<int> stemAnchorVisibleIndexes;
  final Set<int> chordMemberVisibleIndexes;
  final Map<int, String> chordKeyByVisibleIndex;
  final Map<int, double> stemExtraHeightByAnchorVisibleIndex;
}

enum _NoteJudge { pending, pass, miss }

enum _DurationType { whole, half, quarter, eighth, sixteenth }

enum _StemDirection { up, down }
