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
  List<Hack> get myHacks => _myHacks.isNotEmpty ? _myHacks : _hacks;
  List<Hack> get circleHacks => _circleHacks.isNotEmpty ? _circleHacks : _hacks;
  bool get isLoadingMyHacks => _isLoadingMyHacks;
  bool get isLoadingCircleHacks => _isLoadingCircleHacks;

  void _initSeedData() {
    _hacks = [
      Hack(
        id: '9e8b7d0b-6c97-4d56-9b7d-6de1d5f1d341',
        name: 'Swipe smart, fuel free',
        heading:
            'Use your RBL card at IndianOil ITPS POS, earn fuel points, convert them to XTRA rewards, and redeem them for fuel payments.',
        steps: [
          HackStep(name: 'Step 1', heading: 'Swipe at ITPS POS', icon: '💳', description: 'Swipe your RBL Bank XTRA Credit Card at an IndianOil ITPS POS machine.'),
          HackStep(name: 'Step 2', heading: 'Earn Fuel Points', icon: '⛽', description: 'Collect fuel points on fuel transactions at IndianOil outlets.'),
          HackStep(name: 'Step 3', heading: 'Convert to XTRA', icon: '🔄', description: 'Convert your fuel points into XTRA rewards points.'),
          HackStep(name: 'Step 4', heading: 'Redeem for Fuel', icon: '📱', description: 'Use XTRA rewards points to pay for fuel in the IndianOil app by purchasing Fuel e-vouchers.'),
          HackStep(name: 'Step 5', heading: 'Scan Voucher', icon: '🔍', description: 'Ask the fuel attendant to scan the QR code or enter the voucher code on the IndianOil POS to apply the payment.'),
        ],
        cards: ['IndianOil RBL Bank XTRA Credit Card'],
        savings: '8.5%',
        category: 'Fuel',
        rating: 4.8,
        availedby: '10 people on CardCircle have found this hack helpful',
        thingsToNote: [
          'Use IndianOil ITPS POS only, because other machines may not have the correct merchant code and accelerated fuel points may not be credited.',
          'Redeeming fuel points to XTRA rewards points has a Rs. 99 + GST fee, so redeem in bulk.',
          'Keep the transaction amount between Rs. 500 and Rs. 4000, otherwise the 1% fuel surcharge waiver may not apply.',
          'Maximum 2,000 fuel points can be earned per month, which allows fuel spends of up to about Rs. 13,334 at IndianOil outlets.'
        ],
      ),
      Hack(
        id: 'c3a7b7c5-4a2f-4f7d-9d35-1f2d5b9f7a11',
        name: 'Swipe smart, save on gas',
        heading:
            'Use your RBL card at IndianOil ITPS POS, earn fuel points, convert them to XTRA rewards, and redeem them while ordering gas in the IndianOil app.',
        steps: [
          HackStep(name: 'Step 1', heading: 'Swipe at ITPS POS', icon: '💳', description: 'Swipe your RBL Bank XTRA Credit Card at an IndianOil ITPS POS machine.'),
          HackStep(name: 'Step 2', heading: 'Earn Fuel Points', icon: '⛽', description: 'Collect fuel points on fuel transactions at IndianOil outlets.'),
          HackStep(name: 'Step 3', heading: 'Convert to XTRA', icon: '🔄', description: 'Convert your fuel points into XTRA rewards points.'),
          HackStep(name: 'Step 4', heading: 'Redeem in App', icon: '📱', description: 'Open the IndianOil app and redeem XTRA rewards points while ordering gas.'),
        ],
        cards: ['IndianOil RBL Bank XTRA Credit Card'],
        savings: 'Up to 8.5%',
        category: 'Gas',
        rating: 4.6,
        availedby: '10 people on CardCircle have found this hack helpful',
        thingsToNote: [
          'Use IndianOil ITPS POS only, because other machines may not have the correct merchant code and fuel points may not be credited.',
          'Redeeming fuel points to XTRA rewards points has a Rs. 99 + GST fee, so redeem in bulk.',
          'Keep the transaction amount between Rs. 500 and Rs. 4000, otherwise the 1% fuel surcharge waiver may not apply.',
          'Maximum 2,000 fuel points can be earned per month, which allows fuel spends of up to about Rs. 13,334 at IndianOil outlets.'
        ],
      ),
    ];

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
