import 'package:flutter/material.dart';
import '../../../core/services/logger_service.dart';
import '../../../shared/models/models.dart';

class FeedState extends ChangeNotifier {
  late List<Hack> _hacks;
  late List<Offer> _offers;

  FeedState() {
    _initData();
  }

  List<Hack> get hacks => _hacks;
  List<Offer> get offers => _offers;

  void _initData() {
    _hacks = [
      Hack(
        id: 'h1',
        title: 'Amazon Pay Gift Card + SBI Cashback trick',
        description:
            'Buy Amazon Pay Gift Cards using SBI Cashback Card to earn 5% extra cashback on all Amazon purchases. Stack with Amazon Pay offers for up to 15% total savings on every order.',
        cardName: 'SBI Cashback',
        savings: '₹2,400/yr',
        likes: 342,
        author: 'Rahul Mehta',
        authorInitials: 'RM',
        authorLevel: 'Hack Master',
        isLocked: false,
        category: 'Cashback',
        timestamp: '2h ago',
        liked: false,
      ),
      Hack(
        id: 'h2',
        title: 'HDFC SmartBuy Reward Points Multiplier',
        description:
            'Use Regalia Gold during SmartBuy portal for 5x reward points. Redeem during Apple or Samsung sales for maximum value. Effective return of 8-10% on electronics purchases.',
        cardName: 'HDFC Regalia Gold',
        savings: '₹8,500/yr',
        likes: 891,
        author: 'Priya Singh',
        authorInitials: 'PS',
        authorLevel: 'Rewards Expert',
        isLocked: false,
        category: 'Rewards',
        timestamp: '5h ago',
        liked: true,
      ),
      Hack(
        id: 'h3',
        title: 'Unlimited Airport Lounge Access Strategy',
        description:
            'This premium hack reveals how to maximize complimentary lounge visits across 5 Indian airports using card benefits and partner access...',
        cardName: 'HDFC Regalia Gold',
        savings: '₹15,000/yr',
        likes: 1247,
        author: 'Amit Patel',
        authorInitials: 'AP',
        authorLevel: 'Legend',
        isLocked: true,
        category: 'Travel',
        timestamp: '1d ago',
        liked: false,
      ),
      Hack(
        id: 'h4',
        title: 'Swiggy + Axis Ace Combo Deal',
        description:
            'Activate Axis Ace on Swiggy for flat 5% cashback. Pair with Swiggy One membership for free delivery. Works on all Swiggy orders including Instamart groceries.',
        cardName: 'Axis Ace',
        savings: '₹3,200/yr',
        likes: 456,
        author: 'Deepika Rao',
        authorInitials: 'DR',
        authorLevel: 'Saver',
        isLocked: false,
        category: 'Dining',
        timestamp: '3d ago',
        liked: false,
      ),
      Hack(
        id: 'h5',
        title: 'Fuel Surcharge Waiver + Reward Stack',
        description:
            'Complete fuel savings strategy using the right card combination across BPCL and HP pumps...',
        cardName: 'ICICI Amazon Pay',
        savings: '₹5,500/yr',
        likes: 678,
        author: 'Karan Joshi',
        authorInitials: 'KJ',
        authorLevel: 'Expert',
        isLocked: true,
        category: 'Fuel',
        timestamp: '4d ago',
        liked: false,
      ),
    ];

    _offers = [
      Offer(
        id: 'o1',
        merchant: 'Amazon',
        discount: '5% Cashback',
        description: 'Get 5% cashback on all Amazon purchases this weekend only',
        expiresIn: '2d 14h',
        cardName: 'SBI Cashback',
        category: 'Shopping',
        isHot: true,
        cashback: 'Up to ₹500',
      ),
      Offer(
        id: 'o2',
        merchant: 'Swiggy',
        discount: 'Flat ₹100 Off',
        description: 'On orders above ₹300 using Axis Ace card',
        expiresIn: '18h',
        cardName: 'Axis Ace',
        category: 'Dining',
        isHot: true,
        cashback: '₹100 off',
      ),
      Offer(
        id: 'o3',
        merchant: 'MakeMyTrip',
        discount: '12% Off',
        description: 'On flights booked with HDFC Regalia Gold',
        expiresIn: '5d',
        cardName: 'HDFC Regalia Gold',
        category: 'Travel',
        isHot: false,
        cashback: 'Up to ₹3,000',
      ),
      Offer(
        id: 'o4',
        merchant: 'Myntra',
        discount: '15% Cashback',
        description: 'On fashion purchases with ICICI Amazon Pay this month',
        expiresIn: '3d',
        cardName: 'ICICI Amazon Pay',
        category: 'Shopping',
        isHot: false,
        cashback: 'Up to ₹750',
      ),
      Offer(
        id: 'o5',
        merchant: 'BookMyShow',
        discount: '20% Off',
        description: 'On movie tickets every Friday with HDFC cards',
        expiresIn: '1d 6h',
        cardName: 'HDFC Millennia',
        category: 'Entertainment',
        isHot: true,
        cashback: 'Up to ₹200',
      ),
      Offer(
        id: 'o6',
        merchant: 'Flipkart',
        discount: '10% Off',
        description: 'During Big Billion Days with Axis Bank cards',
        expiresIn: '4d',
        cardName: 'Axis Ace',
        category: 'Shopping',
        isHot: false,
        cashback: 'Up to ₹1,000',
      ),
    ];
  }

  void likeHack(String id) {
    LoggerService.debug('Toggling like for hack ID: $id');
    for (var h in _hacks) {
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
    notifyListeners();
  }
}
