import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../main.dart';

const _localePrefKey = 'app.locale';

/// Locales the app currently has translations for. The system-default
/// option is represented by `null`.
const supportedAppLocales = [
  Locale('en'),
  Locale('fr'),
  Locale('sv'),
];

class LocaleNotifier extends StateNotifier<Locale?> {
  LocaleNotifier(this._prefs) : super(_load(_prefs));

  final SharedPreferences _prefs;

  static Locale? _load(SharedPreferences prefs) {
    final tag = prefs.getString(_localePrefKey);
    if (tag == null || tag.isEmpty) return null;
    return Locale(tag);
  }

  Future<void> set(Locale? locale) async {
    state = locale;
    if (locale == null) {
      await _prefs.remove(_localePrefKey);
    } else {
      await _prefs.setString(_localePrefKey, locale.languageCode);
    }
  }
}

final localeProvider =
    StateNotifierProvider<LocaleNotifier, Locale?>((ref) {
  return LocaleNotifier(ref.watch(sharedPreferencesProvider));
});
