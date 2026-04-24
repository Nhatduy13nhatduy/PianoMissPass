import 'dart:math' as math;

import 'package:flutter/material.dart';

class NotationMetrics {
  const NotationMetrics({
    required this.screenWidth,
    required this.screenHeight,
    required this.aspectRatio,
    required this.staffRegionHeight,
    required this.staffHeight,
    required this.topPadding,
    required this.staffGap,
    required this.staffLeftInset,
    required this.staffRightInset,
  });

  factory NotationMetrics.fromCanvasSize(
    Size size, {
    double? staffRegionHeight,
    double staffHeightScale = 1.0,
  }) {
    final screenHeight = size.height;
    final screenWidth = size.width;
    final aspectRatio = screenWidth <= 0 ? 1.0 : screenWidth / screenHeight;
    final resolvedStaffRegionHeight = (staffRegionHeight ?? screenHeight)
        .clamp(0.0, screenHeight)
        .toDouble();

    final safeScale = staffHeightScale.clamp(0.5, 2.0).toDouble();
    var staffHeight = (resolvedStaffRegionHeight / 5.0) * safeScale;
    final maxStaffHeight = resolvedStaffRegionHeight / 2.0;
    staffHeight = staffHeight
        .clamp(28.0, maxStaffHeight > 28 ? maxStaffHeight : 28.0)
        .toDouble();
    final remainingVerticalSpace =
        (resolvedStaffRegionHeight - (staffHeight * 2.0)).clamp(
          0.0,
          double.infinity,
        );
    final topPadding = remainingVerticalSpace / 4.0;
    final staffGap = remainingVerticalSpace / 2.0;

    return NotationMetrics(
      screenWidth: screenWidth,
      screenHeight: screenHeight,
      aspectRatio: aspectRatio,
      staffRegionHeight: resolvedStaffRegionHeight,
      staffHeight: staffHeight,
      topPadding: topPadding,
      staffGap: staffGap,
      staffLeftInset: (staffHeight * 0.3).clamp(16.0, 28.0).toDouble(),
      staffRightInset: 0.0,
    );
  }

  final double screenWidth;
  final double screenHeight;
  final double aspectRatio;
  final double staffRegionHeight;
  final double staffHeight;
  final double topPadding;
  final double staffGap;
  final double staffLeftInset;
  final double staffRightInset;

  double get staffSpace => staffHeight / 4;
  double get visualScale {
    final baseStaffHeight = staffRegionHeight / 5.0;
    if (baseStaffHeight <= 0) {
      return 1.0;
    }
    return staffHeight / baseStaffHeight;
  }

  double _scaledClamp(double value, double min, double max) {
    return value.clamp(min * visualScale, max * visualScale).toDouble();
  }

