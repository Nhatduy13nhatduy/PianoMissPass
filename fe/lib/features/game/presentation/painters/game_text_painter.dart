import 'dart:collection';

import 'package:flutter/material.dart';

class GameTextPainter {
  static const int _maxCachedPainters = 256;
  static final LinkedHashMap<_TextPainterCacheKey, TextPainter>
  _textPainterCache = LinkedHashMap<_TextPainterCacheKey, TextPainter>();

  void paintText(
    Canvas canvas,
    Offset offset,
    String text, {
    required Color color,
    required double fontSize,
    FontWeight fontWeight = FontWeight.w600,
    double maxWidth = 140,
    String? fontFamily,
    double height = 1.0,
  }) {
    final tp = _resolvePainter(
      text: text,
      style: TextStyle(
        color: color,
        fontSize: fontSize,
        fontWeight: fontWeight,
        fontFamily: fontFamily,
        height: height,
      ),
      maxLines: 1,
      ellipsis: '...',
      maxWidth: maxWidth,
    );
    tp.paint(canvas, offset);
  }

  void paintClef(
    Canvas canvas,
    Offset offset,
    String text,
    double fontSize, {
    Color color = const Color(0xFF111111),
  }) {
    final tp = _resolvePainter(
      text: text,
      style: TextStyle(color: color, fontSize: fontSize, height: 1),
      maxLines: 1,
    );
    tp.paint(canvas, offset);
  }

  Size measureText(
    String text, {
    required double fontSize,
    FontWeight fontWeight = FontWeight.w400,
    String? fontFamily,
    double height = 1.0,
    double? maxWidth,
  }) {
    final tp = _resolvePainter(
      text: text,
      style: TextStyle(
        color: const Color(0xFF000000),
        fontSize: fontSize,
        fontWeight: fontWeight,
        fontFamily: fontFamily,
        height: height,
      ),
      maxLines: 1,
      maxWidth: maxWidth,
    );
    return tp.size;
  }

  TextPainter _resolvePainter({
    required String text,
    required TextStyle style,
    required int maxLines,
    String? ellipsis,
    double? maxWidth,
  }) {
    final key = _TextPainterCacheKey(
      text: text,
      colorValue: style.color?.toARGB32() ?? 0,
      fontSize: _quantizeDouble(style.fontSize ?? 14.0),
      fontWeightIndex: style.fontWeight?.value ?? FontWeight.w400.value,
      fontFamily: style.fontFamily ?? '',
      height: _quantizeDouble(style.height ?? 1.0),
      maxLines: maxLines,
      ellipsis: ellipsis ?? '',
      maxWidth: maxWidth == null ? -1 : _quantizeDouble(maxWidth),
    );

    final cached = _textPainterCache.remove(key);
    if (cached != null) {
      _textPainterCache[key] = cached;
      return cached;
    }

    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: maxLines,
      ellipsis: ellipsis,
    );
    if (maxWidth == null) {
      painter.layout();
    } else {
      painter.layout(maxWidth: maxWidth);
    }

    _textPainterCache[key] = painter;
    if (_textPainterCache.length > _maxCachedPainters) {
      _textPainterCache.remove(_textPainterCache.keys.first);
    }

    return painter;
  }

  int _quantizeDouble(double value) {
    return (value * 1000).round();
  }
}

class _TextPainterCacheKey {
  const _TextPainterCacheKey({
    required this.text,
    required this.colorValue,
    required this.fontSize,
    required this.fontWeightIndex,
    required this.fontFamily,
    required this.height,
    required this.maxLines,
    required this.ellipsis,
    required this.maxWidth,
  });

  final String text;
  final int colorValue;
  final int fontSize;
  final int fontWeightIndex;
  final String fontFamily;
  final int height;
  final int maxLines;
  final String ellipsis;
  final int maxWidth;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is _TextPainterCacheKey &&
        other.text == text &&
        other.colorValue == colorValue &&
        other.fontSize == fontSize &&
        other.fontWeightIndex == fontWeightIndex &&
        other.fontFamily == fontFamily &&
        other.height == height &&
        other.maxLines == maxLines &&
        other.ellipsis == ellipsis &&
        other.maxWidth == maxWidth;
  }

  @override
  int get hashCode => Object.hash(
    text,
    colorValue,
    fontSize,
    fontWeightIndex,
    fontFamily,
    height,
    maxLines,
    ellipsis,
    maxWidth,
  );
}
