import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

import 'local_storage_service.dart';
import 'logger_service.dart';

/// Stable identity for this installation, used by contact sync and push
/// registration.
///
/// The id is generated once and persisted, rather than derived from a
/// hardware identifier: Android/iOS both restrict those, and a value that
/// changes on reinstall is fine here because the server treats a new device
/// id as a fresh sync source.
class DeviceService {
  static const String _idKey = '@cardcircle/deviceId';

  static String? _cachedId;
  static String? _cachedName;

  /// Persistent per-install id.
  static Future<String> deviceId() async {
    final cached = _cachedId;
    if (cached != null) return cached;

    final stored = LocalStorageService.getString(_idKey);
    if (stored != null && stored.isNotEmpty) {
      _cachedId = stored;
      return stored;
    }

    // Time + hash of it is enough: this only needs to be unique per install,
    // not guessable or globally coordinated.
    final seed = DateTime.now().microsecondsSinceEpoch;
    final generated = 'dev_${seed.toRadixString(16)}_${seed.hashCode.abs()}';
    await LocalStorageService.setString(_idKey, generated);
    _cachedId = generated;
    return generated;
  }

  /// Human-readable model name for the device list in account settings.
  static Future<String> deviceName() async {
    final cached = _cachedName;
    if (cached != null) return cached;

    var name = 'Unknown device';
    try {
      final plugin = DeviceInfoPlugin();
      if (defaultTargetPlatform == TargetPlatform.android) {
        final info = await plugin.androidInfo;
        name = '${info.manufacturer} ${info.model}'.trim();
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        final info = await plugin.iosInfo;
        name = info.utsname.machine;
      }
    } catch (e, stack) {
      LoggerService.error('Could not read device info', e, stack);
    }

    _cachedName = name;
    return name;
  }

  static String get platformLabel =>
      defaultTargetPlatform == TargetPlatform.iOS ? 'IOS' : 'ANDROID';
}
