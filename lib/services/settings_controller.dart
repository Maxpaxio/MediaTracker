import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'region.dart';

/// Holds simple app settings (currently: region override).
class SettingsController extends ChangeNotifier {
  static const _kRegionOverrideKey = 'settings.regionOverride';
  static const _kCachedGeoRegionKey = 'settings.cachedGeoRegion';
  static const _kCachedGeoTimestampKey = 'settings.cachedGeoTimestamp';
  static const _kGeoTtl = Duration(days: 3); // refresh every few days

  SharedPreferences? _prefs;
  String? _regionOverride; // Explicit user choice (e.g. 'US')
  String? _cachedGeoRegion; // From IP geolocation

  String? get regionOverride => _regionOverride;

  /// Effective region priority:
  /// 1. User override
  /// 2. Cached IP geolocation (if fresh)
  /// 3. On-demand locale detection
  String? get effectiveRegion =>
      _regionOverride ?? _cachedGeoRegion ?? tryDetectRegionCode();

  bool get hasExplicitOverride => _regionOverride != null;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _regionOverride = _prefs!.getString(_kRegionOverrideKey);
    _cachedGeoRegion = _prefs!.getString(_kCachedGeoRegionKey);
    final tsMillis = _prefs!.getInt(_kCachedGeoTimestampKey);
    if (tsMillis != null) {
      final ts = DateTime.fromMillisecondsSinceEpoch(tsMillis);
      if (DateTime.now().difference(ts) > _kGeoTtl) {
        _cachedGeoRegion = null; // stale
      }
    }
    // Kick off refresh (non-blocking)
    _refreshGeoRegion();
    notifyListeners();
  }

  Future<void> setRegionOverride(String? code) async {
    _regionOverride = code?.trim().isEmpty ?? true ? null : code!.toUpperCase();
    if (_prefs == null) _prefs = await SharedPreferences.getInstance();
    if (_regionOverride == null) {
      await _prefs!.remove(_kRegionOverrideKey);
    } else {
      await _prefs!.setString(_kRegionOverrideKey, _regionOverride!);
    }
    notifyListeners();
  }

  /// Fetch IP-based geolocation country code (simple, unauthenticated public API).
  Future<void> _refreshGeoRegion() async {
    if (_regionOverride != null)
      return; // User override takes precedence; skip network.
    try {
      // If we already have a fresh cached value, skip.
      if (_cachedGeoRegion != null) return;
      // Use ipapi.co (no key required for basic fields). Alternative: https://ipwho.is/
      final uri = Uri.parse('https://ipapi.co/json/');
      final resp = await http.get(uri).timeout(const Duration(seconds: 4));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final cc = (data['country_code'] as String?)?.trim();
        if (cc != null && cc.length == 2) {
          _cachedGeoRegion = cc.toUpperCase();
          if (_prefs == null) _prefs = await SharedPreferences.getInstance();
          await _prefs!.setString(_kCachedGeoRegionKey, _cachedGeoRegion!);
          await _prefs!.setInt(
              _kCachedGeoTimestampKey, DateTime.now().millisecondsSinceEpoch);
          notifyListeners();
        }
      }
    } catch (_) {
      // Silent failure; we just fall back to locale detection.
    }
  }
}

class SettingsScope extends InheritedNotifier<SettingsController> {
  const SettingsScope(
      {Key? key, required SettingsController controller, required Widget child})
      : super(key: key, notifier: controller, child: child);

  static SettingsController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SettingsScope>()!.notifier!;
}
