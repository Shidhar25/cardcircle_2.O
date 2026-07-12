import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../circle/state/circle_state.dart';
import '../../auth/state/auth_state.dart';
import '../../../shared/widgets/neo_pop_button.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _isLoading = false;

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
                              _isLoading = true;
                            });
                            final circleState = Provider.of<CircleState>(context, listen: false);
                            final ok = await circleState.approveRequest(followId, selectedCards);
                            setState(() {
                              _isLoading = false;
                            });
                            if (mounted) {
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

  @override
  Widget build(BuildContext context) {
    final circleState = Provider.of<CircleState>(context);
    final requests = circleState.incomingRequests;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Notifications',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(AppColors.primary)))
          : requests.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.notifications_none_rounded,
                        size: 48,
                        color: AppColors.mutedForeground,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No new notifications',
                        style: TextStyle(
                          color: AppColors.mutedForeground,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: requests.length,
                  separatorBuilder: (context, index) => const Divider(color: AppColors.border, height: 20),
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
                                '@$username wants to follow you',
                                style: const TextStyle(color: AppColors.mutedForeground, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () async {
                            setState(() {
                              _isLoading = true;
                            });
                            final ok = await circleState.rejectRequest(followId);
                            setState(() {
                              _isLoading = false;
                            });
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(ok ? 'Follow request rejected for $name.' : 'Failed to reject request.'),
                                  backgroundColor: ok ? AppColors.green : Colors.red,
                                ),
                              );
                            }
                          },
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
    );
  }
}
