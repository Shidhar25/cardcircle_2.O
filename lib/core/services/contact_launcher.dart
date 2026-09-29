import 'package:url_launcher/url_launcher.dart';

import 'logger_service.dart';

/// Opens the phone dialer or WhatsApp for a contact, the one place that
/// error handling lives rather than copied into every screen that offers a
/// "call" or "message" button.
///
/// Both return a plain success bool rather than throwing or showing
/// anything themselves — the caller already has the right wording for
/// *who* couldn't be reached ("Could not call Riya" vs a generic message),
/// which this has no way to know.
class ContactLauncher {
  const ContactLauncher._();

  /// Opens the phone dialer pre-filled with [phone].
  ///
  /// This is `ACTION_DIAL`, not `ACTION_CALL` — it hands the number to the
  /// dialer and stops there; the person still has to press the call button
  /// themselves. Nothing here can silently place a call.
  static Future<bool> call(String phone) {
    if (phone.trim().isEmpty) return Future.value(false);
    return _launch(Uri(scheme: 'tel', path: phone.trim()), 'the dialer');
  }

  /// Opens [whatsappUrl] (a `https://wa.me/...` link with a prefilled
  /// message, as the backend's `whatsapp_url` fields already are).
  static Future<bool> whatsapp(String whatsappUrl) {
    final uri = Uri.tryParse(whatsappUrl);
    if (uri == null) return Future.value(false);
    return _launch(uri, 'WhatsApp', externalApplication: true);
  }

  static Future<bool> _launch(
    Uri uri,
    String what, {
    bool externalApplication = false,
  }) async {
    try {
      return await launchUrl(
        uri,
        mode: externalApplication
            ? LaunchMode.externalApplication
            : LaunchMode.platformDefault,
      );
    } catch (e, stack) {
      LoggerService.error('Failed to open $what', e, stack);
      return false;
    }
  }
}
