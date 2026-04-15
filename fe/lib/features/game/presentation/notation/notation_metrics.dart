import 'package:flutter/material.dart';

class NotationMetrics {
  const NotationMetrics({
    required this.staffHeight,
    required this.topPadding,
    required this.staffGap,
    required this.staffLeftInset,
    required this.staffRightInset,
  });

  factory NotationMetrics.fromCanvasSize(Size size) {
    final screenHeight = size.height;
    final screenWidth = size.width;
    final aspectRatio = screenWidth <= 0 ? 1.0 : screenWidth / screenHeight;

    // Tune staff size primarily from available vertical room so the score
    // feels consistent across short phones, taller phones, and tablets.
    var staffHeight = (() {
      if (screenHeight <= 360) {
        return screenHeight * 0.16;
      }
      if (screenHeight <= 430) {
        return screenHeight * 0.17;
      }
      if (screenHeight <= 520) {
        return screenHeight * 0.182;
      }
      if (screenHeight <= 680) {
        return screenHeight * 0.19;
      }
      return screenHeight * 0.2;
    })();

    // Very wide layouts often have less perceived vertical density, so give
    // the staff a small lift to avoid looking undersized on larger devices.
    if (aspectRatio >= 2.1) {
      staffHeight *= 1.04;
    } else if (aspectRatio <= 1.45) {
      staffHeight *= 0.97;
    }

    staffHeight = staffHeight.clamp(52.0, 96.0).toDouble();
    return NotationMetrics(
      staffHeight: staffHeight,
      topPadding: (staffHeight * 0.78).clamp(30.0, 56.0).toDouble(),
      staffGap: (staffHeight * 1.45).clamp(74.0, 112.0).toDouble(),
      staffLeftInset: (staffHeight * 0.3).clamp(16.0, 28.0).toDouble(),
      staffRightInset: (staffHeight * 0.04).clamp(0.0, 8.0).toDouble(),
    );
  }

  final double staffHeight;
  final double topPadding;
  final double staffGap;
  final double staffLeftInset;
  final double staffRightInset;

  double get staffSpace => staffHeight / 4;

  double get noteHeadHeight => (staffSpace * 1.07).clamp(10.0, 24.0).toDouble();
  double get wholeNoteHeadHeight =>
      (staffSpace * 1.38).clamp(11.0, 28.0).toDouble();
  double get noteHeadStrokeWidth =>
      (staffSpace * 0.12).clamp(1.1, 2.4).toDouble();
  double get slurAnchorHorizontalInset =>
      (staffSpace * 0.82).clamp(7.0, 14.0).toDouble();
  double get slurAnchorVerticalInset =>
      (staffSpace * 0.96).clamp(7.2, 14.2).toDouble();
  double get slurStartAnchorHorizontalInset =>
      (slurAnchorHorizontalInset * 1.0).toDouble();
  double get slurEndAnchorHorizontalInset =>
      (slurAnchorHorizontalInset * 1.22).toDouble();
  double get slurNoteHeadClearance =>
      (staffSpace * 0.34).clamp(2.8, 6.2).toDouble();
  double get slurStemSideNudgeX =>
      (staffSpace * 0.12).clamp(1.0, 2.4).toDouble();
  double get slurStemClearanceY =>
      (staffSpace * 0.34).clamp(2.8, 6.0).toDouble();
  double get slurBeamClearanceY =>
      (staffSpace * 0.42).clamp(3.4, 7.2).toDouble();
  double get slurFingeringClearanceY =>
      (staffSpace * 0.52).clamp(4.0, 8.8).toDouble();
  double get slurAccidentalClearanceX =>
      (staffSpace * 0.92).clamp(7.4, 15.0).toDouble();
  double get slurAutoplaceMinDistance =>
      (staffSpace * 0.46).clamp(3.2, 7.6).toDouble();
  double get slurControlInsetRatio => 0.28;
  double get slurControlInsetMin =>
      (staffSpace * 1.55).clamp(10.0, 20.0).toDouble();
  double get slurControlInsetMax =>
      (staffSpace * 4.6).clamp(22.0, 44.0).toDouble();
  double get slurArcHeightRatio => 0.072;
  double get slurArcHeightMin =>
      (staffSpace * 0.84).clamp(6.0, 12.0).toDouble();
  double get slurArcHeightMax =>
      (staffSpace * 2.3).clamp(14.0, 26.0).toDouble();
  double get slurShoulderDropRatio => 0.1;
  double get slurEndThickness =>
      (staffSpace * 0.12).clamp(0.9, 1.7).toDouble();
  double get slurMiddleThickness =>
      (staffSpace * 0.24).clamp(1.8, 3.2).toDouble();
  double get slurOuterThicknessRatio => 0.66;
  double get slurInnerThicknessRatio => 0.34;
  double get slurPartialHangRatio => 0.42;

