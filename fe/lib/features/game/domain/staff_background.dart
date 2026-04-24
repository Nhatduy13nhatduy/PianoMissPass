import 'package:flutter/material.dart';

class GameStaffBackground {
  const GameStaffBackground.color(Color this.color)
    : gradient = null,
      imageAssetPath = null,
      imageFit = BoxFit.cover,
      imageAlignment = Alignment.center,
      fallbackColor = null;

  const GameStaffBackground.gradient(Gradient this.gradient)
    : color = null,
      imageAssetPath = null,
      imageFit = BoxFit.cover,
      imageAlignment = Alignment.center,
      fallbackColor = null;

  const GameStaffBackground.image({
    required String assetPath,
    BoxFit fit = BoxFit.cover,
    Alignment alignment = Alignment.center,
    this.fallbackColor,
  }) : color = null,
       gradient = null,
       imageAssetPath = assetPath,
       imageFit = fit,
       imageAlignment = alignment;

  final Color? color;
  final Gradient? gradient;
  final String? imageAssetPath;
  final BoxFit imageFit;
  final Alignment imageAlignment;
  final Color? fallbackColor;

  bool get isColor => color != null;
  bool get isGradient => gradient != null;
  bool get isImage => imageAssetPath != null;
}
