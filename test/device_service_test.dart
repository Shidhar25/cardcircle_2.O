import 'package:flutter_test/flutter_test.dart';
import 'package:cardcircle/core/services/device_service.dart';

/// These read real platform plugins (`device_info_plus`,
/// `package_info_plus`), which have no response mocked under
/// `flutter_test` — every call here hits an unimplemented method channel.
/// The point is exactly that: both methods must degrade to a placeholder
/// string rather than let a plugin exception escape into the OTP-verify
/// and push-registration calls that now depend on them.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('appVersion degrades to a placeholder rather than throwing', () async {
    final v = await DeviceService.appVersion();
    expect(v, isNotEmpty);
  });

  test('osVersion degrades to a placeholder rather than throwing', () async {
    final v = await DeviceService.osVersion();
    expect(v, isNotEmpty);
  });

  test('deviceId is generated and persisted with no platform plugin at all', () async {
    final v = await DeviceService.deviceId();
    expect(v, isNotEmpty);
    expect(v, startsWith('dev_'));
  });
}
