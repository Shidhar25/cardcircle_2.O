import 'package:flutter/material.dart';
import '../../../core/services/logger_service.dart';
import '../../../core/services/api_service.dart';
import '../../../shared/models/models.dart';

class FeedState extends ChangeNotifier {
  late List<Hack> _hacks;
  late List<Offer> _offers;
  List<Hack> _myHacks = [];
  List<Hack> _circleHacks = [];
  bool _isLoadingMyHacks = false;
  bool _isLoadingCircleHacks = false;

  FeedState() {
    _initSeedData();
    fetchMyHacks();
    fetchCircleHacks();
  }

  List<Hack> get hacks => _hacks;
  List<Offer> get offers => _offers;
  List<Hack> get myHacks => _myHacks;
  List<Hack> get circleHacks => _circleHacks;
  bool get isLoadingMyHacks => _isLoadingMyHacks;
  bool get isLoadingCircleHacks => _isLoadingCircleHacks;

  void _initSeedData() {
    _hacks = [];
    _offers = [];
  }

  Future<void> fetchMyHacks() async {
    _isLoadingMyHacks = true;
    notifyListeners();
    try {
      final list = await ApiService.getMyHacks();
      if (list != null && list.isNotEmpty) {
        _myHacks = list.map((e) => Hack.fromJson(e)).toList();
        LoggerService.info('Fetched ${_myHacks.length} My Hacks from backend.');
      }
    } catch (e, stack) {
      LoggerService.error('Error in fetchMyHacks', e, stack);
    } finally {
      _isLoadingMyHacks = false;
      notifyListeners();
    }
  }

  Future<void> fetchCircleHacks() async {
    _isLoadingCircleHacks = true;
    notifyListeners();
    try {
      final list = await ApiService.getCircleHacks();
      if (list != null && list.isNotEmpty) {
        _circleHacks = list.map((e) => Hack.fromJson(e)).toList();
        LoggerService.info('Fetched ${_circleHacks.length} Circle Hacks from backend.');
      }
    } catch (e, stack) {
      LoggerService.error('Error in fetchCircleHacks', e, stack);
    } finally {
      _isLoadingCircleHacks = false;
      notifyListeners();
    }
  }

  void likeHack(String id) {
    LoggerService.debug('Toggling like for hack ID: $id');
    for (var list in [_hacks, _myHacks, _circleHacks]) {
      for (var h in list) {
        if (h.id == id) {
          h.liked = !h.liked;
          if (h.liked) {
            h.likes += 1;
          } else {
            h.likes -= 1;
          }
          break;
        }
      }
    }
    notifyListeners();
  }

  Future<void> loadHacks() async {
    await Future.wait([
      fetchMyHacks(),
      fetchCircleHacks(),
    ]);
  }

  Future<void> loadOffers() async {
    await loadHacks();
  }
}
