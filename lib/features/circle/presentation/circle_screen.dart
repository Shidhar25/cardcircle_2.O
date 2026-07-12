import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/api_service.dart';
import '../../auth/state/auth_state.dart';
import '../state/circle_state.dart';
import '../../../shared/widgets/friend_item.dart';
import '../../../shared/widgets/neo_pop_button.dart';

class CircleScreen extends StatefulWidget {
  const CircleScreen({super.key});

  @override
  State<CircleScreen> createState() => _CircleScreenState();
}

class _CircleScreenState extends State<CircleScreen> {
  String _activeTab = 'followers';
  bool _isSyncing = false;
  bool _contactSyncNeeded = false;

  Future<void> _handleRefresh() async {
    final circleState = Provider.of<CircleState>(context, listen: false);
    final authState = Provider.of<AuthState>(context, listen: false);
    await Future.wait([
      circleState.loadContactsFromDirectory(),
      authState.refreshProfileFromServer(),
    ]);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkSyncNeeded();
    });
  }

  Future<void> _checkSyncNeeded() async {
    final dash = await ApiService.getDashboard();
    if (dash != null) {
      final syncNeeded = dash['iscontactsyncneeded'] ?? false;
      setState(() {
        _contactSyncNeeded = syncNeeded;
      });
      if (syncNeeded) {
        _showSyncDialog();
      } else {
        if (!mounted) return;
        final circleState = Provider.of<CircleState>(context, listen: false);
        circleState.loadContactsFromDirectory();
      }
    }
  }

  void _showSyncDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Sync Contacts', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text(
          'CardCircle needs to sync your contacts to match you with friends already using the app. Your data is encrypted and secure.',
          style: TextStyle(color: AppColors.mutedForeground),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _contactSyncNeeded = true;
              });
            },
            child: const Text('Deny', style: TextStyle(color: AppColors.mutedForeground)),
          ),
          NeoPopButton.primary(
            onPressed: () {
              Navigator.pop(context);
              _performSync();
            },
            fullWidth: false,
            depth: 4.0,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: const NeoPopButtonText('Allow', color: Color(0xFF050505), fontSize: 14),
          ),
        ],
      ),
    );
  }

  Future<void> _performSync() async {
    setState(() {
      _isSyncing = true;
    });

    final payload = {
      "device_id": "abc123device",
      "sync_started_at": DateTime.now().toIso8601String(),
      "contacts": [
        {
          "mobile_number": "+919665389975",
          "contact_name": "ghcghc"
        },
        {
          "mobile_number": "+919665389974",
          "contact_name": "Shridhar Hande"
        },
        {
          "mobile_number": "+919923506233",
          "contact_name": "Yashavant Dudhal"
        }
      ]
    };

    final result = await ApiService.syncContacts(payload);
    if (result != null) {
      if (!mounted) return;
      final circleState = Provider.of<CircleState>(context, listen: false);
      await circleState.loadContactsFromDirectory();
      setState(() {
        _contactSyncNeeded = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Contacts synced successfully!'),
            backgroundColor: AppColors.green,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to sync contacts. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    setState(() {
      _isSyncing = false;
    });
  }

  void _showCardAccessSheet(String followId, String requesterName) {
    final authState = Provider.of<AuthState>(context, listen: false);
    final myCards = authState.user.cards;
    final List<String> selectedCards = [];

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
                left: 24,
                right: 24,
                top: 24,
                bottom: 24 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'MANAGE CARD ACCESS',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.mutedForeground,
                      letterSpacing: 2.0,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Which cards would you like to show to $requesterName?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (myCards.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20.0),
                      child: Center(
                        child: Text(
                          'You have no cards added yet. Approving will share no cards.',
                          style: TextStyle(color: AppColors.mutedForeground, fontSize: 13),
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
                              color: AppColors.card,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? AppColors.primary : AppColors.border,
                                width: isSelected ? 1.5 : 1.0,
                              ),
                            ),
                            child: CheckboxListTile(
                              value: isSelected,
                              activeColor: AppColors.primary,
                              checkColor: Colors.black,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              title: Text(
                                card.name,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                              ),
                              subtitle: Text(
                                card.bank,
                                style: const TextStyle(color: AppColors.mutedForeground, fontSize: 11),
                              ),
                              secondary: Container(
                                width: 36,
                                height: 24,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(4),
                                  gradient: LinearGradient(colors: card.gradientColors),
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
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel', style: TextStyle(color: AppColors.mutedForeground, fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: NeoPopButton.primary(
                          onPressed: () async {
                            Navigator.pop(context);
                            setState(() {
                              _isSyncing = true;
                            });
                            final circleState = Provider.of<CircleState>(context, listen: false);
                            final ok = await circleState.approveRequest(followId, selectedCards);
                            setState(() {
                              _isSyncing = false;
                            });
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(ok ? 'Follow request approved!' : 'Failed to approve request.'),
                                  backgroundColor: ok ? AppColors.green : Colors.red,
                                ),
                              );
                            }
                          },
                          fullWidth: true,
                          depth: 4.0,
                          child: const NeoPopButtonText('Approve', color: Color(0xFF050505), fontSize: 14),
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

  Future<void> _handleRejectRequest(String followId, String requesterName) async {
    setState(() {
      _isSyncing = true;
    });
    final circleState = Provider.of<CircleState>(context, listen: false);
    final ok = await circleState.rejectRequest(followId);
    setState(() {
      _isSyncing = false;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? 'Follow request rejected for $requesterName.' : 'Failed to reject request.'),
          backgroundColor: ok ? AppColors.green : Colors.red,
        ),
      );
    }
  }

  Widget _buildIncomingRequestsSection(List<Map<String, dynamic>> requests) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'FOLLOW REQUESTS',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.mutedForeground,
                  letterSpacing: 2.0,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  requests.length.toString(),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: requests.length,
            separatorBuilder: (context, index) => const Divider(color: AppColors.border, height: 16),
            itemBuilder: (context, index) {
              final req = requests[index];
              final followId = req['follow_id'] ?? '';
              final name = req['follower_display_name'] ?? req['name'] ?? 'Unknown Saver';
              final username = req['follower_username'] ?? req['username'] ?? name.toLowerCase().replaceAll(' ', '');

              String initials = 'C';
              if (name.isNotEmpty) {
                try {
                  final clean = name.trim().replaceAll(RegExp(r'[^\w]'), '');
                  initials = clean.isNotEmpty ? clean[0].toUpperCase() : 'C';
                } catch (_) {}
              }

              return Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      initials,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          '@$username',
                          style: const TextStyle(color: AppColors.mutedForeground, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => _handleRejectRequest(followId, name),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    child: const Text(
                      'Reject',
                      style: TextStyle(color: AppColors.mutedForeground, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 4),
                  NeoPopButton.primary(
                    onPressed: () => _showCardAccessSheet(followId, name),
                    fullWidth: false,
                    depth: 3.0,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: const NeoPopButtonText('Approve', color: Color(0xFF050505), fontSize: 11),
                  ),
                ],
              );
            },
          ),
        ],
      ),
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
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'INVITE FRIENDS',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.mutedForeground,
                          letterSpacing: 2.0,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (inviteOnly.isEmpty)
                        const Expanded(
                          child: Center(
                            child: Text(
                              'No contacts to invite',
                              style: TextStyle(color: AppColors.mutedForeground, fontSize: 14),
                            ),
                          ),
                        )
                      else
                        Expanded(
                          child: ListView.separated(
                            controller: scrollController,
                            itemCount: inviteOnly.length,
                            separatorBuilder: (context, index) => const Divider(color: AppColors.border, height: 20),
                            itemBuilder: (context, index) {
                              final friend = inviteOnly[index];
                              return Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(
                                        colors: [Color(0xFFFC5C7D), Color(0xFF6A82FB)],
                                      ),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      friend.initials,
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          friend.name,
                                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                        ),
                                        const SizedBox(height: 1),
                                        Text(
                                          friend.id, // Phone number
                                          style: const TextStyle(color: AppColors.mutedForeground, fontSize: 11),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  NeoPopButton(
                                    onPressed: () {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Invitation link sent to ${friend.name}!'),
                                          backgroundColor: AppColors.green,
                                        ),
                                      );
                                    },
                                    style: NeoPopButtonStyle.flat,
                                    color: AppColors.primary,
                                    shadowColor: const Color(0xFF008899),
                                    depth: 2.0,
                                    fullWidth: false,
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    child: const Text(
                                      'Invite',
                                      style: TextStyle(
                                        color: Color(0xFF050505),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
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

  Widget _buildSuggestedFriendsRow(CircleState circleState) {
    final suggestions = circleState.suggestedFriends;
    if (suggestions.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Text(
            'Suggested Friends',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ),
        SizedBox(
          height: 170,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            itemCount: suggestions.length,
            itemBuilder: (context, index) {
              final friend = suggestions[index];
              return Container(
                width: 130,
                margin: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 4.0),
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border, width: 1),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: friend.gradientColors,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        friend.initials,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      friend.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      friend.username,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.mutedForeground,
                        fontSize: 9,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 28,
                      child: NeoPopButton(
                        onPressed: () async {
                          final success = await circleState.toggleFollow(friend.id);
                          if (success && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Sent follow request to ${friend.name}!'),
                                backgroundColor: AppColors.green,
                              ),
                            );
                          } else if (!success && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Failed to send follow request.'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                        style: NeoPopButtonStyle.flat,
                        color: AppColors.primary,
                        shadowColor: const Color(0xFF008899),
                        depth: 3.0,
                        fullWidth: true,
                        padding: EdgeInsets.zero,
                        child: const Center(
                          child: Text(
                            'Follow',
                            style: TextStyle(
                              color: Color(0xFF050505),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildEmptyState(String msg) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.people_outline_rounded, size: 40, color: AppColors.mutedForeground),
            const SizedBox(height: 12),
            Text(
              msg,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.mutedForeground, fontSize: 13, height: 1.45),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final circleState = Provider.of<CircleState>(context);
    final friends = circleState.friends;

    // Filter
    final myCircle = friends.where((f) => f.isFollowing).toList();
    final discoverFriends = friends.where((f) => !f.isFollowing).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _handleRefresh,
          color: AppColors.primary,
          backgroundColor: AppColors.card,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
            SliverToBoxAdapter(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Top Header Bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'My Circle',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: -1.0,
                          ),
                        ),
                        IconButton(
                          onPressed: () => _showInviteFriendsBottomSheet(context),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(
                            Icons.person_add_alt_1_rounded,
                            color: AppColors.primary,
                            size: 28,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  if (circleState.incomingRequests.isNotEmpty)
                    _buildIncomingRequestsSection(circleState.incomingRequests),
                  // Tabs toggle bar
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                    padding: const EdgeInsets.all(4.0),
                    decoration: BoxDecoration(
                      color: AppColors.elevated,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _activeTab = 'followers';
                              });
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: _activeTab == 'followers' ? AppColors.primary : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(
                                child: Text(
                                  'Followers',
                                  style: TextStyle(
                                    color: _activeTab == 'followers'
                                        ? AppColors.background
                                        : AppColors.mutedForeground,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _activeTab = 'my_circle';
                              });
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: _activeTab == 'my_circle' ? AppColors.primary : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(
                                child: Text(
                                  'Following',
                                  style: TextStyle(
                                    color: _activeTab == 'my_circle'
                                        ? AppColors.background
                                        : AppColors.mutedForeground,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _activeTab = 'discover';
                              });
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: _activeTab == 'discover' ? AppColors.primary : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(
                                child: Text(
                                  'Find Friends',
                                  style: TextStyle(
                                    color: _activeTab == 'discover'
                                        ? AppColors.background
                                        : AppColors.mutedForeground,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                ],
              ),
            ),
            if (_contactSyncNeeded)
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.primary, width: 1),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.contacts_rounded, color: AppColors.primary, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Sync Contacts',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Find your friends and see what cards they carry.',
                              style: TextStyle(color: AppColors.mutedForeground, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      NeoPopButton.primary(
                        onPressed: _isSyncing ? null : _showSyncDialog,
                        isLoading: _isSyncing,
                        fullWidth: false,
                        depth: 4.0,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: const NeoPopButtonText('Sync', color: Color(0xFF050505), fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),

            // Tab Content Lists
            if (_activeTab == 'my_circle')
              (myCircle.isEmpty
                  ? SliverToBoxAdapter(
                      child: _buildEmptyState('Your circle is currently empty. Follow other savers to grow!'),
                    )
                  : SliverPadding(
                      padding: const EdgeInsets.only(bottom: 12),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, idx) {
                            final friend = myCircle[idx];
                            return FriendItem(
                              friend: friend,
                              onToggleFollow: () async {
                                final success = await circleState.toggleFollow(friend.id);
                                if (!success && context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Failed to update follow request. Please try again.'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              },
                            );
                          },
                          childCount: myCircle.length,
                        ),
                      ),
                    ))
            else if (_activeTab == 'followers')
              (circleState.followersList.isEmpty
                  ? SliverToBoxAdapter(
                      child: _buildEmptyState('No one is following you yet.'),
                    )
                  : SliverPadding(
                      padding: const EdgeInsets.only(bottom: 12),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, idx) {
                            final follower = circleState.followersList[idx];
                            final String followerId = follower['user_id'] ?? '';
                            final String name = follower['name'] ?? 'Unknown';
                            final String username = follower['username'] ?? 'unknown';
                            final bool isFollowingBack = myCircle.any((f) => f.id == followerId);

                            String initials = 'C';
                            if (name.isNotEmpty) {
                              try {
                                final clean = name.trim().replaceAll(RegExp(r'[^\w]'), '');
                                initials = clean.isNotEmpty ? clean[0].toUpperCase() : 'C';
                              } catch (_) {}
                            }

                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppColors.card,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppColors.border, width: 1),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(
                                        colors: [Color(0xFF00C6FF), Color(0xFF0072FF)],
                                      ),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      initials,
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name,
                                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '@$username',
                                          style: const TextStyle(color: AppColors.mutedForeground, fontSize: 11),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  NeoPopButton(
                                    onPressed: () async {
                                      final success = await circleState.toggleFollow(followerId);
                                      if (!success && context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Failed to update follow request. Please try again.'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    },
                                    style: NeoPopButtonStyle.flat,
                                    color: isFollowingBack ? Colors.transparent : AppColors.primary,
                                    shadowColor: isFollowingBack ? Colors.transparent : const Color(0xFF008899),
                                    depth: isFollowingBack ? 0 : 4.0,
                                    fullWidth: false,
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    child: Text(
                                      isFollowingBack ? 'Following' : 'Follow',
                                      style: TextStyle(
                                        color: isFollowingBack ? AppColors.mutedForeground : const Color(0xFF050505),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                          childCount: circleState.followersList.length,
                        ),
                      ),
                    ))
            else
              (discoverFriends.isEmpty
                  ? SliverToBoxAdapter(
                      child: _buildEmptyState('You are following all available savers!'),
                    )
                  : SliverPadding(
                      padding: const EdgeInsets.only(bottom: 12),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, idx) {
                            final friend = discoverFriends[idx];
                            return FriendItem(
                              friend: friend,
                              onToggleFollow: () async {
                                final success = await circleState.toggleFollow(friend.id);
                                if (!success && context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Failed to update follow request. Please try again.'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              },
                            );
                          },
                          childCount: discoverFriends.length,
                        ),
                      ),
                    )),

            // Suggested Friends Carousel at the very bottom
            SliverToBoxAdapter(
              child: _buildSuggestedFriendsRow(circleState),
            ),
          ],
        ),
      ),
      ),
    );
  }
}
