import 'package:flutter_test/flutter_test.dart';
import 'package:cardcircle/shared/models/otp_send_result.dart';

/// These are the real payloads the backend returns, captured from
/// `POST /api/v1/otp/send`. The throttled case is the one that mattered:
/// it reports `success: false` while still handing back a usable requestId,
/// and reading it as a plain failure is what stranded people who left the
/// OTP screen and pressed Continue again.
void main() {
  group('a freshly sent code', () {
    final result = OtpSendResult.fromResponse(const {
      'success': true,
      'message': 'OTP sent successfully',
      'data': {
        'requestId': '9a24ae08-0e9e-4c05-9bec-353684ae2c8d',
        'expiresIn': 300,
        'phoneNumber': '*********0123',
        'retryAfter': null,
      },
    }, httpOk: true);

    test('can proceed to verification', () {
      expect(result.canProceed, isTrue);
      expect(result.requestId, '9a24ae08-0e9e-4c05-9bec-353684ae2c8d');
    });

    test('is not throttled', () {
      expect(result.sentNow, isTrue);
      expect(result.isThrottled, isFalse);
    });

    test('carries the expiry and a null cooldown', () {
      expect(result.expiresIn, 300);
      expect(result.retryAfter, isNull);
    });
  });

  group('a throttled send', () {
    final result = OtpSendResult.fromResponse(const {
      'success': false,
      'message': 'Please wait 56 seconds before requesting a new OTP',
      'data': {
        'requestId': '9a24ae08-0e9e-4c05-9bec-353684ae2c8d',
        'retryAfter': 56,
      },
    }, httpOk: true);

    test('still proceeds — the existing code is valid', () {
      expect(result.canProceed, isTrue);
      expect(result.requestId, '9a24ae08-0e9e-4c05-9bec-353684ae2c8d');
    });

    test('is reported as throttled, not as a new send', () {
      expect(result.sentNow, isFalse);
      expect(result.isThrottled, isTrue);
    });

    test('exposes the real remaining cooldown for the countdown', () {
      expect(result.retryAfter, 56);
    });

    test("keeps the server's wording for the user", () {
      expect(result.message, contains('56 seconds'));
    });
  });

  group('genuine failures', () {
    test('a refusal with no requestId cannot proceed', () {
      final result = OtpSendResult.fromResponse(const {
        'success': false,
        'message': 'Invalid phone number',
        'data': null,
      }, httpOk: false);
      expect(result.canProceed, isFalse);
      expect(result.isThrottled, isFalse);
      expect(result.message, 'Invalid phone number');
    });

    test('an empty requestId is treated as absent', () {
      final result = OtpSendResult.fromResponse(const {
        'success': true,
        'data': {'requestId': ''},
      }, httpOk: true);
      expect(result.canProceed, isFalse);
    });

    test('a network error carries a message and cannot proceed', () {
      const result = OtpSendResult.failed('Could not reach the server.');
      expect(result.canProceed, isFalse);
      expect(result.message, 'Could not reach the server.');
    });

    test('a 200 body with success false is not treated as sent', () {
      final result = OtpSendResult.fromResponse(const {
        'success': false,
        'data': {'requestId': 'abc'},
      }, httpOk: true);
      expect(result.sentNow, isFalse);
    });
  });

  test('numeric fields survive being sent as strings', () {
    final result = OtpSendResult.fromResponse(const {
      'success': false,
      'data': {'requestId': 'abc', 'retryAfter': '42', 'expiresIn': '300'},
    }, httpOk: true);
    expect(result.retryAfter, 42);
    expect(result.expiresIn, 300);
  });
}
