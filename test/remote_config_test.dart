import 'package:flutter_test/flutter_test.dart';
import 'package:cardcircle/core/config/remote_config.dart';

/// The whole point of this layer is that a bad server payload must never be
/// worse than shipping no payload at all. Every case here is a way the
/// backend could send something unexpected; in all of them the app has to
/// keep rendering.
void main() {
  setUp(() {
    // A fresh singleton per test: apply({}) clears any overrides a previous
    // test left behind, without touching disk.
    RemoteConfig.instance.applyForTest(const {});
  });

  group('defaults', () {
    test('every key resolves before any payload arrives', () {
      expect(config.flag('auth.termsRequired'), isTrue);
      expect(config.number('defaultSettings.otpLength'), 6);
      expect(config.text('discover.title'), 'Benefits');
      expect(config.strings('discover.tabLabels'), [
        'MY BENEFITS',
        'CIRCLE BENEFITS',
      ]);
    });

    test('an unknown key falls back to the caller-supplied value', () {
      expect(config.flag('not.a.real.key', fallback: true), isTrue);
      expect(config.text('not.a.real.key', fallback: 'x'), 'x');
      expect(config.number('not.a.real.key', fallback: 7), 7);
      expect(config.strings('not.a.real.key', fallback: const ['a']), ['a']);
    });
  });

  group('overrides', () {
    test('a flat payload overrides the default', () {
      RemoteConfig.instance.applyForTest(const {'auth.termsRequired': false});
      expect(config.flag('auth.termsRequired'), isFalse);
    });

    test('a nested payload resolves to the same dotted keys', () {
      RemoteConfig.instance.applyForTest(const {
        'defaultSettings': {'otpLength': 4, 'otpExpirySeconds': 30},
      });
      expect(config.number('defaultSettings.otpLength'), 4);
      expect(config.number('defaultSettings.otpExpirySeconds'), 30);
    });

    test('keys the payload omits keep their defaults', () {
      RemoteConfig.instance.applyForTest(const {'discover.title': 'Perks'});
      expect(config.text('discover.title'), 'Perks');
      expect(config.text('discover.searchHint'), contains('benefits'));
    });
  });

  group('malformed values degrade instead of breaking a build', () {
    test('a stringified boolean is still read as a boolean', () {
      RemoteConfig.instance.applyForTest(const {'auth.termsRequired': 'false'});
      expect(config.flag('auth.termsRequired'), isFalse);
    });

    test('a wrong-typed flag falls back rather than throwing', () {
      RemoteConfig.instance.applyForTest(const {'auth.termsRequired': 42});
      expect(config.flag('auth.termsRequired', fallback: true), isTrue);
    });

    test('blank copy does not blank the screen', () {
      RemoteConfig.instance.applyForTest(const {'discover.title': '   '});
      expect(config.text('discover.title'), 'Benefits');
    });

    test('an empty list keeps the default, so tab indexing stays valid', () {
      RemoteConfig.instance.applyForTest(const {'discover.tabLabels': []});
      expect(config.strings('discover.tabLabels').length, 2);
    });

    test('non-string entries are dropped from a list', () {
      RemoteConfig.instance.applyForTest(const {
        'discover.tabLabels': ['MINE', 7, null, 'CIRCLE'],
      });
      expect(config.strings('discover.tabLabels'), ['MINE', 'CIRCLE']);
    });

    test('a wrong-typed list falls back to the default', () {
      // A string where a list belongs must not leave the tab bar empty:
      // SegmentedTabs indexes into this.
      RemoteConfig.instance.applyForTest(const {'discover.tabLabels': 'MINE'});
      expect(config.strings('discover.tabLabels').length, 2);
      expect(config.strings('discover.tabLabels').first, 'MY BENEFITS');
    });
  });
}
