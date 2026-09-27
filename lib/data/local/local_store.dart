import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/utils/json.dart';

/// The only thing in the app that touches persistent storage.
///
/// Deliberately boring: JSON strings in shared preferences, on the device,
/// behind the app sandbox. No server, no sync, no network permission in the
/// release manifest. If the user uninstalls, the data is gone — which is the
/// privacy trade the brief asked for.
class LocalStore {
  LocalStore({this.namespace = 'savewise.v1.'});

  final String namespace;
  SharedPreferences? _prefs;

  bool get isReady => _prefs != null;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  String _k(String key) => '$namespace$key';

  // ---- primitives ----

  Future<void> setString(String key, String value) async {
    await _prefs?.setString(_k(key), value);
  }

  String? getString(String key) => _prefs?.getString(_k(key));

  Future<void> setBool(String key, bool value) async {
    await _prefs?.setBool(_k(key), value);
  }

  bool getBool(String key, {bool fallback = false}) =>
      _prefs?.getBool(_k(key)) ?? fallback;

  Future<void> remove(String key) async {
    await _prefs?.remove(_k(key));
  }

  // ---- JSON ----

  Future<void> setMap(String key, Map<String, dynamic> value) =>
      setString(key, jsonEncode(value));

  Map<String, dynamic>? getMap(String key) {
    final String? raw = getString(key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is Map) return J.asMap(decoded);
    } catch (_) {
      // Corrupt record: treat as absent rather than crashing on launch.
    }
    return null;
  }

  Future<void> setMapList(String key, List<Map<String, dynamic>> value) =>
      setString(key, jsonEncode(value));

  List<Map<String, dynamic>> getMapList(String key) {
    final String? raw = getString(key);
    if (raw == null || raw.isEmpty) return <Map<String, dynamic>>[];
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is List) return J.asMapList(decoded);
    } catch (_) {
      // Same reasoning as getMap.
    }
    return <Map<String, dynamic>>[];
  }

  /// Removes only SaveWise's keys, never anything else the device stores.
  Future<void> wipe() async {
    final SharedPreferences? prefs = _prefs;
    if (prefs == null) return;
    final Set<String> keys = prefs.getKeys();
    for (final String key in keys) {
      if (key.startsWith(namespace)) {
        await prefs.remove(key);
      }
    }
  }
}
