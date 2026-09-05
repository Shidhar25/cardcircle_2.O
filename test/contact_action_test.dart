import 'package:flutter_test/flutter_test.dart';
import 'package:cardcircle/shared/models/contact_action.dart';

void main() {
  group('parse', () {
    test('maps every documented action string', () {
      expect(ContactAction.parse('self'), ContactAction.self);
      expect(ContactAction.parse('invite_only'), ContactAction.inviteOnly);
      expect(ContactAction.parse('following'), ContactAction.following);
      expect(ContactAction.parse('request_sent'), ContactAction.requestSent);
      expect(ContactAction.parse('blocked'), ContactAction.blocked);
      expect(
        ContactAction.parse('request_received'),
        ContactAction.requestReceived,
      );
      expect(ContactAction.parse('follow'), ContactAction.follow);
    });

    test('an unknown or missing action degrades to follow, not a crash', () {
      expect(ContactAction.parse(null), ContactAction.follow);
      expect(ContactAction.parse(''), ContactAction.follow);
      expect(ContactAction.parse('some_future_state'), ContactAction.follow);
    });
  });

  group('Suggested tab membership', () {
    test('never shows yourself or anyone who blocked you', () {
      expect(ContactAction.self.belongsInSuggested, isFalse);
      expect(ContactAction.blocked.belongsInSuggested, isFalse);
    });

    test('excludes people already followed and non-users', () {
      expect(ContactAction.following.belongsInSuggested, isFalse);
      expect(ContactAction.inviteOnly.belongsInSuggested, isFalse);
    });

    test('includes states where a relationship can still progress', () {
      expect(ContactAction.follow.belongsInSuggested, isTrue);
      expect(ContactAction.requestSent.belongsInSuggested, isTrue);
      expect(ContactAction.requestReceived.belongsInSuggested, isTrue);
    });
  });

  group('row control', () {
    test('each state gets its own label, not a blanket Follow', () {
      expect(ContactAction.follow.label, 'Follow');
      expect(ContactAction.following.label, 'Following');
      expect(ContactAction.requestSent.label, 'Requested');
      expect(ContactAction.requestReceived.label, 'Respond');
      expect(ContactAction.inviteOnly.label, 'Invite');
    });

    test('self and blocked render no control at all', () {
      expect(ContactAction.self.label, isEmpty);
      expect(ContactAction.blocked.label, isEmpty);
    });

    test('a pending request is a status, not a tappable button', () {
      expect(ContactAction.requestSent.isActionable, isFalse);
      expect(ContactAction.follow.isActionable, isTrue);
    });
  });

  test('isMatchedUser distinguishes accounts from address-book entries', () {
    expect(ContactAction.follow.isMatchedUser, isTrue);
    expect(ContactAction.following.isMatchedUser, isTrue);
    expect(ContactAction.blocked.isMatchedUser, isTrue);
    expect(ContactAction.inviteOnly.isMatchedUser, isFalse);
    expect(ContactAction.self.isMatchedUser, isFalse);
  });

  group('contacts list order', () {
    List<ContactAction> sorted(List<ContactAction> input) =>
        [...input]..sort((a, b) => a.sortPriority.compareTo(b.sortPriority));

    test('actionable states come first, invite-only last', () {
      // A phone book is mostly people who are not on CardCircle. Leaving
      // them interleaved buried the handful of rows worth acting on.
      expect(
        sorted([
          ContactAction.inviteOnly,
          ContactAction.following,
          ContactAction.requestSent,
          ContactAction.follow,
          ContactAction.requestReceived,
        ]),
        [
          ContactAction.follow,
          ContactAction.requestSent,
          ContactAction.requestReceived,
          ContactAction.following,
          ContactAction.inviteOnly,
        ],
      );
    });

    test('follow and requested outrank everything else', () {
      for (final other in [
        ContactAction.requestReceived,
        ContactAction.following,
        ContactAction.inviteOnly,
      ]) {
        expect(
          ContactAction.follow.sortPriority,
          lessThan(other.sortPriority),
          reason: 'follow above ${other.name}',
        );
        expect(
          ContactAction.requestSent.sortPriority,
          lessThan(other.sortPriority),
          reason: 'requested above ${other.name}',
        );
      }
    });

    test('invite-only sinks below every on-platform state', () {
      for (final onPlatform in [
        ContactAction.follow,
        ContactAction.requestSent,
        ContactAction.requestReceived,
        ContactAction.following,
      ]) {
        expect(
          ContactAction.inviteOnly.sortPriority,
          greaterThan(onPlatform.sortPriority),
          reason: 'invite below ${onPlatform.name}',
        );
      }
    });

    test('states that are filtered out cannot float to the top', () {
      // Defence in depth: the screen removes these, but a caller that
      // forgot to must not see them first.
      for (final hidden in [ContactAction.self, ContactAction.blocked]) {
        expect(
          hidden.sortPriority,
          greaterThan(ContactAction.inviteOnly.sortPriority),
          reason: hidden.name,
        );
      }
    });

    test('every state has a distinct position', () {
      final all = ContactAction.values.map((a) => a.sortPriority).toList();
      expect(all.toSet().length, all.length);
    });
  });
}