  double get noteHeadHeight => math.max(staffSpace * 1.1, 10.8 * visualScale);
  double get wholeNoteHeadHeight =>
      math.max(staffSpace * 1.42, 12.0 * visualScale);
  double get noteHeadStrokeWidth =>
      math.max(staffSpace * 0.12, 1.1 * visualScale);
  double get slurAnchorHorizontalInset =>
      _scaledClamp(staffSpace * 0.82, 7.0, 14.0);
  double get slurAnchorVerticalInset =>
      _scaledClamp(staffSpace * 0.96, 7.2, 14.2);
  double get slurStartAnchorHorizontalInset =>
      (slurAnchorHorizontalInset * 1.0).toDouble();
  double get slurEndAnchorHorizontalInset =>
      (slurAnchorHorizontalInset * 0.86).toDouble();
  double get slurOutsideHeadHorizontalInset =>
      _scaledClamp(staffSpace * 0.24, 2.0, 5.0);
  double get slurChordHorizontalInsetExtra =>
      _scaledClamp(staffSpace * 0.32, 2.4, 6.4);
  double get slurChordVerticalInsetExtra =>
      _scaledClamp(staffSpace * 0.28, 2.0, 5.2);
  double get slurNoteHeadClearance => _scaledClamp(staffSpace * 0.34, 2.8, 6.2);
  double get slurStemSideNudgeX => _scaledClamp(staffSpace * 0.12, 1.0, 2.4);
  double get slurStemClearanceY => _scaledClamp(staffSpace * 0.34, 2.8, 6.0);
  double get slurBeamClearanceY => _scaledClamp(staffSpace * 0.42, 3.4, 7.2);
  double get slurFingeringClearanceY =>
      _scaledClamp(staffSpace * 0.52, 4.0, 8.8);
  double get slurAccidentalClearanceX =>
      _scaledClamp(staffSpace * 0.92, 7.4, 15.0);
  double get slurAutoplaceMinDistance =>
      _scaledClamp(staffSpace * 0.46, 3.2, 7.6);
  double get slurAnchorLocalCollisionZoneX =>
      _scaledClamp(staffSpace * 2.1, 14.0, 32.0);
  double get slurAccidentalXWeight => 1.2;
  double get slurBeamAnchorYWeight => 1.08;
  double get slurFingeringAnchorYWeight => 1.12;
  double get slurDotAnchorYWeight => 0.96;
  double get slurStaccatoAnchorYWeight => 1.0;
  double get slurAnchorDotClearanceY =>
      _scaledClamp(staffSpace * 0.32, 2.4, 5.6);
  double get slurAnchorStaccatoClearanceY =>
      _scaledClamp(staffSpace * 0.38, 2.8, 6.4);
  double get slurBodyNoteClearance => _scaledClamp(staffSpace * 0.5, 3.6, 8.0);
  double get slurBodyNoteArcLiftWeight => 1.0;
  double get slurBodyNoteArcLiftMax =>
      _scaledClamp(staffSpace * 0.75, 5.0, 10.0);
  double get slurNoteCollisionClearance =>
      _scaledClamp(staffSpace * 0.42, 3.0, 7.0);
  double get slurControlInsetRatio => 0.28;
  double get slurControlInsetMin => _scaledClamp(staffSpace * 1.55, 10.0, 20.0);
  double get slurControlInsetMax => _scaledClamp(staffSpace * 4.6, 22.0, 44.0);
  double get slurArcHeightRatio => 0.085;
  double get slurArcHeightMin => _scaledClamp(staffSpace * 1.18, 8.0, 16.0);
  double get slurArcHeightMax => _scaledClamp(staffSpace * 2.7, 16.0, 30.0);
  double get slurArcHeightSpanRatioCap => 0.26;
  double get slurShortSpanBoostThreshold =>
      _scaledClamp(staffSpace * 6.4, 42.0, 88.0);
  double get slurShortSpanBoostMax => _scaledClamp(staffSpace * 0.7, 5.0, 10.0);
  double get slurSlopeBoostMax => _scaledClamp(staffSpace * 0.45, 3.0, 6.0);
  double get slurStackGap => _scaledClamp(staffSpace * 0.82, 6.0, 14.0);
  double get slurStackOverlapPadding =>
      _scaledClamp(staffSpace * 0.55, 4.0, 10.0);
  double get slurShoulderDropRatio => 0.1;
  double get slurEndThickness => _scaledClamp(staffSpace * 0.08, 0.65, 1.25);
  double get slurMiddleThickness => _scaledClamp(staffSpace * 0.24, 1.8, 3.2);
  double get slurOuterThicknessRatio => 0.66;
  double get slurInnerThicknessRatio => 0.34;
  double get slurPartialHangRatio => 0.42;

  double get trebleMainClefX => staffLeftInset + staffSpace * 0.68;
  double get bassMainClefX => staffLeftInset + staffSpace * 0.82;
  double get clefBaselineOffsetY => staffSpace * 0.35;
  double get clefFontSize => math.max(staffSpace * 4.65, 62.0 * visualScale);
  double get movingClefOffsetX => staffSpace * 0.35;

  double get keySignatureStartX => staffLeftInset + staffSpace * 4.55;
  double get keyToTimeSignatureGap => _scaledClamp(staffSpace * 0.2, 4.0, 10.0);
  double get timeSignatureToPlayheadGap =>
      _scaledClamp(staffSpace * 1.15, 12.0, 22.0);
  double get fixedPlayheadX => staffLeftInset + staffSpace * 12;
  double get measureLineOffsetX => -staffSpace * 1.33;
  double get keySignatureGlyphFontSize =>
      math.max(staffSpace * 3.45, 25.0 * visualScale);
  double get keySignatureBaselineNudgeSharp => staffSpace * 0.14;
  double get keySignatureBaselineNudgeFlat => staffSpace * 0.28;
  double get keySignatureSpacingX =>
      _scaledClamp(staffSpace * 1.38, 11.0, 19.0);
  double get keySignatureTrailingGap =>
      _scaledClamp(staffSpace * 1.95, 12.0, 26.0);