  double get trebleMainClefX => staffLeftInset + staffSpace * 0.68;
  double get bassMainClefX => staffLeftInset + staffSpace * 0.82;
  double get clefBaselineOffsetY => staffSpace * 0.35;
  double get clefFontSize => (staffSpace * 4.8).clamp(58.0, 84.0).toDouble();
  double get movingClefOffsetX => staffSpace * 0.35;

  double get keySignatureStartX => staffLeftInset + staffSpace * 4.55;
  double get keyToTimeSignatureGap =>
      (staffSpace * 0.2).clamp(4.0, 10.0).toDouble();
  double get timeSignatureToPlayheadGap =>
      (staffSpace * 1.15).clamp(12.0, 22.0).toDouble();
  double get measureLineOffsetX => -staffSpace * 1.33;
  double get keySignatureGlyphFontSize =>
      (staffSpace * 3.9).clamp(28.0, 54.0).toDouble();
  double get keySignatureBaselineNudgeSharp => staffSpace * 0.05;
  double get keySignatureBaselineNudgeFlat => staffSpace * 0.18;
  double get keySignatureSpacingX =>
      (staffSpace * 1.28).clamp(10.0, 18.0).toDouble();
  double get keySignatureTrailingGap =>
      (staffSpace * 1.95).clamp(12.0, 26.0).toDouble();

  double get timeSignatureTargetDigitHeight =>
      (staffHeight * 0.55).clamp(24.0, 48.0).toDouble();
  double get timeSignatureVisualScale => 1.95;
  double get timeSignatureMinFontSize => 44.0;
  double get timeSignatureMaxFontSize => 110.0;
  double get timeSignatureTopCenterOffset =>
      (staffSpace * 1.08).clamp(5.0, 28.0).toDouble();
  double get timeSignatureBottomCenterOffset =>
      (staffSpace * 2.92).clamp(14.0, 64.0).toDouble();
  double get timeSignatureMaxWidthPadding =>
      (staffSpace * 0.42).clamp(4.0, 10.0).toDouble();

  double get playheadStrokeWidth => (staffSpace * 0.15).clamp(1.8, 2.6);
  double get measureLineStrokeWidth => (staffSpace * 0.09).clamp(1.0, 1.6);
  double get symbolLabelFontSize => (staffSpace * 0.93).clamp(12.0, 16.0);
  double get symbolLabelTopOffset => staffSpace * 1.05;
  double get symbolLabelOffsetX => staffSpace * 0.27;

  double get noteInkColorFontScale => staffSpace;
  double get restWholeHalfScaleFactor => 2.65;
  double get restOtherScaleFactor => 1.72;
  double get restWholeHalfMinFontSize => 50.0;
  double get restWholeHalfMaxFontSize => 124.0;
  double get restOtherMinFontSize => 32.0;
  double get restOtherMaxFontSize => 84.0;

  double get keyboardTopInset => (staffHeight * 0.82).clamp(44.0, 62.0);
}
