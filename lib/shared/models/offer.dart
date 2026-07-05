class Offer {
  final String id;
  final String merchant;
  final String discount;
  final String description;
  final String expiresIn;
  final String cardName;
  final String category;
  final bool isHot;
  final String cashback;

  Offer({
    required this.id,
    required this.merchant,
    required this.discount,
    required this.description,
    required this.expiresIn,
    required this.cardName,
    required this.category,
    required this.isHot,
    required this.cashback,
  });
}
