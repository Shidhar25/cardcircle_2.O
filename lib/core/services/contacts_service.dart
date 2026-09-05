import 'package:flutter_contacts/flutter_contacts.dart';

import 'logger_service.dart';

/// Outcome of asking for the contacts permission.
enum ContactsPermission {
  granted,

  /// Declined this time; asking again later is allowed.
  denied,

  /// Declined permanently (or blocked by policy) — the OS will not show the
  /// prompt again, so the user has to enable it in Settings.
  permanentlyDenied,
}

/// Reads the device address book for contact sync.
///
/// Replaces the hardcoded sample payload that used to be sent: with that in
/// place, a real contact could never be matched, so the invite/backfill flow
/// could not work end to end no matter what the backend did.
class ContactsService {
  /// Requests permission, distinguishing a soft decline from a permanent one
  /// so the caller can decide whether re-prompting is worth it.
  static Future<ContactsPermission> requestPermission() async {
    try {
      // `readonly` keeps the request to the narrowest scope that works —
      // the app only ever reads names and numbers.
      final granted = await FlutterContacts.requestPermission(readonly: true);
      if (granted) return ContactsPermission.granted;

      // flutter_contacts collapses "denied" and "don't ask again" into a
      // single false. Re-requesting is the only way to tell them apart: when
      // the OS will no longer prompt, the second call returns immediately.
      final retry = await FlutterContacts.requestPermission(readonly: true);
      return retry
          ? ContactsPermission.granted
          : ContactsPermission.permanentlyDenied;
    } catch (e, stack) {
      LoggerService.error('Contacts permission request failed', e, stack);
      return ContactsPermission.denied;
    }
  }

  /// Every contact with at least one phone number, as
  /// `{mobile_number, contact_name}` — the shape `POST /user/contacts/sync`
  /// expects.
  ///
  /// Numbers are normalised to E.164 so they can match the phone numbers
  /// accounts are created with; anything that can't be normalised is dropped
  /// rather than sent in a form the backend can't match.
  static Future<List<Map<String, String>>> readContacts({
    String defaultCountryCode = '+91',
  }) async {
    try {
      final contacts = await FlutterContacts.getContacts(
        withProperties: true,
        withPhoto: false,
        withThumbnail: false,
      );

      final seen = <String>{};
      final out = <Map<String, String>>[];

      for (final c in contacts) {
        for (final phone in c.phones) {
          final normalised = normalisePhone(
            phone.number,
            defaultCountryCode: defaultCountryCode,
          );
          if (normalised == null) continue;
          if (!seen.add(normalised)) continue; // de-dupe across contacts
          out.add({
            'mobile_number': normalised,
            'contact_name': c.displayName.trim().isEmpty
                ? normalised
                : c.displayName.trim(),
          });
        }
      }

      LoggerService.info(
        'Read ${out.length} unique numbers from ${contacts.length} contacts.',
      );
      return out;
    } catch (e, stack) {
      LoggerService.error('Failed to read contacts', e, stack);
      return const [];
    }
  }

  /// Best-effort E.164 normalisation.
  ///
  /// Handles the forms an Indian address book actually contains: spaces and
  /// punctuation, a `0` trunk prefix, `00` international prefix, and bare
  /// 10-digit numbers. Returns null when the result can't be a real number,
  /// so junk never reaches the sync payload.
  static String? normalisePhone(
    String raw, {
    String defaultCountryCode = '+91',
  }) {
    var s = raw.replaceAll(RegExp(r'[^\d+]'), '');
    if (s.isEmpty) return null;

    if (s.startsWith('00')) s = '+${s.substring(2)}';

    if (s.startsWith('+')) {
      final digits = s.substring(1);
      if (digits.length < 8 || digits.length > 15) return null;
      return '+$digits';
    }

    // Strip a domestic trunk prefix before assuming the default country.
    if (s.startsWith('0')) s = s.replaceFirst(RegExp(r'^0+'), '');

    // Already carries the country code without a '+'.
    final cc = defaultCountryCode.replaceAll('+', '');
    if (s.startsWith(cc) && s.length > cc.length + 6) {
      return '+$s';
    }

    if (s.length < 6 || s.length > 15) return null;
    return '$defaultCountryCode$s';
  }
}
