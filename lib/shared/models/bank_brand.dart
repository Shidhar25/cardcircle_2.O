import 'package:flutter/material.dart';

/// A bank's display name and brand gradient.
///
/// The gradient is the plate the card falls back to when the catalog has no
/// artwork for it, or when an image URL fails — so a card still reads as
/// that bank's card rather than as a grey rectangle. Logos and artwork
/// themselves come from the backend.
class BankBrand {
  final String name;

  /// Two-stop gradient, dark enough that white chrome stays legible on top.
  final List<Color> gradient;

  const BankBrand({required this.name, required this.gradient});
}

/// Curated brand data keyed by the backend's `bank_id` slug.
///
/// Gradients approximate each bank's public brand colour, darkened so the
/// card face keeps contrast against white text and logos. Adding a bank is
/// one entry here; its logo and artwork come from the catalog.
const Map<String, BankBrand> kBankBrands = {
  'hdfc-bank': BankBrand(
    name: 'HDFC Bank',
    gradient: [Color(0xFF12467F), Color(0xFF071F3A)],
  ),
  'icici-bank': BankBrand(
    name: 'ICICI Bank',
    gradient: [Color(0xFF9C3A12), Color(0xFF3A1608)],
  ),
  'axis-bank': BankBrand(
    name: 'Axis Bank',
    gradient: [Color(0xFF8C1D45), Color(0xFF330A19)],
  ),
  'state-bank-of-india': BankBrand(
    name: 'State Bank of India',
    gradient: [Color(0xFF17539E), Color(0xFF08203E)],
  ),
  'kotak-mahindra-bank': BankBrand(
    name: 'Kotak Mahindra Bank',
    gradient: [Color(0xFF9E2A2B), Color(0xFF3A0F10)],
  ),
  'yes-bank': BankBrand(
    name: 'Yes Bank',
    gradient: [Color(0xFF13489B), Color(0xFF071B3B)],
  ),
  'bank-of-baroda': BankBrand(
    name: 'Bank of Baroda',
    gradient: [Color(0xFFA6531C), Color(0xFF3A1D0A)],
  ),
  'indusind-bank': BankBrand(
    name: 'IndusInd Bank',
    gradient: [Color(0xFF8E2032), Color(0xFF330C13)],
  ),
  'idfc-first-bank': BankBrand(
    name: 'IDFC FIRST Bank',
    gradient: [Color(0xFF8C2A22), Color(0xFF330F0C)],
  ),
  'rbl-bank': BankBrand(
    name: 'RBL Bank',
    gradient: [Color(0xFF1F4B87), Color(0xFF0B1C33)],
  ),
  'standard-chartered': BankBrand(
    name: 'Standard Chartered',
    gradient: [Color(0xFF0F5C64), Color(0xFF062326)],
  ),
  'hsbc-india': BankBrand(
    name: 'HSBC India',
    gradient: [Color(0xFF8E1420), Color(0xFF33070B)],
  ),
  'citibank': BankBrand(
    name: 'Citibank',
    gradient: [Color(0xFF10529E), Color(0xFF061F3B)],
  ),
  'american-express-banking-corp-india': BankBrand(
    name: 'American Express',
    gradient: [Color(0xFF1B5E9E), Color(0xFF08243B)],
  ),
  'au-small-finance-bank': BankBrand(
    name: 'AU Small Finance Bank',
    gradient: [Color(0xFF6E2C8F), Color(0xFF280F33)],
  ),
  'federal-bank': BankBrand(
    name: 'Federal Bank',
    gradient: [Color(0xFF13629E), Color(0xFF07243B)],
  ),
  'punjab-national-bank': BankBrand(
    name: 'Punjab National Bank',
    gradient: [Color(0xFF8C1F2E), Color(0xFF330B11)],
  ),
  'canara-bank': BankBrand(
    name: 'Canara Bank',
    gradient: [Color(0xFF13489B), Color(0xFF071B3B)],
  ),
  'union-bank-of-india': BankBrand(
    name: 'Union Bank of India',
    gradient: [Color(0xFF9E2436), Color(0xFF3B0D14)],
  ),
  'bank-of-india': BankBrand(
    name: 'Bank of India',
    gradient: [Color(0xFF1B4E9E), Color(0xFF081D3B)],
  ),
  'indian-bank': BankBrand(
    name: 'Indian Bank',
    gradient: [Color(0xFF175E8C), Color(0xFF082433)],
  ),
  'idbi-bank': BankBrand(
    name: 'IDBI Bank',
    gradient: [Color(0xFF0F6B4F), Color(0xFF06281E)],
  ),
  'bandhan-bank': BankBrand(
    name: 'Bandhan Bank',
    gradient: [Color(0xFF9E2A1F), Color(0xFF3B0F0B)],
  ),
  'dbs-bank': BankBrand(
    name: 'DBS Bank',
    gradient: [Color(0xFF8C1621), Color(0xFF33080C)],
  ),
  'sbm-bank': BankBrand(
    name: 'SBM Bank',
    gradient: [Color(0xFF1B5E7E), Color(0xFF08242F)],
  ),
};

/// Neutral treatment for a bank not yet in [kBankBrands] — deliberately
/// understated rather than eye-catching, so unmapped banks read as "not
/// styled yet" instead of as a deliberate design choice.
const BankBrand kFallbackBankBrand = BankBrand(
  name: '',
  gradient: [Color(0xFF2E3140), Color(0xFF16182A)],
);

/// Brand for a bank slug, always non-null.
BankBrand bankBrandFor(String? bankId) {
  if (bankId == null || bankId.isEmpty) return kFallbackBankBrand;
  return kBankBrands[bankId] ?? kFallbackBankBrand;
}

/// Two-letter monogram identifying the issuer on a plate.
///
/// `axis-bank` -> `AX`, `bank-of-baroda` -> `OB`, `hdfc-bank` -> `HD`.
/// "Bank" is dropped because it carries no signal — nearly every issuer has
/// it — and a single remaining word contributes its first two letters so the
/// monogram is always the same width.
String bankInitials(String bankIdOrName) {
  final words = bankIdOrName
      .replaceAll('-', ' ')
      .split(' ')
      .where((w) => w.isNotEmpty && w.toLowerCase() != 'bank')
      .toList();
  if (words.isEmpty) return '';
  if (words.length == 1) {
    final w = words.first;
    return (w.length >= 2 ? w.substring(0, 2) : w).toUpperCase();
  }
  return (words[0].substring(0, 1) + words[1].substring(0, 1)).toUpperCase();
}
