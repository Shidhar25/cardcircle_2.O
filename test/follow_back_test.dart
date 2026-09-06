import 'package:flutter_test/flutter_test.dart';
import 'package:cardcircle/features/circle/state/circle_state.dart';

/// `follow_back_status` decides whether the app offers to reciprocate.
/// Getting it wrong either nags someone who already followed back, or
/// silently drops the offer for someone who has not — so each value is
/// pinned.
void main() {
  group('followsBack', () {
    CircleState stateWith(List<Map<String, dynamic>> followers) {
      final state = CircleState();
      state.setFollowersForTest(followers);
      return state;
    }

    test('null means the offer is still open', () {
      final state = stateWith([
        {'user_id': 'u1', 'follow_back_status': null},
      ]);
      expect(state.followsBack('u1'), isFalse);
    });

    test('PENDING means already asked — do not ask again', () {
      // The request is sitting with them; re-asking would send a duplicate
      // the server rejects.
      final state = stateWith([
        {'user_id': 'u1', 'follow_back_status': 'PENDING'},
      ]);
      expect(state.followsBack('u1'), isTrue);
    });

    test('APPROVED means it is already mutual', () {
      final state = stateWith([
        {'user_id': 'u1', 'follow_back_status': 'APPROVED'},
      ]);
      expect(state.followsBack('u1'), isTrue);
    });

    test('an empty string is treated as no relationship', () {
      // Defensive: an empty status is not a real state, and treating it as
      // "already handled" would silently drop the offer.
      final state = stateWith([
        {'user_id': 'u1', 'follow_back_status': ''},
      ]);
      expect(state.followsBack('u1'), isFalse);
    });

    test('someone absent from the followers list is not offered', () {
      // They do not follow you, so there is nothing to reciprocate.
      final state = stateWith([
        {'user_id': 'someone-else', 'follow_back_status': null},
      ]);
      expect(state.followsBack('u1'), isTrue);
    });

    test('an empty followers list offers nothing', () {
      expect(stateWith(const []).followsBack('u1'), isTrue);
    });

    test('the right follower is matched among several', () {
      final state = stateWith([
        {'user_id': 'a', 'follow_back_status': 'APPROVED'},
        {'user_id': 'b', 'follow_back_status': null},
        {'user_id': 'c', 'follow_back_status': 'PENDING'},
      ]);
      expect(state.followsBack('a'), isTrue);
      expect(state.followsBack('b'), isFalse);
      expect(state.followsBack('c'), isTrue);
    });
  });
}
