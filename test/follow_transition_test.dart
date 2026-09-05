import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cardcircle/core/services/api_result.dart';
import 'package:cardcircle/features/circle/state/circle_state.dart';
import 'package:cardcircle/shared/models/contact_action.dart';
import 'package:cardcircle/shared/models/friend.dart';

Friend _friend(ContactAction action) => Friend(
  id: 'u1',
  name: 'Riya',
  username: '@riya',
  initials: 'R',
  cardsCount: 0,
  level: '',
  action: action,
  commonCards: const [],
  gradientColors: const [Colors.black, Colors.white],
);

void main() {
  group('the state a follow lands in', () {
    test('following someone creates a pending request, not a follow', () {
      // POST /follow/requests/… creates a *request*. Reporting it as
      // "Following" would claim access to their cards that has not been
      // granted.
      expect(
        CircleState.resolveAction(null, wasFollowing: false),
        ContactAction.requestSent,
      );
    });

    test('unfollowing returns you to being able to request again', () {
      expect(
        CircleState.resolveAction(null, wasFollowing: true),
        ContactAction.follow,
      );
    });

    test("the server's own status wins over the assumption", () {
      // An account that auto-approves goes straight to following.
      expect(
        CircleState.resolveAction('following', wasFollowing: false),
        ContactAction.following,
      );
      expect(
        CircleState.resolveAction('blocked', wasFollowing: false),
        ContactAction.blocked,
      );
    });

    test('an unrecognised status falls back rather than becoming follow', () {
      // ContactAction.parse degrades unknown values to `follow`; trusting
      // that here would silently show a Follow button right after a
      // successful follow — the original bug.
      expect(
        CircleState.resolveAction('some_future_state', wasFollowing: false),
        ContactAction.requestSent,
      );
    });

    test('an explicit "follow" status is still honoured', () {
      expect(
        CircleState.resolveAction('follow', wasFollowing: true),
        ContactAction.follow,
      );
    });
  });

  group('the row visibly changes after a follow', () {
    test('the pill label changes', () {
      final before = _friend(ContactAction.follow);
      final after = before.withAction(ContactAction.requestSent);
      expect(before.action.label, 'Follow');
      expect(after.action.label, 'Requested');
    });

    test('it leaves Suggested only once the follow is approved', () {
      // A sent request stays in Suggested — the relationship is still in
      // progress — but an approved follow moves to the Following tab.
      expect(ContactAction.requestSent.belongsInSuggested, isTrue);
      expect(ContactAction.following.belongsInSuggested, isFalse);
    });

    test('a pending request is not reported as following', () {
      expect(_friend(ContactAction.requestSent).isFollowing, isFalse);
      expect(_friend(ContactAction.following).isFollowing, isTrue);
    });

    test('withAction preserves everything except the relationship', () {
      final before = _friend(ContactAction.follow);
      final after = before.withAction(ContactAction.following);
      expect(after.id, before.id);
      expect(after.name, before.name);
      expect(after.initials, before.initials);
      expect(after.commonCards, before.commonCards);
    });
  });

  group('backend messages reach the user', () {
    test("the server's wording is preferred over the app's fallback", () {
      const result = ApiResult<Map<String, dynamic>>(
        ok: false,
        message: 'You already follow this user',
      );
      expect(
        result.display('Could not follow.'),
        'You already follow this user',
      );
    });

    test('the fallback is used when the server said nothing', () {
      const result = ApiResult<Map<String, dynamic>>(ok: false);
      expect(result.display('Could not follow.'), 'Could not follow.');
      expect(
        const ApiResult<Map<String, dynamic>>(
          ok: false,
          message: '   ',
        ).display('Could not follow.'),
        'Could not follow.',
      );
    });

    test('an expired session is distinguishable from a plain failure', () {
      const expired = ApiResult<Map<String, dynamic>>(
        ok: false,
        statusCode: 401,
      );
      const failed = ApiResult<Map<String, dynamic>>(
        ok: false,
        statusCode: 500,
      );
      expect(expired.isUnauthorised, isTrue);
      expect(failed.isUnauthorised, isFalse);
    });
  });
}
