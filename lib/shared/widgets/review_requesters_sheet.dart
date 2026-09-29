import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/services/api_service.dart';
import '../../core/services/logger_service.dart';
import '../../core/theme/app_theme.dart';
import 'app_snackbar.dart';
import 'primitives.dart';

/// "Ask for a review" — the bottom sheet behind a card the caller does not
/// hold yet (Add Cards catalog): who in their network already has it and
/// has chosen to let them see it, each with a one-tap WhatsApp message
/// asking for a review.
///
/// Backed by `GET /follow/cards/{cardId}/review-requesters`, which only
/// returns people who are both an APPROVED follow *and* have this specific
/// card's `is_allowed` set — so everyone this sheet lists already agreed to
/// be seen holding it. Nobody here was asked anything new by opening this
/// sheet.
class ReviewRequestersSheet {
  const ReviewRequestersSheet._();

  static Future<void> show(
    BuildContext context, {
    required String cardId,
    required String cardName,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _ReviewRequestersSheetBody(
        cardId: cardId,
        cardName: cardName,
      ),
    );
  }
}

class _ReviewRequestersSheetBody extends StatefulWidget {
  final String cardId;
  final String cardName;

  const _ReviewRequestersSheetBody({
    required this.cardId,
    required this.cardName,
  });

  @override
  State<_ReviewRequestersSheetBody> createState() =>
      _ReviewRequestersSheetBodyState();
}

class _ReviewRequestersSheetBodyState
    extends State<_ReviewRequestersSheetBody> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _people = const [];

  /// Ids with a WhatsApp launch in flight, so a double-tap on a slow phone
  /// cannot fire the intent twice.
  final Set<String> _openingIds = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await ApiService.getReviewRequesters(widget.cardId);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (list == null) {
        _error = 'Could not load reviewers right now.';
      } else {
        _people = list;
      }
    });
  }

  static String _idOf(Map<String, dynamic> person) =>
      (person['user_id'] ?? '').toString();

  static String _nameOf(Map<String, dynamic> person) {
    final name = (person['name'] ?? person['display_name'] ?? '')
        .toString()
        .trim();
    return name.isEmpty ? 'Someone in your circle' : name;
  }

  static String _initialsOf(String name) {
    final trimmed = name.trim();
    return trimmed.isEmpty ? 'C' : trimmed[0].toUpperCase();
  }

  Future<void> _call(String phone) async {
    final messenger = ScaffoldMessenger.of(context);
    final uri = Uri(scheme: 'tel', path: phone);
    try {
      final opened = await launchUrl(uri);
      if (!opened) messenger.showError('Could not open the phone dialer.');
    } catch (e, stack) {
      LoggerService.error('Failed to open dialer for review requester', e, stack);
      messenger.showError('Could not open the phone dialer.');
    }
  }

  Future<void> _openWhatsapp(Map<String, dynamic> person) async {
    final id = _idOf(person);
    if (id.isNotEmpty && _openingIds.contains(id)) return;

    final messenger = ScaffoldMessenger.of(context);
    final url = (person['whatsapp_url'] ?? '').toString();
    final uri = url.isEmpty ? null : Uri.tryParse(url);
    if (uri == null) {
      messenger.showError("${_nameOf(person)}'s WhatsApp link was unreadable.");
      return;
    }

    setState(() => _openingIds.add(id));
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened) messenger.showError('Could not open WhatsApp.');
    } catch (e, stack) {
      LoggerService.error('Failed to open review-request WhatsApp link', e, stack);
      messenger.showError('Could not open WhatsApp.');
    } finally {
      if (mounted) setState(() => _openingIds.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.mdLg,
          AppSpacing.xl,
          AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              'Ask about ${widget.cardName}',
              style: AppText.sans(
                19,
                weight: FontWeight.w500,
                color: AppColors.text,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              "People in your circle who hold this card and let you see it — "
              "ask one for a quick review before you add it.",
              style: AppText.sans(12.5, color: AppColors.textDim),
            ),
            const SizedBox(height: AppSpacing.lg),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.5,
              ),
              child: _body(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
        child: Center(
          child: CircularProgressIndicator(
            color: AppColors.gold,
            strokeWidth: 2,
          ),
        ),
      );
    }

    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: AppText.sans(13, color: AppColors.textDim),
            ),
            const SizedBox(height: AppSpacing.lg),
            _RetryButton(onTap: () {
              setState(() => _loading = true);
              _load();
            }),
          ],
        ),
      );
    }

    if (_people.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: Text(
          "Nobody in your circle who holds this card has let you see it "
          "yet — try again once someone approves you, or once you follow "
          "someone who has it.",
          textAlign: TextAlign.center,
          style: AppText.sans(13, color: AppColors.textDim),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const ClampingScrollPhysics(),
      itemCount: _people.length,
      separatorBuilder: (context, index) =>
          const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final person = _people[index];
        final id = _idOf(person);
        final name = _nameOf(person);
        final phone = (person['phone_number'] ?? '').toString();
        return OutlinedSurface(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.mdLg,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              AvatarBubble(
                initials: _initialsOf(name),
                hue: AvatarHue.values[index % AvatarHue.values.length],
              ),
              const SizedBox(width: AppSpacing.mdLg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.sans(
                        13.5,
                        weight: FontWeight.w500,
                        color: AppColors.text,
                      ),
                    ),
                    if (phone.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _call(phone),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              PhosphorIconsFill.phone,
                              size: 12,
                              color: AppColors.teal,
                            ),
                            const SizedBox(width: 4),
                            MonoLabel(
                              phone,
                              size: 9.5,
                              letterSpacing: 0.8,
                              color: AppColors.teal,
                              uppercase: false,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              _AskButton(
                busy: id.isNotEmpty && _openingIds.contains(id),
                onTap: () => _openWhatsapp(person),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AskButton extends StatelessWidget {
  final bool busy;
  final VoidCallback onTap;

  const _AskButton({required this.busy, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.pill),
        onTap: busy ? null : onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.pill),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.55)),
          ),
          child: busy
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.6,
                    color: AppColors.gold,
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      PhosphorIconsFill.whatsappLogo,
                      size: 14,
                      color: AppColors.gold,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Ask',
                      style: AppText.sans(
                        11.5,
                        weight: FontWeight.w600,
                        color: AppColors.gold,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _RetryButton extends StatelessWidget {
  final VoidCallback onTap;

  const _RetryButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.pill),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.pill),
            border: Border.all(color: AppColors.border),
          ),
          child: Text(
            'Try again',
            style: AppText.sans(12, weight: FontWeight.w600, color: AppColors.text),
          ),
        ),
      ),
    );
  }
}
