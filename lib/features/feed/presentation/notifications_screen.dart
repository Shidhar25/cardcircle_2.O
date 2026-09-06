import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import 'tabs_layout.dart';
import '../../../shared/models/app_notification.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../core/services/api_service.dart';
import '../../circle/state/circle_state.dart';
import '../../auth/state/auth_state.dart';
import '../../../shared/widgets/gritty_background.dart';
import '../../../shared/widgets/primitives.dart';

/// v1 screen 20 — Notifications. Matches CardCircle.html's `isNotifications`
/// block: back + title + "Mark read", then grouped rows (icon tile, text,
/// timestamp, unread dot).
///
/// Real incoming follow requests need actionable approve/reject controls the
/// prototype's plain notif row doesn't have, so they get their own section
/// above the grouped list rather than being squeezed into that row shape.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _isLoading = false;
  List<AppNotification> _pushNotifications = [];

  @override
  void initState() {
    super.initState();
    _fetchPushNotifications();
  }

  Future<void> _fetchPushNotifications() async {
    setState(() => _isLoading = true);
    final pushData = await ApiService.getNotifications();
    if (mounted) {
      setState(() {
        _pushNotifications = (pushData ?? [])
            .map(AppNotification.tryParse)
            .nonNulls
            .toList();
        _isLoading = false;
      });
    }
  }

  /// Marks a notification read and, where it points somewhere, goes there.
  ///
  /// `CONTACT_JOINED` says a contact has just joined — the only useful next
  /// step is to go and follow them, so it lands on Circle rather than
  /// leaving the reader to find them.
  Future<void> _openNotification(AppNotification notif) async {
    // Dim it immediately: the request is not worth waiting on, and a row
    // that stays bold after being opened reads as broken.
    if (!notif.isRead) {
      setState(() {
        final i = _pushNotifications.indexWhere((n) => n.id == notif.id);
        if (i != -1) {
          _pushNotifications[i] = AppNotification(
            id: notif.id,
            title: notif.title,
            body: notif.body,
            kind: notif.kind,
            isRead: true,
            createdAt: notif.createdAt,
            data: notif.data,
          );
        }
      });
      ApiService.markNotificationRead(notif.id);
    }

    if (!notif.isActionable || !mounted) return;

    Navigator.pushNamedAndRemoveUntil(
      context,
      '/home',
      (route) => false,
      arguments: TabsLayout.circleTab,
    );
  }

  void _showCardAccessSheet(String followId, String requesterName) {
    final authState = Provider.of<AuthState>(context, listen: false);
    final myCards = authState.user.cards;
    final List<String> selectedCards = myCards.map((c) => c.id).toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final allSelected =
                myCards.isNotEmpty && selectedCards.length == myCards.length;

            return Container(
              padding: EdgeInsets.only(
                left: AppSpacing.xl,
                right: AppSpacing.xl,
                top: AppSpacing.xl,
                bottom:
                    AppSpacing.xl + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const MonoLabel(
                        'MANAGE CARD ACCESS',
                        size: 10,
                        letterSpacing: 2.0,
                        color: AppColors.textDim,
                      ),
                      if (myCards.isNotEmpty)
                        GestureDetector(
                          onTap: () {
                            setModalState(() {
                              if (allSelected) {
                                selectedCards.clear();
                              } else {
                                selectedCards
                                  ..clear()
                                  ..addAll(myCards.map((c) => c.id));
                              }
                            });
                          },
                          child: Text(
                            allSelected ? 'Deselect All' : 'Select All',
                            style: AppText.sans(
                              12,
                              weight: FontWeight.w500,
                              color: AppColors.gold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Select specific card(s) to show to $requesterName:',
                    style: AppText.sans(
                      15,
                      weight: FontWeight.w500,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  if (myCards.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                        child: Text(
                          'You have no cards added yet. Approving will share no cards.',
                          style: AppText.sans(13, color: AppColors.textDim),
                        ),
                      ),
                    )
                  else
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.4,
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: myCards.length,
                        itemBuilder: (context, index) {
                          final card = myCards[index];
                          final isSelected = selectedCards.contains(card.id);
                          return Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(
                                AppRadii.card,
                              ),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.gold
                                    : AppColors.border,
                                width: isSelected ? 1.5 : 1.0,
                              ),
                            ),
                            child: CheckboxListTile(
                              value: isSelected,
                              activeColor: AppColors.gold,
                              checkColor: AppColors.background,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.lg,
                                vertical: 4,
                              ),
                              title: Text(
                                card.name,
                                style: AppText.sans(
                                  14,
                                  weight: FontWeight.w500,
                                  color: AppColors.text,
                                ),
                              ),
                              subtitle: Text(
                                card.bank,
                                style: AppText.sans(
                                  11,
                                  color: AppColors.textDim,
                                ),
                              ),
                              secondary: Container(
                                width: 36,
                                height: 24,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(4),
                                  gradient: LinearGradient(
                                    colors: card.gradientColors,
                                  ),
                                ),
                              ),
                              onChanged: (val) {
                                setModalState(() {
                                  if (val == true) {
                                    selectedCards.add(card.id);
                                  } else {
                                    selectedCards.remove(card.id);
                                  }
                                });
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: AppSpacing.xl),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            'Cancel',
                            style: AppText.sans(
                              13,
                              weight: FontWeight.w500,
                              color: AppColors.textDim,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: GoldButton(
                          label: 'Confirm & Allow',
                          height: 46,
                          onTap: () async {
                            // Both resolved before the pop: this context
                            // belongs to the sheet being dismissed, so it is
                            // defunct by the time the request returns.
                            final messenger = ScaffoldMessenger.of(context);
                            final circle = Provider.of<CircleState>(
                              context,
                              listen: false,
                            );
                            Navigator.pop(context);
                            setState(() => _isLoading = true);
                            final result = await circle.approveRequest(
                              followId,
                              selectedCards,
                            );
                            if (mounted) setState(() => _isLoading = false);
                            messenger.showResult(
                              result,
                              onSuccess:
                                  'Approved — ${selectedCards.length} card(s) shared.',
                              onFailure: 'Could not approve that request.',
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final circleState = Provider.of<CircleState>(context);
    final requests = circleState.incomingRequests;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: GrittyBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.md,
                  AppSpacing.xl,
                  AppSpacing.mdLg,
                ),
                child: Row(
                  children: [
                    IconTile(
                      icon: PhosphorIconsRegular.arrowLeft,
                      iconSize: 17,
                      onTap: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: AppSpacing.mdLg),
                    Expanded(
                      child: Text(
                        'Notifications',
                        style: AppText.sans(
                          20,
                          weight: FontWeight.w500,
                          color: AppColors.text,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                    Text(
                      'Mark read',
                      style: AppText.sans(11.5, color: AppColors.gold),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    await circleState.fetchIncomingRequests();
                    await _fetchPushNotifications();
                  },
                  color: AppColors.gold,
                  backgroundColor: AppColors.surface,
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.gold,
                            strokeWidth: 2,
                          ),
                        )
                      : (requests.isEmpty && _pushNotifications.isEmpty)
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            SizedBox(
                              height: MediaQuery.of(context).size.height * 0.6,
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      PhosphorIconsRegular.bellSlash,
                                      size: 40,
                                      color: AppColors.textGhost,
                                    ),
                                    const SizedBox(height: AppSpacing.md),
                                    Text(
                                      'No new notifications',
                                      style: AppText.sans(
                                        14,
                                        color: AppColors.textDim,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        )
                      : ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.xl,
                            0,
                            AppSpacing.xl,
                            30,
                          ),
                          children: [
                            if (requests.isNotEmpty) ...[
                              const MonoLabel(
                                'FOLLOW REQUESTS',
                                size: 9.5,
                                letterSpacing: 1.8,
                                color: AppColors.textFaint,
                              ),
                              const SizedBox(height: AppSpacing.mdLg),
                              ...List.generate(requests.length, (index) {
                                final req = requests[index];
                                final followId = req['follow_id'] ?? '';
                                final name =
                                    req['follower_display_name'] ??
                                    req['name'] ??
                                    'Unknown Saver';
                                final username =
                                    req['follower_username'] ??
                                    req['username'] ??
                                    name.toLowerCase().replaceAll(' ', '');
                                final initials = name.isNotEmpty
                                    ? name.trim()[0].toUpperCase()
                                    : 'C';

                                return Padding(
                                  padding: const EdgeInsets.only(
                                    bottom: AppSpacing.sm,
                                  ),
                                  child: OutlinedSurface(
                                    padding: const EdgeInsets.all(
                                      AppSpacing.mdLg,
                                    ),
                                    child: Row(
                                      children: [
                                        AvatarBubble(
                                          initials: initials,
                                          size: 40,
                                          hue: AvatarHue.values[index % 4],
                                        ),
                                        const SizedBox(width: AppSpacing.mdLg),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                name,
                                                style: AppText.sans(
                                                  14,
                                                  weight: FontWeight.w500,
                                                  color: AppColors.text,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                '@$username requested to follow you',
                                                style: AppText.sans(
                                                  12,
                                                  color: AppColors.textDim,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        TextButton(
                                          onPressed: () async {
                                            // Captured before the await; this
                                            // context is the dialog's.
                                            final messenger =
                                                ScaffoldMessenger.of(context);
                                            setState(() => _isLoading = true);
                                            final result = await circleState
                                                .rejectRequest(followId);
                                            if (mounted) {
                                              setState(
                                                () => _isLoading = false,
                                              );
                                            }
                                            messenger.showResult(
                                              result,
                                              onSuccess:
                                                  'Request from $name rejected.',
                                              onFailure:
                                                  'Could not reject that request.',
                                            );
                                          },
                                          style: TextButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 8,
                                            ),
                                          ),
                                          child: Text(
                                            'Reject',
                                            style: AppText.sans(
                                              12,
                                              weight: FontWeight.w500,
                                              color: AppColors.textDim,
                                            ),
                                          ),
                                        ),
                                        GestureDetector(
                                          onTap: () => _showCardAccessSheet(
                                            followId,
                                            name,
                                          ),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 8,
                                            ),
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(
                                                    AppRadii.pill,
                                                  ),
                                              color: AppColors.gold.withValues(
                                                alpha: 0.12,
                                              ),
                                              border: Border.all(
                                                color: AppColors.gold,
                                              ),
                                            ),
                                            child: Text(
                                              'Approve',
                                              style: AppText.sans(
                                                11,
                                                weight: FontWeight.w500,
                                                color: AppColors.gold,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                              const SizedBox(height: AppSpacing.md),
                            ],
                            if (_pushNotifications.isNotEmpty) ...[
                              const MonoLabel(
                                'RECENT NOTIFICATIONS',
                                size: 9.5,
                                letterSpacing: 1.8,
                                color: AppColors.textFaint,
                              ),
                              const SizedBox(height: AppSpacing.mdLg),
                              ..._pushNotifications.map(
                                (notif) => Padding(
                                  padding: const EdgeInsets.only(
                                    bottom: AppSpacing.sm,
                                  ),
                                  child: _NotificationRow(
                                    notification: notif,
                                    onTap: () => _openNotification(notif),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One notification.
///
/// The icon is chosen by type and unread rows are marked, because a list
/// where every entry looks identical makes the reader read all of them to
/// find the one that matters.
class _NotificationRow extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;

  const _NotificationRow({required this.notification, required this.onTap});

  (IconData, Color) get _glyph => switch (notification.kind) {
    NotificationKind.contactJoined => (
      PhosphorIconsFill.userPlus,
      AppColors.teal,
    ),
    NotificationKind.followRequest => (
      PhosphorIconsFill.userCircle,
      AppColors.gold,
    ),
    NotificationKind.other => (PhosphorIconsFill.bell, AppColors.gold),
  };

  @override
  Widget build(BuildContext context) {
    final (icon, tint) = _glyph;
    final unread = !notification.isRead;

    return OutlinedSurface(
      onTap: onTap,
      // Unread rows sit slightly proud of the read ones.
      background: unread
          ? AppColors.gold.withValues(alpha: 0.05)
          : AppColors.surface,
      padding: const EdgeInsets.all(AppSpacing.mdLg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadii.card),
              color: AppColors.elevated,
            ),
            child: Icon(icon, size: 16, color: tint),
          ),
          const SizedBox(width: AppSpacing.mdLg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notification.title,
                  style: AppText.sans(
                    13,
                    weight: unread ? FontWeight.w500 : FontWeight.w400,
                    color: AppColors.text,
                    height: 1.4,
                  ),
                ),
                if (notification.body.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    notification.body,
                    style: AppText.sans(
                      12,
                      color: AppColors.textDim,
                      height: 1.4,
                    ),
                  ),
                ],
                if (notification.relativeTime.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  MonoLabel(
                    notification.relativeTime,
                    size: 9,
                    letterSpacing: 1.1,
                    color: AppColors.textGhost,
                    uppercase: false,
                  ),
                ],
              ],
            ),
          ),
          if (unread) ...[
            const SizedBox(width: AppSpacing.sm),
            Container(
              width: 7,
              height: 7,
              margin: const EdgeInsets.only(top: 6),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.gold,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
