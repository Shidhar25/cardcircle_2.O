import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/api_service.dart';
import '../../../shared/models/hack.dart';
import '../../../shared/widgets/gritty_background.dart';

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
          _faqs = [];
        }
        _isLoadingFaqs = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hack = ModalRoute.of(context)?.settings.arguments as Hack?;

    if (hack == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
        body: const Center(
          child: Text('Hack details not found', style: TextStyle(color: Colors.white)),
        ),
      );
    }

    final displaySteps = hack.steps;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: GrittyBackground(
        child: SafeArea(
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
                            Text(
                              'How to Apply'.toUpperCase(),
                              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: -0.3,
                                  ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${hack.name} - ${hack.savings}'.toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: AppColors.mutedForeground,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Sharing this hack with your circle...'),
                              backgroundColor: AppColors.primary,
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
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
                            Icons.share_rounded,
                            color: AppColors.primary,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // Summary Banner Card
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16.0),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border, width: 1),
                  ),
                  child: Column(
                    children: [
                      Container(
                        height: 160,
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                          image: DecorationImage(
                            image: NetworkImage(
                              hack.image.isNotEmpty
                                  ? hack.image
                                  : 'https://images.unsplash.com/photo-1559526324-4b87b5e36e44?auto=format&fit=crop&w=600&q=80',
                            ),
                            fit: BoxFit.cover,
                            opacity: 0.4,
                          ),
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(16.0),
                          decoration: BoxDecoration(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.8),
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
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.5),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.white.withValues(alpha: 0.2),
                                      ),
                                    ),
                                    child: Text(
                                      hack.category.toUpperCase(),
                                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.5),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      children: [
                                        ...List.generate(
                                          5,
                                          (i) => Icon(
                                            Icons.star_rounded,
                                            color: i < hack.rating.floor() ? const Color(0xFFFFD700) : Colors.white24,
                                            size: 14,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${hack.rating}',
                                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                                color: Colors.white,
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
                                    hack.name.toUpperCase(),
                                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                  ),
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                                    ),
                                    child: Text(
                                      hack.cardName.toUpperCase(),
                                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              hack.heading,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.white,
                                    height: 1.5,
                                  ),
                            ),
                            if (hack.availedby.isNotEmpty || hack.circledetail.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (hack.availedby.isNotEmpty)
                                      Row(
                                        children: [
                                          const Icon(Icons.people_outline_rounded, size: 16, color: AppColors.primary),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              hack.availedby.toUpperCase(),
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .labelSmall
                                                  ?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600),
                                            ),
                                          ),
                                        ],
                                      ),
                                    if (hack.availedby.isNotEmpty && hack.circledetail.isNotEmpty)
                                      const SizedBox(height: 8),
                                    if (hack.circledetail.isNotEmpty)
                                      Row(
                                        children: [
                                          const Icon(Icons.hub_outlined, size: 16, color: AppColors.secondary),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              hack.circledetail.toUpperCase(),
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .labelSmall
                                                  ?.copyWith(color: AppColors.secondary, fontWeight: FontWeight.w600),
                                            ),
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ).animate().fade(duration: 400.ms).slideY(begin: 0.05, curve: Curves.easeOutQuad),

                const SizedBox(height: 24),

                // Steps Section
                if (displaySteps.isNotEmpty)
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
                            children: [
                              const Icon(Icons.list_alt_rounded, size: 22, color: AppColors.primary),
                              const SizedBox(width: 10),
                              Text(
                                'Steps'.toUpperCase(),
                                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                      color: Colors.white,
                                    ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Scrollable Steps Container
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 450),
                            child: Theme(
                              data: Theme.of(context).copyWith(
                                scrollbarTheme: ScrollbarThemeData(
                                  thumbColor: WidgetStateProperty.all(AppColors.primary.withValues(alpha: 0.3)),
                                  thickness: WidgetStateProperty.all(4),
                                  radius: const Radius.circular(10),
                                ),
                              ),
                              child: Scrollbar(
                                thumbVisibility: true,
                                child: SingleChildScrollView(
                                  physics: const BouncingScrollPhysics(),
                                  padding: const EdgeInsets.only(right: 12),
                                  child: ListView.builder(
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
                                                border: Border.all(color: AppColors.border, width: 1),
                                              ),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    step.name.toUpperCase().isNotEmpty
                                                        ? step.name.toUpperCase()
                                                        : 'STEP $stepNum',
                                                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                                          fontWeight: FontWeight.bold,
                                                          color: AppColors.primary,
                                                          letterSpacing: 0.8,
                                                        ),
                                                  ),
                                                  const SizedBox(height: 6),
                                                  Text(
                                                    step.heading,
                                                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                                          fontWeight: FontWeight.bold,
                                                          color: Colors.white,
                                                        ),
                                                  ),
                                                  const SizedBox(height: 6),
                                                  Text(
                                                    step.description,
                                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ).animate().fade(delay: 200.ms, duration: 400.ms).slideY(begin: 0.05, curve: Curves.easeOutQuad),

                const SizedBox(height: 24),

                // Things to Note Section
                if (hack.thingsToNote.isNotEmpty)
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
                            children: [
                              const Icon(Icons.info_outline_rounded, size: 22, color: AppColors.secondary),
                              const SizedBox(width: 10),
                              Text(
                                'Things to Note'.toUpperCase(),
                                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                      color: Colors.white,
                                    ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          ...hack.thingsToNote.map((note) => Padding(
                                padding: const EdgeInsets.only(bottom: 12.0),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4.0),
                                      child: Icon(Icons.circle, size: 6, color: AppColors.secondary),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        note,
                                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                              color: AppColors.mutedForeground,
                                              height: 1.5,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              )),
                        ],
                      ),
                    ),
                  ).animate().fade(delay: 250.ms, duration: 400.ms).slideY(begin: 0.05, curve: Curves.easeOutQuad),

                const SizedBox(height: 24),

                // FAQ Section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.help_outline_rounded, size: 22, color: AppColors.primary),
                          const SizedBox(width: 10),
                          Text(
                            'FAQ'.toUpperCase(),
                            style: Theme.of(context).textTheme.labelLarge?.copyWith(
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
                                        _expandedFaqIndex = isExpanded ? null : faqIdx;
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
                                              color: AppColors.primary.withValues(alpha: 0.15),
                                            ),
                                            alignment: Alignment.center,
                                            child: Text(
                                              '$number',
                                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                                    color: AppColors.primary,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              faq.question.toUpperCase(),
                                              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 12,
                                                  ),
                                            ),
                                          ),
                                          Icon(
                                            isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.chevron_right_rounded,
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
                                      padding: const EdgeInsets.only(left: 56.0, right: 16.0, bottom: 16.0),
                                      child: Text(
                                        faq.answer,
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                              color: AppColors.mutedForeground,
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
      ),
    );
  }

  Widget _getStepIcon(int idx, String emojiIcon) {
    if (emojiIcon.isNotEmpty) {
      return Text(
        emojiIcon,
        style: const TextStyle(fontSize: 20),
      );
    }

    if (idx == 0) {
      return const Icon(Icons.assignment_turned_in_outlined, color: AppColors.primary, size: 20);
    } else if (idx == 1) {
      return const Icon(Icons.folder_open_rounded, color: AppColors.primary, size: 20);
    } else if (idx == 2) {
      return const Icon(Icons.link_rounded, color: AppColors.primary, size: 20);
    } else {
      return const Icon(Icons.lightbulb_outline_rounded, color: AppColors.primary, size: 20);
    }
  }
}
