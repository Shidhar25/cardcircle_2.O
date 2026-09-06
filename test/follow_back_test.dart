import 'package:flutter_test/flutter_test.dart';
import 'package:cardcircle/shared/models/follow_back_status.dart';

/// `follow_back_status` decides whether the Followers list offers a
/// reciprocal follow. Getting it wrong either nags someone who has already
/// followed back, or silently drops the offer for someone who has not — so
/// each value is pinned.
void main() {
  group('parsing the server value', () {
    test('null means the offer is still open', () {
      expect(FollowBackStatus.parse(null), FollowBackStatus.open);
      expect(FollowBackStatus.parse(null).canFollowBack, isTrue);
    });

    test('PENDING means the request already sits with them', () {
      // Offering again would send a duplicate the server rejects.
      expect(FollowBackStatus.parse('PENDING'), FollowBackStatus.requested);
      expect(FollowBackStatus.parse('PENDING').canFollowBack, isFalse);
    });

    test('APPROVED means it is already mutual', () {
      expect(FollowBackStatus.parse('APPROVED'), FollowBackStatus.mutual);
      expect(FollowBackStatus.parse('APPROVED').canFollowBack, isFalse);
    });

    test('case and surrounding space do not matter', () {
      expect(FollowBackStatus.parse('  pending '), FollowBackStatus.requested);
      expect(FollowBackStatus.parse('Approved'), FollowBackStatus.mutual);
    });
  });

  group('values that are not real states', () {
    test('an empty string is treated as no relationship', () {
      // Reading it as "already handled" would drop the offer invisibly,
      // which is the worse failure.
      expect(FollowBackStatus.parse(''), FollowBackStatus.open);
      expect(FollowBackStatus.parse('   '), FollowBackStatus.open);
    });

    test('an unknown status stays quiet rather than offering', () {
      // The server knows about a relationship this build does not; a
      // follow offered here would only be rejected.
      expect(FollowBackStatus.parse('BLOCKED').canFollowBack, isFalse);
      expect(FollowBackStatus.parse('REJECTED').canFollowBack, isFalse);
      expect(FollowBackStatus.parse('SOMETHING_NEW').canFollowBack, isFalse);
    });

    test('a non-string value does not throw', () {
      expect(FollowBackStatus.parse(42).canFollowBack, isFalse);
      expect(FollowBackStatus.parse(true).canFollowBack, isFalse);
    });
  });
}
