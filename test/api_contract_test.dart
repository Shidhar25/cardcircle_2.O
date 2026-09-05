import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:cardcircle/core/services/api_result.dart';
import 'package:cardcircle/core/services/otp_session.dart';
import 'package:cardcircle/features/circle/state/circle_state.dart';
import 'package:cardcircle/shared/models/contact_action.dart';
import 'package:cardcircle/shared/models/otp_send_result.dart';

http.Response _res(Object? body, int status) =>
    http.Response(body == null ? '' : jsonEncode(body), status);

/// These cases are transcribed from the documented API contract, so the
/// parsing is checked against what the backend actually sends rather than
/// against what the client happens to expect.
void main() {
  group('error envelopes', () {
    test('asyncHandler shape: {success, status, message}', () {
      final r = ApiResult.fromResponse(
        _res({
          'success': false,
          'status': 400,
          'message': 'Cannot send follow request to yourself',
        }, 400),
        action: 'Follow',
      );
      expect(r.ok, isFalse);
      expect(r.message, 'Cannot send follow request to yourself');
      expect(r.statusCode, 400);
    });

    test('try/catch shape: {success, message, code}', () {
      final r = ApiResult.fromResponse(
        _res({
          'success': false,
          'message':
              'Username is already taken. Please choose another '
              'username.',
          'code': 'USERNAME_EXISTS',
        }, 409),
        action: 'Create profile',
      );
      expect(r.code, 'USERNAME_EXISTS');
      expect(r.message, startsWith('Username is already taken'));
    });

    test('a code nested in data is found too (OTP MAX_ATTEMPTS)', () {
      final r = ApiResult.fromResponse(
        _res({
          'success': false,
          'message': 'Too many attempts',
          'data': {'code': 'MAX_ATTEMPTS', 'remainingAttempts': 0},
        }, 429),
        action: 'Verify OTP',
      );
      expect(r.code, 'MAX_ATTEMPTS');
      expect(r.data?['remainingAttempts'], 0);
    });

    test('a wrong code reports how many tries remain', () {
      final r = ApiResult.fromResponse(
        _res({
          'success': false,
          'message': 'Invalid OTP',
          'data': {'remainingAttempts': 2},
        }, 400),
        action: 'Verify OTP',
      );
      expect(r.ok, isFalse);
      expect(r.data?['remainingAttempts'], 2);
    });
  });

  group('success envelopes', () {
    test('201 with success:true is ok', () {
      final r = ApiResult.fromResponse(
        _res({
          'success': true,
          'message': '1 card(s) added successfully',
          'data': {'user_card_id': 'abc'},
        }, 201),
        action: 'Add cards',
      );
      expect(r.ok, isTrue);
      expect(r.display('fallback'), '1 card(s) added successfully');
    });

    test('an empty 204 body is a success, not a parse failure', () {
      final r = ApiResult.fromResponse(_res(null, 204), action: 'Delete');
      expect(r.ok, isTrue);
    });

    test('a non-JSON body (proxy error page) does not throw', () {
      final r = ApiResult.fromResponse(
        http.Response('<html>502 Bad Gateway</html>', 502),
        action: 'Anything',
      );
      expect(r.ok, isFalse);
      expect(r.display('fallback'), isNotEmpty);
    });

    test('HTTP 200 with success:false is still a failure', () {
      // /push/send returns exactly this on a partial delivery failure.
      final r = ApiResult.fromResponse(
        _res({'success': false, 'message': 'No active devices'}, 200),
        action: 'Push',
      );
      expect(r.ok, isFalse);
    });
  });

  group('follow relationship status', () {
    // The follow endpoints report the record's status (PENDING/APPROVED/…),
    // which is a different vocabulary from the directory's `action`.
    test('a new request lands on PENDING -> Requested', () {
      expect(
        CircleState.resolveAction('PENDING', wasFollowing: false),
        ContactAction.requestSent,
      );
    });

    test('APPROVED -> Following', () {
      expect(
        CircleState.resolveAction('APPROVED', wasFollowing: false),
        ContactAction.following,
      );
    });

    test('unfollow returns CANCELLED -> you may request again', () {
      expect(
        CircleState.resolveAction('CANCELLED', wasFollowing: true),
        ContactAction.follow,
      );
    });

    test('REJECTED -> you may request again', () {
      expect(
        CircleState.resolveAction('REJECTED', wasFollowing: false),
        ContactAction.follow,
      );
    });

    test('BLOCKED is preserved, not flattened into follow', () {
      expect(
        CircleState.resolveAction('BLOCKED', wasFollowing: false),
        ContactAction.blocked,
      );
    });
  });

  group('throttled OTP send', () {
    test('a throttled send carries no requestId, so it cannot proceed', () {
      // The documented 429: requestId is null, only retryAfter is useful.
      final r = OtpSendResult.fromResponse(const {
        'success': false,
        'message': 'Please wait 56 seconds before requesting a new OTP',
        'data': {
          'requestId': null,
          'expiresIn': null,
          'phoneNumber': '*********0001',
          'retryAfter': 56,
        },
      }, httpOk: false);

      expect(r.canProceed, isFalse);
      expect(r.retryAfter, 56);
      expect(r.sentNow, isFalse);
    });

    test('a fresh send carries the id and lifetime', () {
      final r = OtpSendResult.fromResponse(const {
        'success': true,
        'message': 'OTP sent successfully',
        'data': {
          'requestId': 'feb9e4f6-9519-42ee-873d-73672d7f0698',
          'expiresIn': 300,
          'retryAfter': null,
        },
      }, httpOk: true);

      expect(r.canProceed, isTrue);
      expect(r.expiresIn, 300);
      expect(r.sentNow, isTrue);
    });
  });

  group('the outstanding OTP request is remembered across screens', () {
    setUp(OtpSession.clear);

    test('the id survives leaving and returning to the login screen', () {
      // This is the reported bug: press Continue, go back, press Continue
      // again. The server refuses the second send and returns no id, so the
      // flow only works if the first id was kept.
      OtpSession.remember(
        phone: '+919000010001',
        requestId: 'req-1',
        expiresInSeconds: 300,
      );
      expect(OtpSession.idFor('+919000010001'), 'req-1');
    });

    test('it is not reused for a different number', () {
      OtpSession.remember(phone: '+919000010001', requestId: 'req-1');
      expect(OtpSession.idFor('+919000010002'), isNull);
    });

    test('an expired code is dropped rather than reused', () {
      OtpSession.rememberForTest(
        phone: '+919000010001',
        requestId: 'req-1',
        expiresAt: DateTime.now().subtract(const Duration(seconds: 1)),
      );
      expect(OtpSession.idFor('+919000010001'), isNull);
    });

    test('a resend replaces the id, so login cannot hold a stale one', () {
      OtpSession.remember(phone: '+919000010001', requestId: 'req-1');
      OtpSession.remember(phone: '+919000010001', requestId: 'req-2');
      expect(OtpSession.idFor('+919000010001'), 'req-2');
    });

    test('verifying clears it, so the next login sends a fresh code', () {
      OtpSession.remember(phone: '+919000010001', requestId: 'req-1');
      OtpSession.clear();
      expect(OtpSession.idFor('+919000010001'), isNull);
    });
  });

  group('inviting a contact', () {
    // The server sends nothing itself: it returns a wa.me deep link the
    // user sends from WhatsApp, and enforces a per-contact cooldown.
    test('a successful invite carries the link to open', () {
      final r = ApiResult.fromResponse(
        _res({
          'success': true,
          'message': 'Invite link generated',
          'data': {
            'contact_id': 'c1',
            'mobile_number': '+919000010099',
            'whatsapp_url':
                'https://wa.me/919000010099?text=Join%20me%20on%20CardCircle',
            'invite_count': 1,
            'last_invited_at': '2026-09-05T09:00:00.000Z',
          },
        }, 200),
        action: 'Invite contact',
      );

      expect(r.ok, isTrue);
      expect(r.data?['whatsapp_url'], startsWith('https://wa.me/'));
      expect(r.data?['invite_count'], 1);
    });

    test('the cooldown reply explains itself rather than failing blankly', () {
      // 429 with hours remaining. Nothing should open; the user is told
      // why, in the server's own words.
      final r = ApiResult.fromResponse(
        _res({
          'success': false,
          'message': 'Already invited. Try again in 23 hours.',
        }, 429),
        action: 'Invite contact',
      );

      expect(r.ok, isFalse);
      expect(r.statusCode, 429);
      expect(r.display('fallback'), contains('23 hours'));
      expect(r.data?['whatsapp_url'], isNull);
    });

    test('inviting someone already registered is refused', () {
      final r = ApiResult.fromResponse(
        _res({
          'success': false,
          'status': 400,
          'message': 'Contact is already a CardCircle user',
        }, 400),
        action: 'Invite contact',
      );
      expect(r.ok, isFalse);
      expect(r.display('fallback'), contains('already a CardCircle user'));
    });

    test('an unknown contact is a 404, not a crash', () {
      final r = ApiResult.fromResponse(
        _res({
          'success': false,
          'status': 404,
          'message': 'Contact not found',
        }, 404),
        action: 'Invite contact',
      );
      expect(r.ok, isFalse);
      expect(r.statusCode, 404);
    });

    test('a success with no link is treated as unusable by the caller', () {
      // The screen guards on this: ok but nothing to open.
      final r = ApiResult.fromResponse(
        _res({
          'success': true,
          'data': {'contact_id': 'c1'},
        }, 200),
        action: 'Invite contact',
      );
      expect(r.ok, isTrue);
      expect((r.data?['whatsapp_url'] ?? '').toString(), isEmpty);
    });
  });
}