  double get timeSignatureTargetDigitHeight =>
      math.max(staffHeight * 0.55, 24.0 * visualScale);
  double get timeSignatureVisualScale => 1.85;
  double get timeSignatureMinFontSize => 44.0 * visualScale;
  double get timeSignatureMaxFontSize =>
      math.max(110.0 * visualScale, timeSignatureMinFontSize);
  double get timeSignatureTopCenterOffset => staffSpace * 1.0;
  double get timeSignatureBottomCenterOffset => staffSpace * 4.35;
  double get timeSignatureMaxWidthPadding =>
      _scaledClamp(staffSpace * 0.42, 4.0, 10.0);

  double get playheadStrokeWidth => _scaledClamp(staffSpace * 0.15, 1.8, 2.6);
  double get measureLineStrokeWidth =>
      _scaledClamp(staffSpace * 0.09, 1.0, 1.6);
  double get symbolLabelFontSize => _scaledClamp(staffSpace * 0.93, 12.0, 16.0);
  double get symbolLabelTopOffset => staffSpace * 1.05;
  double get symbolLabelOffsetX => staffSpace * 0.27;

  double get noteInkColorFontScale => staffSpace;
  double get restWholeHalfScaleFactor => 3.55;
  double get restOtherScaleFactor => 2.8;
  double get restWholeHalfMinFontSize => 41.0 * visualScale;
  double get restWholeHalfMaxFontSize => 98.0 * visualScale;
  double get restOtherMinFontSize => 32.0 * visualScale;
  double get restOtherMaxFontSize => 84.0 * visualScale;

  double get keyboardTotalHeight =>
      keyboardWhiteHeight + keyboardBedBottomInset;

  double get keyboardTopInset => (staffHeight * 0.82).clamp(44.0, 62.0);
  double get keyboardWhiteHeight {
    var height = screenHeight * 0.108;
    if (aspectRatio >= 2.1) {
      height *= 0.94;
    } else if (aspectRatio <= 1.45) {
      height *= 1.08;
    }
    return height.clamp(43.0, 69.0).toDouble();
  }

  double get keyboardBlackHeightRatio {
    final ratio = aspectRatio >= 2.1 ? 0.77 : 0.79;
    return ratio.clamp(0.72, 0.84).toDouble();
  }

  double get keyboardBlackWidthRatio {
    final ratio = screenWidth >= 1180 ? 0.54 : 0.58;
    return ratio.clamp(0.52, 0.6).toDouble();
  }

  double get keyboardWhiteGap =>
      (keyboardWhiteHeight * 0.012).clamp(0.45, 1.1).toDouble();
  double get keyboardBedTopInset =>
      (keyboardWhiteHeight * 0.075).clamp(3.0, 6.0).toDouble();
  double get keyboardBedBottomInset =>
      (keyboardWhiteHeight * 0.2).clamp(10.0, 16.0).toDouble();
  double get keyboardWhiteCornerRadius =>
      (keyboardWhiteHeight * 0.06).clamp(3.0, 6.0).toDouble();
  double get keyboardBlackCornerRadius =>
      (keyboardWhiteHeight * 0.05).clamp(3.0, 5.0).toDouble();
  double get keyboardWhiteShadowBlur =>
      (keyboardWhiteHeight * 0.07).clamp(2.0, 4.8).toDouble();
  double get keyboardBlackShadowBlur =>
      (keyboardWhiteHeight * 0.075).clamp(2.0, 4.8).toDouble();
  double get keyboardWhiteShadowOffsetY =>
      (keyboardWhiteHeight * 0.022).clamp(0.9, 1.8).toDouble();
  double get keyboardBlackShadowOffsetY =>
      (keyboardWhiteHeight * 0.026).clamp(1.0, 2.0).toDouble();
  double get keyboardWhiteHighlightHeightRatio =>
      aspectRatio >= 2.1 ? 0.18 : 0.2;
  double get keyboardBlackHighlightHeightRatio =>
      aspectRatio >= 2.1 ? 0.13 : 0.14;
  double get keyboardWhitePressDepth =>
      (keyboardWhiteHeight * 0.06).clamp(3.0, 5.0).toDouble();
  double get keyboardBlackPressDepth =>
      (keyboardWhiteHeight * 0.055).clamp(2.0, 4.0).toDouble();
}
