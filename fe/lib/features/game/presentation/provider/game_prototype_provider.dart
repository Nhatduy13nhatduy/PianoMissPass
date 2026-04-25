import 'package:flutter/material.dart';

import '../../domain/game_score.dart';
import '../../domain/staff_background.dart';

enum GamePrototypeSettingsTab { gameplay, color }

class GamePrototypeSettingsProvider extends ChangeNotifier {
  GamePrototypeSettingsProvider();

  static const GameColorScheme defaultColors = GameColorScheme.classic;

  static const List<(String, GameStaffBackground)> backgroundPresets = [
    ('White', GameStaffBackground.color(Color(0xE6F4F4F4))),
    (
      'Forest',
      GameStaffBackground.image(
        assetPath:
            'assets/backgrounds/luxury-plain-green-gradient-abstract-studio-background-empty-room-with-space-your-text-picture.jpg',
        fallbackColor: Color(0xFFE5EFE5),
      ),
    ),
    (
      'Paper',
      GameStaffBackground.image(
        assetPath: 'assets/backgrounds/pexels-fwstudio-33348-172295.jpg',
        fallbackColor: Color(0xFFF1E6D6),
      ),
    ),
    (
      'Stone',
      GameStaffBackground.image(
        assetPath: 'assets/backgrounds/pexels-pixabay-235985.jpg',
        fallbackColor: Color(0xFFE8E8E4),
      ),
    ),
    (
      'Soft',
      GameStaffBackground.image(
        assetPath:
            'assets/backgrounds/f8cd0a0d-0f8a-447f-b73c-37e87c224e31.jpg',
        fallbackColor: Color(0xFFE7DFD7),
      ),
    ),
  ];

  static const List<(String, Color?)> staffBackgroundColorOptions = [
    ('Transparent', null),
    ('Mist', Color(0x66EDF3F8)),
    ('Warm Paper', Color(0x73F5E8D7)),
    ('Sage', Color(0x666C8268)),
    ('White', Color(0xE6F4F4F4)),
  ];

  static const List<Color> noteColorOptions = [
    Color(0xFF111111),
    Color(0xFF1C2A3A),
    Color(0xFF2D1E2F),
    Color(0xFF243322),
    Color(0xFF3A2418),
  ];

  static const List<Color> staffStrokeOptions = [
    Color(0xFF111111),
    Color(0xFF22313F),
    Color(0xFF4A403A),
    Color(0xFF2E3D2F),
    Color(0xFF47312A),
  ];

  static const List<Color> notationGlyphOptions = [
    Color(0xFF111111),
    Color(0xFF1F2D3A),
    Color(0xFF2F253D),
    Color(0xFF30422C),
    Color(0xFF4C3423),
  ];

  static const List<Color> keyboardBlackOptions = [
    Color(0xFF1A1A1C),
    Color(0xFF15222D),
    Color(0xFF2A2434),
    Color(0xFF233123),
    Color(0xFF35251E),
  ];

  static const List<Color> keyboardWhiteOptions = [
    Color(0xFFE7EBF0),
    Color(0xFFF5F1E8),
    Color(0xFFE9F0EA),
    Color(0xFFEDE7F3),
    Color(0xFFF2E7E1),
  ];

  static const List<Color> keyboardActiveOptions = [
    Color(0xFF8A6DB8),
    Color(0xFF2B7FFF),
    Color(0xFF2E9C6A),
    Color(0xFFE07A2D),
    Color(0xFFC05780),
  ];

  static const List<Color> neutralGlyphOptions = [
    Color(0xFF222222),
    Color(0xFF34495E),
    Color(0xFF5B4B3A),
    Color(0xFF38553C),
    Color(0xFF5C3B3B),
  ];

  static const List<Color> passAccentOptions = [
    Color(0xFF1E5D31),
    Color(0xFF2E9C6A),
    Color(0xFF2C7A7B),
    Color(0xFF4D8B31),
    Color(0xFF0F766E),
  ];

  static const List<Color> missAccentOptions = [
    Color(0xFF98273B),
    Color(0xFFC44536),
    Color(0xFFD97706),
    Color(0xFFB42318),
    Color(0xFF9F1239),
  ];

  bool _showKeyboard = true;
  double _staffHeightScale = 1.0;
  GamePrototypeSettingsTab _selectedSettingsTab =
      GamePrototypeSettingsTab.gameplay;

  GameStaffBackground _staffBackground = backgroundPresets.first.$2;
  Color? _staffBackgroundColor;

  Color _noteColor = defaultColors.note.idle;
  Color _staffStrokeColor = defaultColors.staff.border;
  Color _notationGlyphColor = defaultColors.notation.clef;
  Color _keyboardBlackColor = defaultColors.keyboard.black;
  Color _keyboardWhiteColor = defaultColors.keyboard.white;
  Color _keyboardActiveColor = defaultColors.keyboard.active;
  Color _neutralGlyphColor = defaultColors.rest.glyph;
  Color _passAccentColor = defaultColors.note.pass;
  Color _missAccentColor = defaultColors.note.miss;

  bool get showKeyboard => _showKeyboard;
  double get staffHeightScale => _staffHeightScale;
  GamePrototypeSettingsTab get selectedSettingsTab => _selectedSettingsTab;

  GameStaffBackground get staffBackground => _staffBackground;
  Color? get staffBackgroundColor => _staffBackgroundColor;

  Color get noteColor => _noteColor;
  Color get staffStrokeColor => _staffStrokeColor;
  Color get notationGlyphColor => _notationGlyphColor;
  Color get keyboardBlackColor => _keyboardBlackColor;
  Color get keyboardWhiteColor => _keyboardWhiteColor;
  Color get keyboardActiveColor => _keyboardActiveColor;
  Color get neutralGlyphColor => _neutralGlyphColor;
  Color get passAccentColor => _passAccentColor;
  Color get missAccentColor => _missAccentColor;

