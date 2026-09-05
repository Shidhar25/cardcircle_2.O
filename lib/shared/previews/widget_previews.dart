import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../widgets/primitives.dart';

/// Renders every primitive from `lib/shared/widgets/primitives.dart` in one
/// place (FLUTTER_HANDOFF.md §5 step 3) so their spacing/color/radius can be
/// eyeballed against the prototype before any screen consumes them.
///
/// Not part of the app's normal navigation — push it manually while
/// building/reviewing primitives, e.g. `Navigator.push(context,
/// MaterialPageRoute(builder: (_) => const WidgetPreviewsScreen()))`.
class WidgetPreviewsScreen extends StatefulWidget {
  const WidgetPreviewsScreen({super.key});

  @override
  State<WidgetPreviewsScreen> createState() => _WidgetPreviewsScreenState();
}

class _WidgetPreviewsScreenState extends State<WidgetPreviewsScreen> {
  int _tabIndex = 0;
  int _segIndex = 0;
  final Set<String> _selectedPills = {'All'};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Primitives')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          const _Section('OutlinedSurface'),
          OutlinedSurface(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text(
              'Outlined surface',
              style: AppText.sans(14, color: AppColors.text),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          const _Section('GoldButton'),
          const GoldButton(
            label: 'Enabled',
            icon: Icons.arrow_forward,
            onTap: null,
            enabled: true,
          ),
          const SizedBox(height: AppSpacing.sm),
          const GoldButton(
            label: 'Disabled',
            icon: Icons.arrow_forward,
            enabled: false,
          ),
          const SizedBox(height: AppSpacing.sm),
          const GoldButton(label: 'Loading', loading: true),
          const SizedBox(height: AppSpacing.xl),

          const _Section('AccentPanel'),
          AccentPanel(
            kind: AccentKind.gold,
            child: Text(
              'Gold accent panel',
              style: AppText.sans(13, color: AppColors.goldLight),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          AccentPanel(
            kind: AccentKind.teal,
            child: Text(
              'Teal accent panel',
              style: AppText.sans(13, color: AppColors.teal),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          const _Section('MonoLabel'),
          const MonoLabel('Step 2 of 2', size: 9.5, letterSpacing: 1.6),
          const SizedBox(height: AppSpacing.xs),
          const MonoLabel(
            '₹640/mo',
            size: 14,
            weight: FontWeight.w700,
            color: AppColors.teal,
            uppercase: false,
          ),
          const SizedBox(height: AppSpacing.xl),

          const _Section('CardFaceThumb'),
          Row(
            children: const [
              CardFaceThumb(face: CardFace.millennia),
              SizedBox(width: AppSpacing.sm),
              CardFaceThumb(face: CardFace.ace),
              SizedBox(width: AppSpacing.sm),
              CardFaceThumb(face: CardFace.amazonPay),
              SizedBox(width: AppSpacing.sm),
              CardFaceThumb(face: CardFace.magnus),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),

          const _Section('AvatarBubble'),
          Row(
            children: const [
              AvatarBubble(initials: 'RK', hue: AvatarHue.gold),
              SizedBox(width: AppSpacing.sm),
              AvatarBubble(initials: 'DR', hue: AvatarHue.teal),
              SizedBox(width: AppSpacing.sm),
              AvatarBubble(initials: 'MS', hue: AvatarHue.violet),
              SizedBox(width: AppSpacing.sm),
              AvatarBubble(initials: 'IV', hue: AvatarHue.steel),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),

          const _Section('FilterPill'),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: ['All', 'Dining', 'Travel', 'Shopping', 'Bills', 'Fuel']
                .map((label) {
                  return FilterPill(
                    label: label,
                    selected: _selectedPills.contains(label),
                    onTap: () => setState(() {
                      _selectedPills
                        ..clear()
                        ..add(label);
                    }),
                  );
                })
                .toList(),
          ),
          const SizedBox(height: AppSpacing.xl),

          const _Section('SegmentedTabs'),
          SegmentedTabs(
            labels: const ['CIRCLE', 'MY HACKS'],
            selectedIndex: _tabIndex,
            onChanged: (i) => setState(() => _tabIndex = i),
          ),
          const SizedBox(height: AppSpacing.sm),
          SegmentedTabs(
            labels: const ['FOLLOWERS', 'FOLLOWING', 'SUGGESTED'],
            selectedIndex: _segIndex,
            onChanged: (i) => setState(() => _segIndex = i),
            fontSize: 9.5,
          ),
          const SizedBox(height: AppSpacing.xl),

          const _Section('IconTile'),
          Row(
            children: [
              IconTile(icon: Icons.arrow_back_ios_new_rounded, onTap: () {}),
              const SizedBox(width: AppSpacing.sm),
              const IconTile(
                icon: Icons.notifications_none_rounded,
                iconSize: 16,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),

          const _Section('Money'),
          Text(
            '${Money.inr(148000)}   ·   ${Money.short(148000)}   ·   ${Money.short(920000)}',
            style: AppText.mono(13, c: AppColors.text),
          ),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  const _Section(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: MonoLabel(
        title,
        size: 11,
        letterSpacing: 1.4,
        color: AppColors.textFaint,
      ),
    );
  }
}
