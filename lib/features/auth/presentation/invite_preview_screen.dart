import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/invite_link.dart';
import '../../../core/services/pending_invite.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/gritty_background.dart';
import '../../../shared/widgets/primitives.dart';
import '../../feed/presentation/tabs_layout.dart';
import '../state/auth_state.dart';

/// What a tapped invite link (`cardcircle://invite/<token>` today,
/// `https://cardcircle.com/invite/<token>` once that domain is live) opens
/// to, whether or not the person already has an account.
///
/// Two different continuations from the same screen:
///
///   * Not signed in: the token cannot be redeemed yet — redeeming needs
///     auth — so it's stashed in [PendingInvite] and the person is sent
///     through the normal login -> OTP -> create-profile flow. Once that
///     profile exists, [CreateProfileScreen] consumes the stashed token and
///     redeems it automatically — this is the "onboard, then follow the
///     inviter" flow from the spec.
///   * Already signed in: nothing to onboard, so redeeming happens right
///     here.
///
/// The GET this screen opens with is intentionally unauthenticated
/// (see [ApiService.getInvitePreview]) — showing who invited you must not
/// require an account first.
class InvitePreviewScreen extends StatefulWidget {
  const InvitePreviewScreen({super.key});

  @override
  State<InvitePreviewScreen> createState() => _InvitePreviewScreenState();
}

class _InvitePreviewScreenState extends State<InvitePreviewScreen> {
  late final String _token;
  bool _didInit = false;

  bool _loading = true;
  bool _redeeming = false;
  String? _loadError;
  String? _inviterName;
  String? _inviterUsername;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didInit) return;
    _didInit = true;

    final arg = ModalRoute.of(context)?.settings.arguments;
    final token = arg is String ? arg.trim() : '';
    _token = token;

    if (token.isEmpty) {
      // Reached with no token — a malformed link, or the route pushed
      // programmatically without one. Nothing to preview or redeem.
      _loading = false;
      _loadError = 'This invite link looks incomplete.';
      return;
    }
    _loadPreview();
  }

  Future<void> _loadPreview() async {
    final result = await ApiService.getInvitePreview(_token);
    if (!mounted) return;

    if (!result.ok) {
      setState(() {
        _loading = false;
        // A used or expired token both land here (404/400/410 depending on
        // the backend), so the wording stays generic rather than guessing
        // which one it was.
        _loadError = result.display(
          'This invite link is invalid or has expired.',
        );
      });
      return;
    }

    // `name` is the confirmed field — the backend reads it from
    // `user_profiles.name`, the person's real name, not their `@username`
    // (which used to be shown here by mistake, under the confusingly
    // similar `display_name` key). `full_name` stays as a fallback for a
    // differently-shaped response; `display_name` deliberately does not,
    // since reusing it here would risk silently showing a username again.
    final data = result.data ?? const <String, dynamic>{};
    final inviter =
        (data['inviter'] as Map?)?.cast<String, dynamic>() ?? data;

    setState(() {
      _loading = false;
      _inviterName = _firstNonEmpty([inviter['name'], inviter['full_name']]);
      _inviterUsername = _firstNonEmpty([
        inviter['username'],
        inviter['handle'],
      ]);
    });
  }

  static String? _firstNonEmpty(List<dynamic> candidates) {
    for (final c in candidates) {
      final s = c?.toString().trim();
      if (s != null && s.isNotEmpty) return s;
    }
    return null;
  }

  void _continue() {
    final authState = Provider.of<AuthState>(context, listen: false);
    if (authState.hasProfile) {
      _redeemNow();
    } else {
      PendingInvite.remember(_token);
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    }
  }

  Future<void> _redeemNow() async {
    if (_redeeming) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _redeeming = true);

    final result = await ApiService.redeemInvite(_token);
    if (!mounted) return;
    setState(() => _redeeming = false);

    if (result.ok) {
      messenger.showSuccess(
        result.display(
          _inviterName == null
              ? 'Follow request sent.'
              : 'Follow request sent to $_inviterName.',
        ),
      );
    } else {
      // Not `showResult` — its generic 403-means-"session expired" reading
      // is wrong for this endpoint. See [InviteLink.redeemFailureMessage].
      messenger.showError(InviteLink.redeemFailureMessage(result));
    }

    Navigator.pushNamedAndRemoveUntil(
      context,
      '/home',
      (route) => false,
      arguments: TabsLayout.circleTab,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: GrittyBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Center(child: _body()),
          ),
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const CircularProgressIndicator(
        strokeWidth: 2,
        color: AppColors.gold,
      );
    }

    if (_loadError != null) {
      return _Message(
        icon: PhosphorIconsRegular.linkBreak,
        title: 'Invite link unavailable',
        body: _loadError!,
        actionLabel: 'Continue to CardCircle',
        onAction: () => Navigator.pushNamedAndRemoveUntil(
          context,
          '/login',
          (route) => false,
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AvatarBubble(
          initials: (_inviterName ?? _inviterUsername ?? '?')
              .trim()
              .substring(0, 1)
              .toUpperCase(),
          size: 72,
        ),
        const SizedBox(height: AppSpacing.xl),
        Text(
          _inviterName != null
              ? '$_inviterName invited you to CardCircle'
              : 'You\'ve been invited to CardCircle',
          textAlign: TextAlign.center,
          style: AppText.sans(
            22,
            weight: FontWeight.w500,
            color: AppColors.text,
          ),
        ),
        if (_inviterUsername != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            '@$_inviterUsername',
            style: AppText.sans(13, color: AppColors.textDim),
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Join to see and share credit card benefits with your circle.',
          textAlign: TextAlign.center,
          style: AppText.sans(13, color: AppColors.textDim),
        ),
        const SizedBox(height: AppSpacing.xxl),
        GoldButton(
          label: 'Continue',
          icon: PhosphorIconsRegular.arrowRight,
          loading: _redeeming,
          onTap: _continue,
        ),
      ],
    );
  }
}

class _Message extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final String actionLabel;
  final VoidCallback onAction;

  const _Message({
    required this.icon,
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 40, color: AppColors.textDim),
        const SizedBox(height: AppSpacing.lg),
        Text(
          title,
          style: AppText.sans(18, weight: FontWeight.w500, color: AppColors.text),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          body,
          textAlign: TextAlign.center,
          style: AppText.sans(13, color: AppColors.textDim),
        ),
        const SizedBox(height: AppSpacing.xxl),
        GoldButton(label: actionLabel, onTap: onAction),
      ],
    );
  }
}
