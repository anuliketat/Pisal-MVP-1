import 'package:shared_preferences/shared_preferences.dart';

/// User-tunable settings (privacy, sync window, optional parse backend).
class AppConfig {
  AppConfig(this._prefs);

  final SharedPreferences _prefs;

  static const keySyncMonths = 'sync_window_months';
  static const keyAllowCloudParse = 'allow_cloud_parse';
  static const keyParseBackendUrl = 'parse_backend_url';
  static const keyOnboardingDone = 'onboarding_done';

  int get syncWindowMonths => _prefs.getInt(keySyncMonths) ?? 12;

  Future<void> setSyncWindowMonths(int m) =>
      _prefs.setInt(keySyncMonths, m.clamp(3, 1200));

  bool get allowCloudParse => _prefs.getBool(keyAllowCloudParse) ?? false;

  Future<void> setAllowCloudParse(bool v) =>
      _prefs.setBool(keyAllowCloudParse, v);

  /// Base URL without trailing slash, e.g. http://10.0.2.2:8787
  String? get parseBackendUrl => _prefs.getString(keyParseBackendUrl);

  Future<void> setParseBackendUrl(String? url) async {
    if (url == null || url.isEmpty) {
      await _prefs.remove(keyParseBackendUrl);
    } else {
      await _prefs.setString(keyParseBackendUrl, url);
    }
  }

  bool get onboardingDone => _prefs.getBool(keyOnboardingDone) ?? false;

  Future<void> setOnboardingDone(bool v) =>
      _prefs.setBool(keyOnboardingDone, v);
}
