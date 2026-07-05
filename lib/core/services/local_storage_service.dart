import 'package:shared_preferences/shared_preferences.dart';
import 'logger_service.dart';

class LocalStorageService {
  static SharedPreferences? _prefs;

  static Future<void> init() async {
    if (_prefs != null) return;
    try {
      _prefs = await SharedPreferences.getInstance();
      LoggerService.info('LocalStorageService initialized successfully.');
    } catch (e, stack) {
      LoggerService.error('Failed to initialize SharedPreferences', e, stack);
    }
  }

  static Future<bool> setBool(String key, bool value) async {
    if (_prefs == null) await init();
    LoggerService.debug('Saving bool: $key = $value');
    return _prefs?.setBool(key, value) ?? Future.value(false);
  }

  static bool getBool(String key, {bool defaultValue = false}) {
    final val = _prefs?.getBool(key);
    LoggerService.debug('Reading bool: $key = $val (default: $defaultValue)');
    return val ?? defaultValue;
  }

  static Future<bool> setString(String key, String value) async {
    if (_prefs == null) await init();
    LoggerService.debug('Saving string: $key = $value');
    return _prefs?.setString(key, value) ?? Future.value(false);
  }

  static String? getString(String key) {
    final val = _prefs?.getString(key);
    LoggerService.debug('Reading string: $key = $val');
    return val;
  }

  static Future<bool> remove(String key) async {
    if (_prefs == null) await init();
    LoggerService.debug('Removing key: $key');
    return _prefs?.remove(key) ?? Future.value(false);
  }
}
