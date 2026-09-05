import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/contacts_service.dart';
import '../../../core/services/device_service.dart';
import '../../auth/state/auth_state.dart';
import '../state/circle_state.dart';
import '../../../shared/models/contact_action.dart';
import '../../../shared/widgets/gritty_background.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/primitives.dart';

/// v1 screen 23 — Circle. Matches CardCircle.html's `isCircle` block:
/// title + follower/following counts, a FOLLOWERS / FOLLOWING / SUGGESTED
/// segmented tab bar, and a flat list of people rows with a follow pill.
///
/// The app has real backend features the prototype doesn't spec (incoming
/// follow requests, contact-sync prompt, invite sheet, card-access approval)
/// — those are kept, styled with the same tokens, below the prototype's
/// header/tab chrome rather than dropped.
class CircleScreen extends StatefulWidget {
  const CircleScreen({super.key});

  @override
  State<CircleScreen> createState() => _CircleScreenState();
}

/// Whether this account still needs a contact sync.
///
/// Tri-state on purpose. Before the dashboard answers, the screen must not
/// claim either "you're synced" (hiding the only way forward) or "you're not"
/// (flashing a sync prompt at someone who already synced).
enum _SyncStatus { unknown, needed, done }

/// Why the card-access sheet was opened.
enum _AccessMode {
  /// Approving an incoming request: POST /follow/requests/{id}/approve.
  approve,

  /// Changing an existing follower's access: PUT /follow/permissions/{id}.
  edit,
}

class _CircleScreenState extends State<CircleScreen> {
  int _tabIndex = 0; // 0 = followers, 1 = following, 2 = suggested

  /// True only while contacts are being read and uploaded. Kept separate
  /// from [_isMutating] so approving a follow request no longer puts the
  /// contact-sync button into a spinner.
  bool _isSyncing = false;

  /// True while a follow request is being approved or rejected.

  _SyncStatus _syncStatus = _SyncStatus.unknown;

  /// Ids with a follow/unfollow in flight. Per-row rather than a single
  /// screen-wide flag so tapping one person's Follow does not freeze every
  /// other row on the list.
  final Set<String> _pendingFollowIds = {};

  /// The automatic prompt fires once per visit to this screen. Declining it
  /// must not remove the ability to sync later, which is what the persistent
  /// [_SyncPrompt] card below the tabs is for.
  bool _autoPromptShown = false;

