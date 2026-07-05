import 'package:flutter/material.dart';
import '../../../core/services/logger_service.dart';
import '../../../shared/models/models.dart';
import '../../auth/state/auth_state.dart';

class ChallengesState extends ChangeNotifier {
  late List<Challenge> _challenges;
  AuthState? _authState;

  ChallengesState() {
    _initData();
  }

  List<Challenge> get challenges => _challenges;

  void updateAuth(AuthState authState) {
    _authState = authState;
  }

  void _initData() {
    _challenges = [
      Challenge(
        id: 'ch1',
        title: 'Save ₹1,000 this month',
        description: 'Earn ₹1,000 in cashback or rewards from any card',
        progress: 750,
        total: 1000,
        rewardPoints: 200,
        daysLeft: 8,
        completed: false,
        claimed: false,
        iconName: 'wallet',
      ),
      Challenge(
        id: 'ch2',
        title: 'Refer 3 Friends',
        description: 'Invite 3 friends to join CardCircle',
        progress: 2,
        total: 3,
        rewardPoints: 150,
        daysLeft: 15,
        completed: false,
        claimed: false,
        iconName: 'people',
      ),
      Challenge(
        id: 'ch3',
        title: 'Share 5 Verified Hacks',
        description: 'Contribute 5 hacks to the community',
        progress: 5,
        total: 5,
        rewardPoints: 500,
        daysLeft: 0,
        completed: true,
        claimed: false,
        iconName: 'flash',
      ),
      Challenge(
        id: 'ch4',
        title: 'Discover 10 Offers',
        description: 'Explore and claim 10 exclusive offers',
        progress: 4,
        total: 10,
        rewardPoints: 100,
        daysLeft: 22,
        completed: false,
        claimed: false,
        iconName: 'gift',
      ),
      Challenge(
        id: 'ch5',
        title: '7-Day Login Streak',
        description: 'Log in every day for 7 consecutive days',
        progress: 5,
        total: 7,
        rewardPoints: 75,
        daysLeft: 2,
        completed: false,
        claimed: false,
        iconName: 'flame',
      ),
    ];
  }

  void completeChallenge(String id) {
    LoggerService.debug('Completing challenge ID: $id');
    for (var c in _challenges) {
      if (c.id == id) {
        c.completed = true;
        break;
      }
    }
    notifyListeners();
  }

  void claimChallenge(String id) {
    LoggerService.info('Claiming reward for challenge ID: $id');
    for (var c in _challenges) {
      if (c.id == id && c.completed && !c.claimed) {
        c.claimed = true;
        if (_authState != null) {
          _authState!.addPoints(c.rewardPoints);
        } else {
          LoggerService.warning('AuthState not linked to ChallengesState, points not added.');
        }
        break;
      }
    }
    notifyListeners();
  }
}
