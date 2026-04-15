part of 'game_note_painter.dart';

class _RenderNote {
  _RenderNote({
    required this.index,
    required this.x,
    required this.y,
    required this.isUpperStaff,
    required this.isTreble,
    required this.noteStep,
    required this.note,
    required this.adjustedHitMs,
    required this.status,
    required this.durationType,
    required this.accidentalToRender,
    required this.stemDirection,
    required this.stemXAxisDirection,
  });

  final int index;
  final double x;
  final double y;
  final bool isUpperStaff;
  final bool isTreble;
  final int noteStep;
  final MusicNote note;
  final int adjustedHitMs;
  final _NoteJudge status;
  final _DurationType durationType;
  final String? accidentalToRender;
  _StemDirection stemDirection;
  _StemDirection stemXAxisDirection;
  double headDx = 0;
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
    required this.stemXByAnchorVisibleIndex,
  });

  final Map<int, _StemDirection> stemDirectionByVisibleIndex;
  final Map<int, double> headDxByVisibleIndex;
  final Set<int> stemAnchorVisibleIndexes;
  final Set<int> chordMemberVisibleIndexes;
  final Map<int, String> chordKeyByVisibleIndex;
  final Map<int, double> stemExtraHeightByAnchorVisibleIndex;
  final Map<int, double> stemXByAnchorVisibleIndex;
}

class _PrecomputedRenderNote {
  const _PrecomputedRenderNote({
    required this.adjustedHitMs,
    required this.isUpperStaff,
    required this.isTreble,
    required this.durationType,
    required this.accidentalToRender,
    required this.stemDirection,
  });

  final int adjustedHitMs;
  final bool isUpperStaff;
  final bool isTreble;
  final _DurationType durationType;
  final String? accidentalToRender;
  final _StemDirection stemDirection;
}

class _PrecomputedScoreRenderData {
  const _PrecomputedScoreRenderData({
    required this.notes,
    required this.beamGroupsByScoreIndex,
    required this.beamAnchorAdjustedHitMsByScoreIndex,
  });

  final List<_PrecomputedRenderNote> notes;
  final List<List<int>> beamGroupsByScoreIndex;
  final List<int?> beamAnchorAdjustedHitMsByScoreIndex;
}

enum _NoteJudge { pending, pass, miss }

enum _DurationType { whole, half, quarter, eighth, sixteenth, thirtySecond }

enum _StemDirection { up, down }

enum _SlurAnchorMode { center, outsideHead, stemSide }

class _SlurAnchorResolution {
  const _SlurAnchorResolution({
    required this.anchor,
    required this.mode,
  });

  final Offset anchor;
  final _SlurAnchorMode mode;
}
