import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/api_service.dart';
import '../../auth/state/auth_state.dart';
import '../state/circle_state.dart';
import '../../../shared/widgets/friend_item.dart';

class CircleScreen extends StatefulWidget {
  const CircleScreen({super.key});

  @override
  State<CircleScreen> createState() => _CircleScreenState();
}

class _CircleScreenState extends State<CircleScreen> {
  String _activeTab = 'my_circle';
  bool _isSyncing = false;
  bool _contactSyncNeeded = false;

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
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _performSync();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Allow', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
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

  @override
  Widget build(BuildContext context) {
    final circleState = Provider.of<CircleState>(context);
    final authState = Provider.of<AuthState>(context);

    final friends = circleState.friends;

    // Filter
    final myCircle = friends.where((f) => f.isFollowing).toList();
    final discoverFriends = friends.where((f) => !f.isFollowing).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header stats view
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border, width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'CIRCLE INSIGHTS',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.mutedForeground,
                      letterSpacing: 2.0,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            myCircle.length.toString(),
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Active Circle',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.mutedForeground,
                            ),
                          ),
                        ],
                      ),
                      Container(width: 1, height: 32, color: AppColors.border),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            '₹48,400',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: AppColors.green,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Circle Savings',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.mutedForeground,
                            ),
                          ),
                        ],
                      ),
                      Container(width: 1, height: 32, color: AppColors.border),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            authState.user.cards.length.toString(),
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: AppColors.gold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Unique Cards',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.mutedForeground,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Your circle has unlocked access to premium tips and shared benefit codes automatically.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.72),
                      fontSize: 12,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),

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
                            'My Circle (${myCircle.length})',
                            style: TextStyle(
                              color: _activeTab == 'my_circle'
                                  ? AppColors.background
                                  : AppColors.mutedForeground,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
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
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_contactSyncNeeded)
              Container(
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
                    ElevatedButton(
                      onPressed: _isSyncing ? null : _showSyncDialog,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: _isSyncing
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.black)),
                            )
                          : const Text('Sync', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 10),

            // Tab Content
            Expanded(
              child: _activeTab == 'my_circle'
                  ? (myCircle.isEmpty
                      ? _buildEmptyState('Your circle is currently empty. Follow other savers to grow!')
                      : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 20),
                          itemCount: myCircle.length,
                          itemBuilder: (context, idx) {
                            final friend = myCircle[idx];
                            return FriendItem(
                              friend: friend,
                              onToggleFollow: () => circleState.toggleFollow(friend.id),
                            );
                          },
                        ))
                  : (discoverFriends.isEmpty
                      ? _buildEmptyState('You are following all available savers!')
                      : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 20),
                          itemCount: discoverFriends.length,
                          itemBuilder: (context, idx) {
                            final friend = discoverFriends[idx];
                            return FriendItem(
                              friend: friend,
                              onToggleFollow: () => circleState.toggleFollow(friend.id),
                            );
                          },
                        )),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String msg) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40.0),
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
}
