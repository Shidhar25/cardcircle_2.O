import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/api_service.dart';
import '../../../shared/models/hack.dart';

class FaqModel {
  final String question;
  final String answer;

  FaqModel({required this.question, required this.answer});

  factory FaqModel.fromJson(Map<String, dynamic> json) {
    return FaqModel(
      question: json['question']?.toString() ?? '',
      answer: json['answer']?.toString() ?? '',
    );
  }
}

class HowToApplyScreen extends StatefulWidget {
  const HowToApplyScreen({super.key});

  @override
  State<HowToApplyScreen> createState() => _HowToApplyScreenState();
}

class _HowToApplyScreenState extends State<HowToApplyScreen> {
  List<FaqModel> _faqs = [];
  bool _isLoadingFaqs = true;
  int? _expandedFaqIndex;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchFaqs();
    });
  }

  Future<void> _fetchFaqs() async {
    final hack = ModalRoute.of(context)?.settings.arguments as Hack?;
    if (hack == null) {
      setState(() => _isLoadingFaqs = false);
      return;
    }

    final rawFaqs = await ApiService.getFaqFromHackId(hack.id);
    if (mounted) {
      setState(() {
        if (rawFaqs != null && rawFaqs.isNotEmpty) {
          _faqs = rawFaqs.map((e) => FaqModel.fromJson(e)).toList();
        } else {
          // Fallback seed FAQs if API list empty
          _faqs = [
            FaqModel(
              question: 'Is this hack applicable to all cards?',
              answer: 'No, this hack is specifically optimized for ${hack.cardName}.',
            ),
            FaqModel(
              question: 'What is the maximum savings limit per month?',
              answer: 'You can earn maximum rewards up to card monthly caps as per terms.',
            ),
            FaqModel(
              question: 'Are there any redemption fees?',
              answer: 'Certain point conversions may carry a minimal fee (e.g. Rs. 99 + GST), so redeem in bulk.',
            ),
          ];
        }
        _isLoadingFaqs = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hack = ModalRoute.of(context)?.settings.arguments as Hack? ??
        Hack(
          id: '9e8b7d0b-6c97-4d56-9b7d-6de1d5f1d341',
          name: 'Amazon - 5% Cashback',
          heading: 'Buy Amazon Pay Gift Cards using SBI Cashback Card.',
          steps: [
            HackStep(
              name: 'Step 1',
              heading: 'Check Eligibility First',
              icon: '📋',
              description:
                  'Make sure your credit score is above 720 and you haven\'t applied for a similar card in the last 6 months.',
            ),
            HackStep(
              name: 'Step 2',
              heading: 'Prepare Your Documents',
              icon: '📁',
              description:
                  'Keep your PAN card, Aadhaar, salary slips (last 3 months), and bank statements ready for quick upload.',
            ),
            HackStep(
              name: 'Step 3',
              heading: 'Use the Referral Link',
              icon: '🔗',
              description:
                  'Apply through our verified referral link to unlock exclusive signup bonuses and accelerated approval.',
            ),
          ],
          cards: ['SBI Cashback'],
          savings: '5% Cashback',
          category: 'Shopping',
          rating: 4.7,
          availedby: '102 people availed',
          thingsToNote: [],
        );

    final displaySteps = hack.steps.isNotEmpty
        ? hack.steps
        : [
            HackStep(
              name: 'Step 1',
              heading: 'Check Eligibility First',
              icon: '📋',
              description:
                  'Make sure your credit score is above 720 and you haven\'t applied for a similar card in the last 6 months.',
            ),
            HackStep(
              name: 'Step 2',
              heading: 'Prepare Your Documents',
              icon: '📁',
              description:
                  'Keep your PAN card, Aadhaar, salary slips (last 3 months), and bank statements ready for quick upload.',
            ),
            HackStep(
              name: 'Step 3',
              heading: 'Use the Referral Link',
              icon: '🔗',
              description:
                  'Apply through our verified referral link to unlock exclusive signup bonuses and accelerated approval.',
            ),
          ];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.border, width: 1),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.chevron_left_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'How to Apply',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${hack.name} - ${hack.savings}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.mutedForeground,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // Summary Banner Card
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16.0),
                height: 180,
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border, width: 1),
                  image: const DecorationImage(
                    image: NetworkImage(
                      'https://images.unsplash.com/photo-1559526324-4b87b5e36e44?auto=format&fit=crop&w=600&q=80',
                    ),
                    fit: BoxFit.cover,
                    opacity: 0.25,
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.85),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Text(
                              hack.category.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                ...List.generate(
                                  5,
                                  (i) => const Icon(Icons.star_rounded,
                                      color: Color(0xFFFFD700), size: 14),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${hack.rating} (102)',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            hack.name,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.elevated,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              hack.cardName,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white70,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ).animate().fade(duration: 400.ms).slideY(begin: 0.05, curve: Curves.easeOutQuad),

              const SizedBox(height: 24),

              // Steps Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Container(
                  padding: const EdgeInsets.all(20.0),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border, width: 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.list_alt_rounded,
                              size: 22, color: AppColors.primary),
                          SizedBox(width: 10),
                          Text(
                            'Steps',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Steps Timeline List
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: displaySteps.length,
                        itemBuilder: (context, idx) {
                          final step = displaySteps[idx];
                          final isLast = idx == displaySteps.length - 1;
                          final stepNum = idx + 1;

                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Timeline Node & Line
                              Column(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: AppColors.primary.withValues(alpha: 0.12),
                                      border: Border.all(
                                        color: AppColors.primary,
                                        width: 1.5,
                                      ),
                                    ),
                                    alignment: Alignment.center,
                                    child: _getStepIcon(idx, step.icon),
                                  ),
                                  if (!isLast)
                                    Container(
                                      width: 2,
                                      height: 90,
                                      color: AppColors.primary.withValues(alpha: 0.3),
                                    ),
                                ],
                              ),
                              const SizedBox(width: 14),

                              // Step Card Content
                              Expanded(
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 16),
                                  padding: const EdgeInsets.all(16.0),
                                  decoration: BoxDecoration(
                                    color: AppColors.elevated,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                        color: AppColors.border, width: 1),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'STEP $stepNum',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primary,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        step.heading,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        step.description,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: AppColors.mutedForeground,
                                          height: 1.4,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ).animate().fade(delay: 200.ms, duration: 400.ms).slideY(begin: 0.05, curve: Curves.easeOutQuad),

              const SizedBox(height: 24),

              // FAQ Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.help_outline_rounded,
                            size: 22, color: AppColors.primary),
                        SizedBox(width: 10),
                        Text(
                          'FAQ',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    if (_isLoadingFaqs)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24.0),
                          child: CircularProgressIndicator(color: AppColors.primary),
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _faqs.length,
                        itemBuilder: (context, faqIdx) {
                          final faq = _faqs[faqIdx];
                          final isExpanded = _expandedFaqIndex == faqIdx;
                          final number = faqIdx + 1;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10.0),
                            decoration: BoxDecoration(
                              color: AppColors.card,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.border, width: 1),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Column(
                              children: [
                                InkWell(
                                  onTap: () {
                                    setState(() {
                                      _expandedFaqIndex =
                                          isExpanded ? null : faqIdx;
                                    });
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Row(
                                    children: [
                                      Container(
                                        width: 28,
                                        height: 28,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: AppColors.primary
                                              .withValues(alpha: 0.15),
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          '$number',
                                          style: const TextStyle(
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          faq.question,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      Icon(
                                        isExpanded
                                            ? Icons.keyboard_arrow_up_rounded
                                            : Icons.chevron_right_rounded,
                                        color: AppColors.mutedForeground,
                                        size: 20,
                                      ),
                                    ],
                                  ),
                                ),
                                ),
                                if (isExpanded)
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.only(
                                        left: 56.0, right: 16.0, bottom: 16.0),
                                    child: Text(
                                      faq.answer,
                                      style: const TextStyle(
                                        color: AppColors.mutedForeground,
                                        fontSize: 13,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ).animate().fade(delay: 350.ms, duration: 400.ms).slideY(begin: 0.05, curve: Curves.easeOutQuad),
            ],
          ),
        ),
      ),
    );
  }

  Widget _getStepIcon(int idx, String emojiIcon) {
    if (idx == 0) {
      return const Icon(Icons.assignment_turned_in_outlined,
          color: AppColors.primary, size: 20);
    } else if (idx == 1) {
      return const Icon(Icons.folder_open_rounded,
          color: AppColors.primary, size: 20);
    } else if (idx == 2) {
      return const Icon(Icons.link_rounded, color: AppColors.primary, size: 20);
    } else {
      return Text(
        emojiIcon.isNotEmpty ? emojiIcon : '💡',
        style: const TextStyle(fontSize: 18),
      );
    }
  }
}