  Future<void> _handleRefresh() async {
    final circleState = Provider.of<CircleState>(context, listen: false);
    final authState = Provider.of<AuthState>(context, listen: false);
    await Future.wait([
      circleState.loadAll(),
      authState.refreshProfileFromServer(),
    ]);
    // Bob may have signed up since the last look; the server backfills the
    // match, so re-reading the directory is enough — no resync needed.
    if (mounted) await _checkSyncNeeded();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _checkSyncNeeded();
      // Outgoing requests are their own endpoint and are not part of the
      // directory load, so the Requests tab needs them fetched too.
      Provider.of<CircleState>(context, listen: false).fetchOutgoingRequests();
    });
  }

  /// Whether the sync affordance should be on screen.
  ///
  /// Shown whenever a sync is still outstanding — including after a decline,
  /// which is the case that previously left Circle permanently empty with no
  /// control to fix it.
  bool get _showSyncPrompt => _syncStatus == _SyncStatus.needed;

  /// Asks the server whether this account still needs a contact sync, and if
  /// so prompts immediately.
  ///
  /// The prompt is driven by arriving on this screen rather than by a button:
  /// Circle is empty and useless without a sync, so a dismissable banner just
  /// leaves people looking at an empty list.
  Future<void> _checkSyncNeeded() async {
    final dash = await ApiService.getDashboard();
    if (!mounted) return;

    final raw = dash?['iscontactsyncneeded'];
    final circleState = Provider.of<CircleState>(context, listen: false);

    // A missing or unreadable flag must not be read as "already synced".
    // Defaulting that to false is what could leave a never-synced account
    // staring at an empty Circle with nothing to press: fall back to the
    // directory itself, which is empty exactly when no sync has happened.
    final bool needed = raw is bool
        ? raw
        : (raw is String
              ? raw.toLowerCase() == 'true'
              : circleState.friends.isEmpty);

    setState(
      () => _syncStatus = needed ? _SyncStatus.needed : _SyncStatus.done,
    );

    if (!needed) {
      await circleState.loadContactsFromDirectory();
      return;
    }

    // Offer the rationale once per visit. Declining leaves the persistent
    // prompt card in place rather than closing the door.
    if (!_autoPromptShown) {
      _autoPromptShown = true;
      await _promptForSync();
    }
  }

  /// Explains why contacts are needed, then hands off to the OS permission
  /// dialog. Showing our own rationale first means a decline is an informed
  /// one — the OS only offers its prompt once.
  Future<void> _promptForSync() async {
    if (_isSyncing) return;
    final proceed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
        ),
        title: Text(
          'Find your circle',
          style: AppText.sans(
            15,
            weight: FontWeight.w500,
            color: AppColors.text,
          ),
        ),
        content: Text(
          'CardCircle matches your contacts against people already here so you '
          'can see which cards your friends carry. Only phone numbers are sent, '
          'and they are never shown to anyone.',
          style: AppText.sans(13, color: AppColors.textDim, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(
              'Not now',
              style: AppText.sans(13, color: AppColors.textDim),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              'Continue',
              style: AppText.sans(
                13,
                weight: FontWeight.w500,
                color: AppColors.gold,
              ),
            ),
          ),
        ],
      ),
    );

    if (proceed == true && mounted) await _performSync();
  }

  /// Sync started by the user from the header.
  ///
  /// Someone who has already synced does not need the rationale again —
  /// they granted contacts access and know what this does — so a repeat
  /// sync runs straight away. A first-time tap still explains itself
  /// before the OS prompt, which only ever appears once.
  Future<void> _handleManualSync() async {
    if (_isSyncing) return;
    if (_syncStatus == _SyncStatus.done) {
      await _performSync();
    } else {
      await _promptForSync();
    }
  }

  Future<void> _performSync() async {
    if (_isSyncing) return;
    setState(() => _isSyncing = true);

    final messenger = ScaffoldMessenger.of(context);

    final permission = await ContactsService.requestPermission();
    if (!mounted) return;

    if (permission != ContactsPermission.granted) {
      setState(() => _isSyncing = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            permission == ContactsPermission.permanentlyDenied
                ? 'Contacts access is blocked. Enable it in Settings to find '
                      'your friends.'
                : 'Contacts access is needed to find your friends.',
          ),
          backgroundColor: AppColors.destructive,
        ),
      );
      return;
    }

    final contacts = await ContactsService.readContacts();
    if (!mounted) return;

    if (contacts.isEmpty) {
      setState(() => _isSyncing = false);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('No phone numbers found in your contacts.'),
          backgroundColor: AppColors.destructive,
        ),
      );
      return;
    }

    final payload = {
      'device_id': await DeviceService.deviceId(),
      'sync_started_at': DateTime.now().toUtc().toIso8601String(),
      'contacts': contacts,
    };

    final result = await ApiService.syncContacts(payload);
    if (!mounted) return;

    if (result != null) {
      await Provider.of<CircleState>(
        context,
        listen: false,
      ).loadContactsFromDirectory();
      if (!mounted) return;
      setState(() {
        _isSyncing = false;
        _syncStatus = _SyncStatus.done;
      });
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            result['message'] ?? 'Synced ${contacts.length} contacts.',
          ),
          backgroundColor: AppColors.teal,
        ),
      );
    } else {
      setState(() => _isSyncing = false);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Failed to sync contacts. Please try again.'),
          backgroundColor: AppColors.destructive,
        ),
      );
    }
  }

  /// Follow / unfollow, with the server's answer shown either way.
  ///
  /// Previously the pill called `CircleState.toggleFollow` directly and
  /// discarded its result, so a rejected or failed follow looked exactly
  /// like a successful one: nothing happened and nothing was said.
  Future<void> _handleToggleFollow(String id, String name) async {
    if (_pendingFollowIds.contains(id)) return;

    final messenger = ScaffoldMessenger.of(context);
    final circle = Provider.of<CircleState>(context, listen: false);

    setState(() => _pendingFollowIds.add(id));
    final result = await circle.toggleFollow(id);
    if (!mounted) return;
    setState(() => _pendingFollowIds.remove(id));

    messenger.showResult(
      result,
      onSuccess: 'Follow request sent to $name.',
      onFailure: 'Could not update your follow for $name.',
    );
  }

  /// Card-access sheet, in one of two modes.
  ///
  /// Approving a request and editing an existing follower's access pick from
  /// the same list and write the same set of card ids; only the endpoint and
  /// the wording differ, so they share a sheet rather than duplicating one.
  void _showCardAccessSheet(
    String followId,
    String requesterName, {
    _AccessMode mode = _AccessMode.approve,
    List<String> preselected = const [],
  }) {
    final authState = Provider.of<AuthState>(context, listen: false);
    final myCards = authState.user.cards;
    final List<String> selectedCards = List.of(preselected);

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
                  MonoLabel(
                    mode == _AccessMode.approve
                        ? 'APPROVE & PICK CARDS'
                        : 'MANAGE CARD ACCESS',
                    size: 10,
                    letterSpacing: 2.0,
                    color: AppColors.textDim,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Which cards would you like to show to $requesterName?',
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
                          label: mode == _AccessMode.approve
                              ? 'Approve'
                              : 'Save access',
                          height: 46,
                          onTap: () async {
                            // Captured before the pop: this context belongs
                            // to the sheet that is about to be torn down.
                            final messenger = ScaffoldMessenger.of(context);
                            final circle = Provider.of<CircleState>(
                              context,
                              listen: false,
                            );
                            Navigator.pop(context);

                            final result = mode == _AccessMode.approve
                                ? await circle.approveRequest(
                                    followId,
                                    selectedCards,
                                  )
                                : await ApiService.updateFollowPermissions(
                                    followId,
                                    selectedCards,
                                  );
                            if (!mounted) return;
                            if (result.ok) {
                              setState(
                                () => _permissions[followId] = selectedCards,
                              );
                              await circle.fetchFollowersAndFollowing();
                            }
                            messenger.showResult(
                              result,
                              onSuccess: mode == _AccessMode.approve
                                  ? 'Follow request approved.'
                                  : "Updated $requesterName's access.",
                              onFailure: mode == _AccessMode.approve
                                  ? 'Could not approve that request.'
                                  : 'Could not update access.',
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

  Future<void> _handleRejectRequest(
    String followId,
    String requesterName,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await Provider.of<CircleState>(
      context,
      listen: false,
    ).rejectRequest(followId);
    if (!mounted) return;
    messenger.showResult(
      result,
      onSuccess: 'Request from $requesterName rejected.',
      onFailure: 'Could not reject that request.',
    );
  }

  void _showInviteFriendsBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Consumer<CircleState>(
              builder: (context, circleState, child) {
                final inviteOnly = circleState.inviteOnlyFriends;
                return Container(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const MonoLabel(
                        'INVITE FRIENDS',
                        size: 11,
                        letterSpacing: 2.0,
                        color: AppColors.textDim,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      if (inviteOnly.isEmpty)
                        Expanded(
                          child: Center(
                            child: Text(
                              'No contacts to invite',
                              style: AppText.sans(14, color: AppColors.textDim),
                            ),
                          ),
                        )
                      else
                        Expanded(
                          child: ListView.separated(
                            controller: scrollController,
                            itemCount: inviteOnly.length,
                            separatorBuilder: (context, index) => const Divider(
                              color: AppColors.border,
                              height: 20,
                            ),
                            itemBuilder: (context, index) {
                              final friend = inviteOnly[index];
                              return Row(
                                children: [
                                  AvatarBubble(
                                    initials: friend.initials,
                                    size: 36,
                                    hue: AvatarHue.values[index % 4],
                                  ),
                                  const SizedBox(width: AppSpacing.md),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          friend.name,
                                          style: AppText.sans(
                                            13,
                                            weight: FontWeight.w500,
                                            color: AppColors.text,
                                          ),
                                        ),
                                        const SizedBox(height: 1),
                                        Text(
                                          friend.id,
                                          style: AppText.sans(
                                            11,
                                            color: AppColors.textDim,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  GestureDetector(
                                    onTap: () => ScaffoldMessenger.of(context)
                                        .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Invitation link sent to ${friend.name}!',
                                            ),
                                            backgroundColor: AppColors.teal,
                                          ),
                                        ),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(
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
                                        'Invite',
                                        style: AppText.sans(
                                          11.5,
                                          weight: FontWeight.w500,
                                          color: AppColors.gold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  /// Cards each follower may see, keyed by follow id.
  ///
  /// The follower list gives no permission data, so it is fetched per row
  /// when the Followers tab first opens. Small lists make that fine; a
  /// batch endpoint would be better if follower counts grow.
  final Map<String, List<String>> _permissions = {};
  bool _loadingPermissions = false;

  Future<void> _loadPermissions(List<Map<String, dynamic>> followers) async {
    if (_loadingPermissions) return;
    final missing = followers
        .map((f) => (f['follow_id'] ?? '').toString())
        .where((id) => id.isNotEmpty && !_permissions.containsKey(id))
        .toList();
    if (missing.isEmpty) return;

    setState(() => _loadingPermissions = true);
    for (final id in missing) {
      final allowed = await ApiService.getFollowPermissions(id);
      if (!mounted) return;
      if (allowed != null) _permissions[id] = allowed;
    }
    if (mounted) setState(() => _loadingPermissions = false);
  }

  String _permissionLine(String followId) {
    final allowed = _permissions[followId];
    if (allowed == null) return 'Checking access…';
    if (allowed.isEmpty) return "Can't see any of your cards";
    final names = Provider.of<AuthState>(context, listen: false).user.cards
        .where((c) => allowed.contains(c.id))
        .map((c) => c.name)
        .toList();
    if (names.isEmpty) {
      return 'Can see ${allowed.length} card${allowed.length == 1 ? '' : 's'}';
    }
    return 'Can see ${names.join(', ')}';
  }

  @override
  Widget build(BuildContext context) {
    final circleState = Provider.of<CircleState>(context);
    final incomingCount = circleState.incomingRequests.length;

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
                  0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const MonoLabel(
                                'YOUR CIRCLE',
                                size: 9.5,
                                letterSpacing: 1.8,
                                color: AppColors.textFaint,
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Network',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppText.sans(
                                  25,
                                  weight: FontWeight.w500,
                                  color: AppColors.text,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        _SyncButton(busy: _isSyncing, onTap: _handleManualSync),
                        const SizedBox(width: AppSpacing.sm),
                        _InviteButton(
                          onTap: () => _showInviteFriendsBottomSheet(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _NetworkTabs(
                      index: _tabIndex,
                      incomingCount: incomingCount,
                      onChanged: (i) {
                        setState(() => _tabIndex = i);
                        if (i == 1) {
                          _loadPermissions(circleState.followersList);
                        }
                      },
                    ),
                  ],
                ),
              ),

              if (_showSyncPrompt)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl,
                    AppSpacing.mdLg,
                    AppSpacing.xl,
                    0,
                  ),
                  child: _SyncPrompt(busy: _isSyncing, onSync: _performSync),
                ),

              Expanded(
                child: RefreshIndicator(
                  onRefresh: _handleRefresh,
                  color: AppColors.gold,
                  backgroundColor: AppColors.surface,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.xl,
                      AppSpacing.mdLg,
                      AppSpacing.xl,
                      0,
                    ),
                    child: switch (_tabIndex) {
                      0 => _buildFollowing(circleState),
                      1 => _buildFollowers(circleState),
                      2 => _buildRequests(circleState),
                      _ => _buildContacts(circleState),
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- lists

  Widget _shell({required String caption, required List<Widget> children}) {
    if (children.isEmpty) {
      return _EmptyTab(message: caption);
    }
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 108),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: Text(
            caption,
            style: AppText.sans(11.5, color: AppColors.textFaint),
          ),
        ),
        ...children,
      ],
    );
  }

  /// GET /follow/following
  Widget _buildFollowing(CircleState state) {
    final rows = state.followingList;
    return _shell(
      caption: rows.isEmpty
          ? 'You are not following anyone yet. Sync your contacts or invite a '
                'friend to get started.'
          : '${rows.length} ${rows.length == 1 ? 'person shares' : 'people share'} cards with you',
      children: [
        for (var i = 0; i < rows.length; i++)
          _NetworkRow(
            initials: _initialsOf(rows[i]['name'] ?? rows[i]['username']),
            hue: AvatarHue.values[i % AvatarHue.values.length],
            title: (rows[i]['name'] ?? 'Unknown').toString(),
            subtitle: '@${rows[i]['username'] ?? 'unknown'}',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _SmallButton(
                  label: 'Cards',
                  primary: true,
                  onTap: () => _showSharedCards(
                    (rows[i]['follow_id'] ?? '').toString(),
                    (rows[i]['name'] ?? 'They').toString(),
                  ),
                ),
                const SizedBox(width: 6),
                _SmallButton(
                  label: 'Unfollow',
                  onTap: () => _handleUnfollow(
                    (rows[i]['user_id'] ?? '').toString(),
                    (rows[i]['name'] ?? 'them').toString(),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// GET /follow/followers
  Widget _buildFollowers(CircleState state) {
    final rows = state.followersList;
    return _shell(
      caption: rows.isEmpty
          ? 'Nobody follows you yet.'
          : 'You choose what each follower can see',
      children: [
        for (var i = 0; i < rows.length; i++)
          _FollowerCard(
            initials: _initialsOf(rows[i]['name'] ?? rows[i]['username']),
            hue: AvatarHue.values[i % AvatarHue.values.length],
            name: (rows[i]['name'] ?? 'Unknown').toString(),
            username: (rows[i]['username'] ?? 'unknown').toString(),
            status: (rows[i]['status'] ?? '').toString(),
            permissionLine: _permissionLine(
              (rows[i]['follow_id'] ?? '').toString(),
            ),
            onEditAccess: () => _showCardAccessSheet(
              (rows[i]['follow_id'] ?? '').toString(),
              (rows[i]['name'] ?? 'them').toString(),
              mode: _AccessMode.edit,
              preselected:
                  _permissions[(rows[i]['follow_id'] ?? '').toString()] ??
                  const [],
            ),
          ),
      ],
    );
  }

  /// GET /follow/requests/incoming + /outgoing
  Widget _buildRequests(CircleState state) {
    final incoming = state.incomingRequests;
    final outgoing = state.outgoingRequests;

    if (incoming.isEmpty && outgoing.isEmpty) {
      return const _EmptyTab(message: 'No follow requests right now.');
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 108),
      children: [
        if (incoming.isNotEmpty) ...[
          const MonoLabel(
            'INCOMING',
            size: 9.5,
            letterSpacing: 1.8,
            color: AppColors.textFaint,
          ),
          const SizedBox(height: AppSpacing.md),
          for (var i = 0; i < incoming.length; i++)
            _IncomingCard(
              initials: _initialsOf(incoming[i]['follower_display_name']),
              hue: AvatarHue.values[i % AvatarHue.values.length],
              name: (incoming[i]['follower_display_name'] ?? 'Someone')
                  .toString(),
              message: (incoming[i]['request_message'] ?? '').toString(),
              onApprove: () => _showCardAccessSheet(
                (incoming[i]['follow_id'] ?? '').toString(),
                (incoming[i]['follower_display_name'] ?? 'them').toString(),
              ),
              onReject: () => _handleRejectRequest(
                (incoming[i]['follow_id'] ?? '').toString(),
                (incoming[i]['follower_display_name'] ?? 'them').toString(),
              ),
            ),
          const SizedBox(height: AppSpacing.xl),
        ],
        if (outgoing.isNotEmpty) ...[
          const MonoLabel(
            'SENT BY YOU',
            size: 9.5,
            letterSpacing: 1.8,
            color: AppColors.textFaint,
          ),
          const SizedBox(height: AppSpacing.md),
          for (var i = 0; i < outgoing.length; i++)
            _NetworkRow(
              initials: _initialsOf(outgoing[i]['following_display_name']),
              hue: AvatarHue.values[i % AvatarHue.values.length],
              title: (outgoing[i]['following_display_name'] ?? 'Unknown')
                  .toString(),
              subtitle: (outgoing[i]['status'] ?? 'PENDING').toString(),
              trailing: _SmallButton(
                label: 'Cancel',
                onTap: () => _handleCancelOutgoing(
                  (outgoing[i]['following_user_id'] ?? '').toString(),
                  (outgoing[i]['following_display_name'] ?? 'them').toString(),
                ),
              ),
            ),
        ],
      ],
    );
  }

  /// GET /user/contacts/directory
  Widget _buildContacts(CircleState state) {
    // Yourself and anyone who blocked you are not actionable, so they are
    // not listed.
    final rows =
        state.friends
            .where(
              (f) =>
                  f.action != ContactAction.self &&
                  f.action != ContactAction.blocked,
            )
            .toList()
          // Actionable first, invite-only last. Name breaks ties so the
          // order is stable across rebuilds rather than following whatever
          // sequence the directory happened to return.
          ..sort((a, b) {
            final byAction = a.action.sortPriority.compareTo(
              b.action.sortPriority,
            );
            if (byAction != 0) return byAction;
            return a.name.toLowerCase().compareTo(b.name.toLowerCase());
          });

    return _shell(
      caption: rows.isEmpty
          ? (_showSyncPrompt
                ? 'Sync your contacts to see who you already know here.'
                : 'No contacts matched yet.')
          : '${rows.where((f) => f.action.isMatchedUser).length} contacts matched',
      children: [
        for (var i = 0; i < rows.length; i++)
          _NetworkRow(
            initials: rows[i].initials,
            hue: AvatarHue.values[i % AvatarHue.values.length],
            title: rows[i].name,
            subtitle: rows[i].action == ContactAction.inviteOnly
                ? 'Not on CardCircle'
                : rows[i].username,
            trailing: _ContactAction(
              action: rows[i].action,
              busy: _pendingFollowIds.contains(rows[i].id),
              onFollow: () => _handleToggleFollow(rows[i].id, rows[i].name),
              onRespond: () => setState(() => _tabIndex = 2),
              onInvite: () => _showInviteFriendsBottomSheet(context),
            ),
          ),
      ],
    );
  }

  static String _initialsOf(dynamic name) {
    final s = (name ?? '').toString().trim();
    if (s.isEmpty) return 'C';
    return s[0].toUpperCase();
  }

  Future<void> _handleUnfollow(String userId, String name) async {
    final messenger = ScaffoldMessenger.of(context);
    final circle = Provider.of<CircleState>(context, listen: false);
    final result = await circle.toggleFollow(userId);
    if (!mounted) return;
    await circle.fetchFollowersAndFollowing();
    messenger.showResult(
      result,
      onSuccess: 'Unfollowed $name.',
      onFailure: 'Could not unfollow $name.',
    );
  }

  Future<void> _handleCancelOutgoing(String userId, String name) async {
    final messenger = ScaffoldMessenger.of(context);
    final circle = Provider.of<CircleState>(context, listen: false);
    final result = await circle.cancelOutgoing(userId);
    if (!mounted) return;
    messenger.showResult(
      result,
      onSuccess: 'Request to $name cancelled.',
      onFailure: 'Could not cancel that request.',
    );
  }

  /// GET /follow/following/{followId}/cards
  Future<void> _showSharedCards(String followId, String name) async {
    final messenger = ScaffoldMessenger.of(context);
    final cards = await ApiService.getSharedCards(followId);
    if (!mounted) return;

    if (cards == null) {
      messenger.showError("Could not load $name's cards.");
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MonoLabel(
              '${name.toUpperCase()} SHARES',
              size: 10,
              letterSpacing: 2,
              color: AppColors.textDim,
            ),
            const SizedBox(height: AppSpacing.lg),
            if (cards.isEmpty)
              Text(
                '$name has not shared any cards with you.',
                style: AppText.sans(13, color: AppColors.textDim),
              )
            else
              ...cards.map(
                (c) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Row(
                    children: [
                      const Icon(
                        PhosphorIconsRegular.creditCard,
                        size: 16,
                        color: AppColors.gold,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          (c['card_name'] ?? 'Card').toString(),
                          style: AppText.sans(13.5, color: AppColors.text),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }
}

/// The persistent contact-sync card.
///
/// This replaces the reliance on a one-shot dialog. Declining the dialog
/// used to be terminal: the prompt never returned, the manual button had
/// been removed, and Circle stayed empty for good. The card stays until a
/// sync actually succeeds.
class _SyncPrompt extends StatelessWidget {
  final bool busy;
  final Future<void> Function() onSync;

  const _SyncPrompt({required this.busy, required this.onSync});

  @override
  Widget build(BuildContext context) {
    return OutlinedSurface(
      background: AppColors.goldSurface,
      borderColor: AppColors.gold.withValues(alpha: 0.4),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          const Icon(
            PhosphorIconsRegular.addressBook,
            size: 20,
            color: AppColors.gold,
          ),
          const SizedBox(width: AppSpacing.mdLg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Find your circle',
                  style: AppText.sans(
                    13,
                    weight: FontWeight.w500,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Only phone numbers are sent, never shown to anyone.',
                  style: AppText.sans(
                    11.5,
                    color: AppColors.textDim,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          GestureDetector(
            onTap: busy ? null : onSync,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: 9,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadii.chip),
                color: busy ? AppColors.elevated : AppColors.gold,
              ),
              child: busy
                  ? const SizedBox(
                      width: 13,
                      height: 13,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.6,
                        color: AppColors.gold,
                      ),
                    )
                  : Text(
                      'Sync',
                      style: AppText.sans(
                        12,
                        weight: FontWeight.w600,
                        color: AppColors.background,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SyncButton extends StatelessWidget {
  final bool busy;
  final VoidCallback onTap;

  const _SyncButton({required this.busy, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (busy) {
      // Same footprint as the tile, so the header does not reflow mid-sync.
      return const SizedBox(
        width: 38,
        height: 38,
        child: Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 1.8,
              color: AppColors.gold,
            ),
          ),
        ),
      );
    }
    return IconTile(
      icon: PhosphorIconsRegular.arrowsClockwise,
      iconSize: 17,
      color: AppColors.textDim,
      onTap: onTap,
    );
  }
}

/// Tab strip for the network screen: Following · Followers · Requests ·
/// Contacts, each mapping to one endpoint.
class _NetworkTabs extends StatelessWidget {
  final int index;
  final int incomingCount;
  final ValueChanged<int> onChanged;

  const _NetworkTabs({
    required this.index,
    required this.incomingCount,
    required this.onChanged,
  });

  static const _labels = ['Following', 'Followers', 'Requests', 'Contacts'];

  @override
  Widget build(BuildContext context) {
    // A Row of equal-width pills rather than a scrolling strip: with four
    // tabs the last one sat off the right edge of a 390pt phone, so
    // Contacts was effectively undiscoverable.
    return Row(
      children: List.generate(_labels.length, (i) {
        final on = i == index;
        // Only Requests carries a count: it is the only tab with work
        // waiting on the user.
        final badge = i == 2 && incomingCount > 0;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i == _labels.length - 1 ? 0 : 6),
            child: GestureDetector(
              onTap: () => onChanged(i),
              child: Container(
                height: 34,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                  color: on
                      ? AppColors.gold.withValues(alpha: 0.12)
                      : Colors.transparent,
                  border: Border.all(
                    color: on ? AppColors.gold : AppColors.border,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        _labels[i],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.sans(
                          11.5,
                          weight: FontWeight.w500,
                          color: on ? AppColors.gold : AppColors.textDim,
                        ),
                      ),
                    ),
                    if (badge) ...[
                      const SizedBox(width: 4),
                      Container(
                        constraints: const BoxConstraints(minWidth: 15),
                        height: 15,
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          color: AppColors.gold,
                          borderRadius: BorderRadius.circular(AppRadii.pill),
                        ),
                        child: Text(
                          '$incomingCount',
                          style: AppText.mono(
                            8.5,
                            ls: 0,
                            w: FontWeight.w700,
                            c: AppColors.background,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

/// A plain person row: avatar, name, one line of detail, a trailing action.
class _NetworkRow extends StatelessWidget {
  final String initials;
  final AvatarHue hue;
  final String title;
  final String subtitle;
  final Widget trailing;

  const _NetworkRow({
    required this.initials,
    required this.hue,
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: OutlinedSurface(
        padding: const EdgeInsets.all(AppSpacing.mdLg),
        child: Row(
          children: [
            AvatarBubble(initials: initials, size: 40, hue: hue),
            const SizedBox(width: AppSpacing.mdLg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.sans(
                      13.5,
                      weight: FontWeight.w500,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 3),
                  MonoLabel(
                    subtitle,
                    size: 9.5,
                    letterSpacing: 1,
                    color: AppColors.textFaint,
                    uppercase: false,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            trailing,
          ],
        ),
      ),
    );
  }
}

/// A follower, with what they are allowed to see and a way to change it.
class _FollowerCard extends StatelessWidget {
  final String initials;
  final AvatarHue hue;
  final String name;
  final String username;
  final String status;
  final String permissionLine;
  final VoidCallback onEditAccess;

  const _FollowerCard({
    required this.initials,
    required this.hue,
    required this.name,
    required this.username,
    required this.status,
    required this.permissionLine,
    required this.onEditAccess,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: OutlinedSurface(
        padding: const EdgeInsets.all(AppSpacing.mdLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AvatarBubble(initials: initials, size: 40, hue: hue),
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
                      const SizedBox(height: 3),
                      MonoLabel(
                        '@$username',
                        size: 9.5,
                        letterSpacing: 1,
                        color: AppColors.textFaint,
                        uppercase: false,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (status.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: MonoLabel(
                      status,
                      size: 8.5,
                      letterSpacing: 1.1,
                      color: AppColors.textDim,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            const Divider(color: AppColors.border, height: 1),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: Text(
                    permissionLine,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.sans(11.5, color: AppColors.textDim),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                _SmallButton(label: 'Edit access', onTap: onEditAccess),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// An incoming follow request, with the optional message they sent.
class _IncomingCard extends StatelessWidget {
  final String initials;
  final AvatarHue hue;
  final String name;
  final String message;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _IncomingCard({
    required this.initials,
    required this.hue,
    required this.name,
    required this.message,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: OutlinedSurface(
        padding: const EdgeInsets.all(AppSpacing.mdLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AvatarBubble(initials: initials, size: 40, hue: hue),
                const SizedBox(width: AppSpacing.mdLg),
                Expanded(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.sans(
                      13.5,
                      weight: FontWeight.w500,
                      color: AppColors.text,
                    ),
                  ),
                ),
              ],
            ),
            if (message.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                message,
                style: AppText.sans(12, color: AppColors.textDim, height: 1.5),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: _SmallButton(
                    label: 'Approve & pick cards',
                    primary: true,
                    onTap: onApprove,
                    expand: true,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                _SmallButton(label: 'Reject', onTap: onReject),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The trailing control on a contact row, chosen by relationship state.
class _ContactAction extends StatelessWidget {
  final ContactAction action;
  final bool busy;
  final VoidCallback onFollow;
  final VoidCallback onRespond;
  final VoidCallback onInvite;

  const _ContactAction({
    required this.action,
    required this.busy,
    required this.onFollow,
    required this.onRespond,
    required this.onInvite,
  });

  @override
  Widget build(BuildContext context) {
    if (busy) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 1.8,
          color: AppColors.gold,
        ),
      );
    }

    switch (action) {
      case ContactAction.follow:
        return _SmallButton(label: 'Follow', primary: true, onTap: onFollow);
      case ContactAction.requestSent:
        // Tapping withdraws the request, matching the outgoing tab.
        return _SmallButton(label: 'Requested', onTap: onFollow);
      case ContactAction.requestReceived:
        return _SmallButton(label: 'Respond', primary: true, onTap: onRespond);
      case ContactAction.following:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.pill),
            border: Border.all(color: AppColors.border),
          ),
          child: MonoLabel(
            'FOLLOWING',
            size: 8.5,
            letterSpacing: 1.1,
            color: AppColors.textDim,
          ),
        );
      case ContactAction.inviteOnly:
        return _SmallButton(label: 'Invite', onTap: onInvite);
      case ContactAction.self:
      case ContactAction.blocked:
        return const SizedBox.shrink();
    }
  }
}

/// Compact button used across the network rows.
class _SmallButton extends StatelessWidget {
  final String label;
  final bool primary;
  final bool expand;
  final VoidCallback onTap;

  const _SmallButton({
    required this.label,
    required this.onTap,
    this.primary = false,
    this.expand = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 32,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadii.pill),
          color: primary
              ? AppColors.gold.withValues(alpha: 0.12)
              : Colors.transparent,
          border: Border.all(
            color: primary ? AppColors.gold : AppColors.border,
          ),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppText.sans(
            11.5,
            weight: FontWeight.w500,
            color: primary ? AppColors.gold : AppColors.textDim,
          ),
        ),
      ),
    );
  }
}

/// Invite control in the header.
class _InviteButton extends StatelessWidget {
  final VoidCallback onTap;

  const _InviteButton({required this.onTap});

  @override
  Widget build(BuildContext context) => IconTile(
    icon: PhosphorIconsRegular.userPlus,
    iconSize: 18,
    color: AppColors.gold,
    onTap: onTap,
  );
}

/// Centred message for a tab with nothing in it.
class _EmptyTab extends StatelessWidget {
  final String message;

  const _EmptyTab({required this.message});

  @override
  Widget build(BuildContext context) {
    // Scrollable so pull-to-refresh still works on an empty tab.
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 24),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: AppText.sans(13, color: AppColors.textDim, height: 1.45),
          ),
        ),
      ],
    );
  }
}
