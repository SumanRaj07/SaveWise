/// Tolerant JSON readers.
///
/// Everything persists to the device as JSON, and a half-written record from an
/// old build should degrade to a sensible default rather than crash the app on
/// launch. Every model decodes through these.
abstract final class J {
  static double asDouble(Object? v, [double fallback = 0]) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? fallback;
    return fallback;
  }

  static int asInt(Object? v, [int fallback = 0]) {
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? fallback;
    return fallback;
  }

  /// Integer within bounds. Avoids `num.clamp` returning `num` at the call site.
  static int asIntClamped(Object? v, int min, int max, [int fallback = 0]) {
    final int raw = asInt(v, fallback);
    if (raw < min) return min;
    if (raw > max) return max;
    return raw;
  }

  /// Double within bounds, same reasoning.
  static double asDoubleClamped(Object? v, double min, double max,
      [double fallback = 0]) {
    final double raw = asDouble(v, fallback);
    if (raw < min) return min;
    if (raw > max) return max;
    return raw;
  }

  static String asString(Object? v, [String fallback = '']) {
    if (v is String) return v;
    if (v == null) return fallback;
    return v.toString();
  }

  static bool asBool(Object? v, [bool fallback = false]) {
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) return v.toLowerCase() == 'true';
    return fallback;
  }

  static DateTime asDate(Object? v, [DateTime? fallback]) {
    if (v is String) {
      final DateTime? parsed = DateTime.tryParse(v);
      if (parsed != null) return parsed;
    }
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    return fallback ?? DateTime.now();
  }

  static DateTime? asDateOrNull(Object? v) {
    if (v is String) return DateTime.tryParse(v);
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    return null;
  }

  static List<int> asIntList(Object? v) {
    if (v is List) {
      return v.map<int>((Object? e) => asInt(e)).toList();
    }
    return <int>[];
  }

  static List<String> asStringList(Object? v) {
    if (v is List) {
      return v.map<String>((Object? e) => asString(e)).toList();
    }
    return <String>[];
  }

  static Map<String, double> asDoubleMap(Object? v) {
    final Map<String, double> out = <String, double>{};
    if (v is Map) {
      v.forEach((Object? key, Object? value) {
        out[asString(key)] = asDouble(value);
      });
    }
    return out;
  }

  static Map<String, dynamic> asMap(Object? v) {
    if (v is Map) {
      return v.map<String, dynamic>(
          (Object? k, Object? val) => MapEntry<String, dynamic>(asString(k), val));
    }
    return <String, dynamic>{};
  }

  static List<Map<String, dynamic>> asMapList(Object? v) {
    if (v is List) {
      return v
          .whereType<Object>()
          .map<Map<String, dynamic>>(asMap)
          .toList();
    }
    return <Map<String, dynamic>>[];
  }

  /// Enum decoding by name, with a guaranteed fallback.
  static T asEnum<T extends Enum>(Object? v, List<T> values, T fallback) {
    final String name = asString(v);
    for (final T e in values) {
      if (e.name == name) return e;
    }
    return fallback;
  }
}
