import 'package:flutter_test/flutter_test.dart';
import 'package:cardcircle/core/services/contacts_service.dart';

/// Phone normalisation is the hinge of the whole invite/backfill flow: a
/// contact only matches an account if the number sent during sync is byte
/// identical to the one that account signed up with. An address book stores
/// the same number a dozen ways, so these cases are the ones that decide
/// whether Bob is findable after he signs up.
void main() {
  String? n(String raw) => ContactsService.normalisePhone(raw);

  group('normalisePhone', () {
    test('keeps an already-normalised number', () {
      expect(n('+919665389975'), '+919665389975');
    });

    test('adds the default country code to a bare 10-digit number', () {
      expect(n('9665389975'), '+919665389975');
    });

    test('strips formatting a phone book adds', () {
      expect(n('+91 96653 89975'), '+919665389975');
      expect(n('(096) 6538-9975'), '+919665389975');
      expect(n('+91-96653-89975'), '+919665389975');
    });

    test('drops the domestic trunk prefix', () {
      expect(n('09665389975'), '+919665389975');
    });

    test('converts the 00 international prefix to +', () {
      expect(n('00919665389975'), '+919665389975');
    });

    test('does not double the country code when already present', () {
      expect(n('919665389975'), '+919665389975');
    });

    test('every spelling of one number collapses to the same string', () {
      const forms = [
        '+919665389975',
        '9665389975',
        '09665389975',
        '00919665389975',
        '919665389975',
        '+91 96653 89975',
      ];
      expect(forms.map(n).toSet(), {'+919665389975'});
    });

    test('rejects junk rather than sending it', () {
      expect(n(''), isNull);
      expect(n('   '), isNull);
      expect(n('12'), isNull);
      expect(n('abc'), isNull);
      expect(n('+1234567890123456789'), isNull);
    });

    test('leaves other countries intact', () {
      expect(n('+14155552671'), '+14155552671');
      expect(n('+442071838750'), '+442071838750');
    });
  });
}