  GameColorScheme get effectiveColors {
    return GameColorScheme(
      staff: GameStaffColorScheme(
        background: _staffBackground,
        backgroundColor: _staffBackgroundColor ?? Colors.transparent,
        border: _staffStrokeColor,
        line: _staffStrokeColor,
        measureLine: _staffStrokeColor,
        judgeLine: defaultColors.staff.judgeLine,
      ),
      note: GameNoteColorScheme(
        idle: _noteColor,
        active: _noteColor,
        pass: _passAccentColor,
        miss: _missAccentColor,
      ),
      accidentalAndSlur: GameAccidentalSlurColorScheme(
        accidental: _neutralGlyphColor,
        slurIdle: _neutralGlyphColor,
        slurPass: _passAccentColor,
        slurMiss: _missAccentColor,
      ),
      fingering: GameFingeringColorScheme(text: _neutralGlyphColor),
      rest: GameRestColorScheme(glyph: _neutralGlyphColor),
      notation: GameNotationColorScheme(
        keySignature: _notationGlyphColor,
        clef: _notationGlyphColor,
        timeSignature: _notationGlyphColor,
      ),
      keyboard: GameKeyboardColorScheme(
        white: _keyboardWhiteColor,
        active: _keyboardActiveColor,
        whiteBorder: _keyboardBlackColor,
        black: _keyboardBlackColor,
      ),
      progress: GameProgressColorScheme(line: _passAccentColor),
    );
  }

  ScoreData resolveEffectiveScore(ScoreData score) {
    return score.copyWith(colors: effectiveColors);
  }

  void selectSettingsTab(GamePrototypeSettingsTab tab) {
    if (_selectedSettingsTab == tab) return;
    _selectedSettingsTab = tab;
    notifyListeners();
  }

  void setShowKeyboard(bool value) {
    if (_showKeyboard == value) return;
    _showKeyboard = value;
    notifyListeners();
  }

  void decreaseStaffHeightScale() {
    setStaffHeightScale(_staffHeightScale - 0.1);
  }

  void increaseStaffHeightScale() {
    setStaffHeightScale(_staffHeightScale + 0.1);
  }

  void setStaffHeightScale(double value) {
    final nextValue = value.clamp(0.5, 2.0).toDouble();
    if (_staffHeightScale == nextValue) return;
    _staffHeightScale = nextValue;
    notifyListeners();
  }

  void setStaffBackground(GameStaffBackground value) {
    if (_sameBackground(_staffBackground, value)) return;
    _staffBackground = value;
    notifyListeners();
  }

  void setStaffBackgroundColor(Color? value) {
    if (_sameOptionalColor(_staffBackgroundColor, value)) return;
    _staffBackgroundColor = value;
    notifyListeners();
  }

  void setNoteColor(Color value) {
    if (_sameColor(_noteColor, value)) return;
    _noteColor = value;
    notifyListeners();
  }

  void setStaffStrokeColor(Color value) {
    if (_sameColor(_staffStrokeColor, value)) return;
    _staffStrokeColor = value;
    notifyListeners();
  }

  void setNotationGlyphColor(Color value) {
    if (_sameColor(_notationGlyphColor, value)) return;
    _notationGlyphColor = value;
    notifyListeners();
  }

  void setKeyboardBlackColor(Color value) {
    if (_sameColor(_keyboardBlackColor, value)) return;
    _keyboardBlackColor = value;
    notifyListeners();
  }

  void setKeyboardWhiteColor(Color value) {
    if (_sameColor(_keyboardWhiteColor, value)) return;
    _keyboardWhiteColor = value;
    notifyListeners();
  }

  void setKeyboardActiveColor(Color value) {
    if (_sameColor(_keyboardActiveColor, value)) return;
    _keyboardActiveColor = value;
    notifyListeners();
  }

  void setNeutralGlyphColor(Color value) {
    if (_sameColor(_neutralGlyphColor, value)) return;
    _neutralGlyphColor = value;
    notifyListeners();
  }

  void setPassAccentColor(Color value) {
    if (_sameColor(_passAccentColor, value)) return;
    _passAccentColor = value;
    notifyListeners();
  }

  void setMissAccentColor(Color value) {
    if (_sameColor(_missAccentColor, value)) return;
    _missAccentColor = value;
    notifyListeners();
  }

  void resetToDefault() {
    _showKeyboard = true;
    _staffHeightScale = 1.0;
    _selectedSettingsTab = GamePrototypeSettingsTab.gameplay;
    _staffBackground = backgroundPresets.first.$2;
    _staffBackgroundColor = null;
    _noteColor = defaultColors.note.idle;
    _staffStrokeColor = defaultColors.staff.border;
    _notationGlyphColor = defaultColors.notation.clef;
    _keyboardBlackColor = defaultColors.keyboard.black;
    _keyboardWhiteColor = defaultColors.keyboard.white;
    _keyboardActiveColor = defaultColors.keyboard.active;
    _neutralGlyphColor = defaultColors.rest.glyph;
    _passAccentColor = defaultColors.note.pass;
    _missAccentColor = defaultColors.note.miss;
    notifyListeners();
  }


  bool _sameColor(Color a, Color b) => a.value == b.value;

  bool _sameOptionalColor(Color? a, Color? b) {
    return a?.value == b?.value && ((a == null) == (b == null));
  }

  bool _sameBackground(GameStaffBackground a, GameStaffBackground b) {
    return a.color?.value == b.color?.value &&
        a.imageAssetPath == b.imageAssetPath &&
        a.fallbackColor?.value == b.fallbackColor?.value;
  }
}
