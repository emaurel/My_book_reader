import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/theme/app_theme.dart';
import '../../../main.dart';

class ReaderSettings {
  const ReaderSettings({
    this.fontSize = 18.0,
    this.lineHeight = 1.5,
    this.horizontalPadding = 24.0,
    this.fontFamily = 'Inter',
    this.theme = ReaderTheme.sepia,
    this.keepScreenOn = true,
  });

  final double fontSize;
  final double lineHeight;
  final double horizontalPadding;
  final String fontFamily;
  final ReaderTheme theme;
  final bool keepScreenOn;

  ReaderSettings copyWith({
    double? fontSize,
    double? lineHeight,
    double? horizontalPadding,
    String? fontFamily,
    ReaderTheme? theme,
    bool? keepScreenOn,
  }) =>
      ReaderSettings(
        fontSize: fontSize ?? this.fontSize,
        lineHeight: lineHeight ?? this.lineHeight,
        horizontalPadding: horizontalPadding ?? this.horizontalPadding,
        fontFamily: fontFamily ?? this.fontFamily,
        theme: theme ?? this.theme,
        keepScreenOn: keepScreenOn ?? this.keepScreenOn,
      );

  TextStyle textStyle() => TextStyle(
        fontSize: fontSize,
        height: lineHeight,
        color: theme.foreground,
      );
}

const _fontSizeKey = 'reader.fontSize';
const _lineHeightKey = 'reader.lineHeight';
const _paddingKey = 'reader.padding';
const _fontFamilyKey = 'reader.fontFamily';
const _themeKey = 'reader.theme';
const _keepScreenOnKey = 'reader.keepScreenOn';

const availableFonts = ['Inter', 'Lora', 'Merriweather', 'Source Serif 4'];

final readerSettingsProvider =
    StateNotifierProvider<ReaderSettingsNotifier, ReaderSettings>((ref) {
  return ReaderSettingsNotifier(ref.watch(sharedPreferencesProvider));
});

class ReaderSettingsNotifier extends StateNotifier<ReaderSettings> {
  ReaderSettingsNotifier(this._prefs) : super(_load(_prefs));

  final SharedPreferences _prefs;

  static ReaderSettings _load(SharedPreferences p) {
    return ReaderSettings(
      fontSize: p.getDouble(_fontSizeKey) ?? 18,
      lineHeight: p.getDouble(_lineHeightKey) ?? 1.5,
      horizontalPadding: p.getDouble(_paddingKey) ?? 24,
      fontFamily: p.getString(_fontFamilyKey) ?? 'Inter',
      theme: ReaderTheme.values.firstWhere(
        (t) => t.name == p.getString(_themeKey),
        orElse: () => ReaderTheme.sepia,
      ),
      keepScreenOn: p.getBool(_keepScreenOnKey) ?? true,
    );
  }

  Future<void> setFontSize(double v) async {
    state = state.copyWith(fontSize: v);
    await _prefs.setDouble(_fontSizeKey, v);
  }

  Future<void> setLineHeight(double v) async {
    state = state.copyWith(lineHeight: v);
    await _prefs.setDouble(_lineHeightKey, v);
  }

  Future<void> setPadding(double v) async {
    state = state.copyWith(horizontalPadding: v);
    await _prefs.setDouble(_paddingKey, v);
  }

  Future<void> setFontFamily(String v) async {
    state = state.copyWith(fontFamily: v);
    await _prefs.setString(_fontFamilyKey, v);
  }

  Future<void> setTheme(ReaderTheme t) async {
    state = state.copyWith(theme: t);
    await _prefs.setString(_themeKey, t.name);
  }

  Future<void> setKeepScreenOn(bool v) async {
    state = state.copyWith(keepScreenOn: v);
    await _prefs.setBool(_keepScreenOnKey, v);
  }
}
