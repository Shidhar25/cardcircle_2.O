import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/state/auth_state.dart';
import '../../../shared/models/hack.dart';
import '../state/feed_state.dart';
import '../../../core/services/api_service.dart';
import '../../../shared/models/hack_rating.dart';
import '../../../shared/widgets/gritty_background.dart';
import '../../../shared/widgets/primitives.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/models/feedback_question.dart';
import '../../../shared/widgets/feedback_sheet.dart';
import '../../../shared/widgets/rating_stars.dart';

/// v1 screen 22 — Benefit detail: a full-bleed hero image, the benefit's
/// title, a You Save / Circle Using stat pair, a numbered "HOW TO AVAIL
/// THIS BENEFIT" timeline, a gold "Things to note" panel, and Save/Share
/// actions.
///
/// The hero is sized from the viewport rather than pinned at a constant, so
/// it keeps roughly the same proportion of the screen on a small phone and
/// a tall one. The title sits below it rather than overlaid, which leaves
/// the whole hero to the image.
class HackDetailScreen extends StatefulWidget {
  const HackDetailScreen({super.key});

  @override
  State<HackDetailScreen> createState() => _HackDetailScreenState();
}

class _HackDetailScreenState extends State<HackDetailScreen> {
  /// Hero shape, near the dominant artwork ratio (2.0, with 1.889 and 2.125
  /// also in the catalog). Slightly taller than 2:1 so the common case
  /// letterboxes by only a few pixels while an odd square image still has
  /// somewhere to sit.
  static const double _heroAspect = 1.9;

  bool _saved = false;

  /// The steps list scrolls independently of the page, so it needs its own
  /// controller — sharing the page's would make the two fight.
  final ScrollController _stepsController = ScrollController();

  /// The benefit as currently displayed.
  ///
  /// Rating it returns fresh aggregates, and this screen was pushed with an
  /// immutable route argument, so the updated copy is held here rather than
  /// making the reader leave and come back to see their own score land.
  Hack? _updated;
  bool _rating = false;

  /// The questions to ask when the reader leaves.
  ///
  /// Asked late but resolved early: the question itself ("did this work for
  /// you?") only makes sense once the reader has read the benefit, but
  /// whether to ask at all has to be settled before they leave.
  FeedbackPrompt _prompt = FeedbackPrompt.none;
  bool _promptResolved = false;

  /// Set once feedback has been asked, so leaving a second time — or the
  /// programmatic pop that follows the sheet — goes straight through.
  bool _feedbackDone = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_promptResolved) return;
    _promptResolved = true;
    _resolvePrompt();
  }

  /// Works out whether to ask, preferring what the list already told us.
  ///
  /// The list endpoints embed `feedback_prompt` per benefit, so arriving
  /// from a list costs no request at all. Only a benefit reached without
  /// one — a deep link — falls back to the standalone endpoint, and that
  /// call is scoped by `hack_id`: feedback is tracked per benefit, so an
  /// unscoped check would report "already answered" for every benefit once
  /// the reader had answered for any one of them.
  Future<void> _resolvePrompt() async {
    final hack = ModalRoute.of(context)?.settings.arguments as Hack?;
    if (hack == null) return;

    final embedded = hack.feedbackPrompt;
    if (embedded != null) {
      // The list is authoritative; nothing to ask the server.
      if (mounted) setState(() => _prompt = embedded);
      return;
    }

    final prompt = await ApiService.getFeedbackPrompt(
      _feedbackContext,
      hackId: hack.id,
    );
    if (mounted) setState(() => _prompt = prompt);
  }

  /// Asks for feedback as the reader leaves, then completes the pop.
  ///
  /// Any failure is silent and the pop still happens: a feedback prompt is
  /// never a reason to trap someone on a screen they are trying to leave.
  Future<void> _handlePop(Hack hack) async {
    _feedbackDone = true;

    if (_prompt.hasSomethingToAsk) {
      final answered = await FeedbackSheet.show(
        context,
        feedbackContext: _feedbackContext,
        questions: _prompt.questions,
        hackId: hack.id,
      );

      // The list this benefit came from still carries the pre-answer
      // prompt, so without this, re-opening it from that same list would
      // ask again and the server would reject the duplicate answers.
      if (answered && mounted) {
        Provider.of<FeedState>(
          context,
          listen: false,
        ).replaceHack((_updated ?? hack).withFeedbackAnswered());
      }
    }

    if (mounted) Navigator.of(context).pop();
  }

  /// Matches the seeded context on the server.
  static const String _feedbackContext = 'hack_benefits_first_view';

  Future<void> _submitRating(Hack hack, int stars) async {
    if (_rating) return;

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _rating = true);
    final result = await ApiService.rateHack(hack.id, stars);
    if (!mounted) return;
    setState(() => _rating = false);

    if (!result.ok) {
      messenger.showError(result.display('Could not save your rating.'));
      return;
    }

    final data = result.data ?? const <String, dynamic>{};
    final mine = data['my_rating'];
    setState(() {
      _updated = hack.withRatings(
        platform: HackRating.parse(data['platform_rating']),
        circle: HackRating.parse(data['circle_rating']),
        mine: mine is num ? mine.toInt() : stars,
      );
    });

    // Keep the list behind this screen in step, so going back does not show
    // the old score.
    if (mounted) {
      Provider.of<FeedState>(context, listen: false).replaceHack(_updated!);
    }
  }

  @override
  void dispose() {
    _stepsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hack = ModalRoute.of(context)?.settings.arguments as Hack?;

    if (hack == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
        body: Center(
          child: Text(
            'Hack details not found',
            style: AppText.sans(14, color: AppColors.text),
          ),
        ),
      );
    }

    // Prefer the locally updated copy once the user has rated.
    final shown = _updated ?? hack;
    final steps = hack.steps;
    final media = MediaQuery.of(context);
    final myCardNames = hack.myCardNames(
      Provider.of<AuthState>(context, listen: false).user.cards,
    );

    // Sized from the artwork, not the viewport. Benefit images are wide —
    // 2720x1360 for most of the catalog, so 2:1 — and a hero shaped to the
    // screen (roughly 1.28:1) cropped about a third of every image away.
    // A 1.9:1 hero sits close enough to the real artwork that almost
    // nothing is letterboxed.
    final heroHeight = (media.size.width / _heroAspect).clamp(180.0, 300.0);

    // The steps get their own scroll area rather than stretching the page.
    // Capped against the viewport so a ten-step benefit does not push
    // "Things to note" and the share button far below the fold.
    final stepsMaxHeight = (media.size.height * 0.42).clamp(240.0, 420.0);

    return PopScope(
      // Intercepted so feedback can be asked on the way out. Once asked,
      // `canPop` is true and the next pop — including the one below —
      // passes straight through.
      canPop: _feedbackDone || !_prompt.hasSomethingToAsk,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handlePop(hack);
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: GrittyBackground(
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 26),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Hero(hack: hack, height: heroHeight),
                  // Category and title moved out of the hero so the image is
                  // not half-covered by an overlay and a scrim.
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.xl,
                      AppSpacing.lg,
                      AppSpacing.xl,
                      0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (hack.category.isNotEmpty) ...[
                          Container(
                            constraints: const BoxConstraints(maxWidth: 240),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 4.5,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(
                                AppRadii.chip,
                              ),
                              color: AppColors.elevated,
                              border: Border.all(color: AppColors.border),
                            ),
                            child: MonoLabel(
                              hack.category,
                              size: 8.5,
                              letterSpacing: 1.2,
                              color: AppColors.text,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.mdLg),
                        ],
                        Text(
                          hack.title,
                          style: AppText.sans(
                            23,
                            weight: FontWeight.w500,
                            color: AppColors.text,
                            letterSpacing: -0.5,
                            height: 1.26,
                          ),
                        ),
                        // Which of the reader's own cards this works with.
                        // Named rather than counted, and omitted when none
                        // match, so it never claims a card the user lacks.
                        if (myCardNames.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.md),
                          Row(
                            children: [
                              const Icon(
                                PhosphorIconsRegular.creditCard,
                                size: 14,
                                color: AppColors.gold,
                              ),
                              const SizedBox(width: 7),
                              Expanded(
                                child: Text(
                                  'Works with ${myCardNames.join(', ')}',
                                  style: AppText.sans(
                                    12,
                                    color: AppColors.textDim,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xl,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: AppSpacing.mdLg),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedSurface(
                                padding: const EdgeInsets.all(AppSpacing.md),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const MonoLabel(
                                      'YOU SAVE',
                                      size: 8.5,
                                      letterSpacing: 1.4,
                                      color: AppColors.textFaint,
                                    ),
                                    const SizedBox(height: 5.6),
                                    // `savings` is sometimes a figure ("5%")
                                    // and sometimes a whole sentence. A fixed
                                    // 19pt display size turned the latter into
                                    // a five-line wall in a half-width box, so
                                    // long values drop to body size.
                                    Text(
                                      hack.savings,
                                      maxLines: 4,
                                      overflow: TextOverflow.ellipsis,
                                      style: hack.savings.length <= 12
                                          ? AppText.mono(
                                              19,
                                              ls: 0,
                                              w: FontWeight.w700,
                                              c: AppColors.teal,
                                            )
                                          : AppText.sans(
                                              12.5,
                                              weight: FontWeight.w500,
                                              color: AppColors.teal,
                                              height: 1.45,
                                            ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: OutlinedSurface(
                                padding: const EdgeInsets.all(AppSpacing.md),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const MonoLabel(
                                      'YOUR CIRCLE',
                                      size: 8.5,
                                      letterSpacing: 1.4,
                                      color: AppColors.textFaint,
                                    ),
                                    const SizedBox(height: 5.6),
                                    // The circle's real score. This box used
                                    // to print hack.likes, a hardcoded 124
                                    // identical on every benefit.
                                    Text(
                                      shown.circleRating.hasRatings
                                          ? shown.circleRating.display
                                          : '—',
                                      style: AppText.mono(
                                        19,
                                        ls: 0,
                                        w: FontWeight.w700,
                                        c: shown.circleRating.hasRatings
                                            ? AppColors.gold
                                            : AppColors.textFaint,
                                      ),
                                    ),
                                    if (shown.circleRating.hasRatings)
                                      Text(
                                        'from ${shown.circleRating.count}',
                                        style: AppText.sans(
                                          10,
                                          color: AppColors.textFaint,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (steps.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.xxl),
                          const MonoLabel(
                            'HOW TO AVAIL THIS BENEFIT',
                            size: 9.5,
                            letterSpacing: 1.8,
                            color: AppColors.textFaint,
                          ),
                          const SizedBox(height: AppSpacing.mdLg),
                          // Only this section scrolls. Short benefits shrink to
                          // fit; long ones scroll inside the box, so the page
                          // below stays reachable without a long drag.
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              maxHeight: stepsMaxHeight,
                            ),
                            child: Scrollbar(
                              controller: _stepsController,
                              thumbVisibility: steps.length > 3,
                              child: ListView.builder(
                                controller: _stepsController,
                                // Clamping, not bouncing: an inner list that
                                // overscrolls past its bounds steals the drag
                                // the outer page should have taken.
                                physics: const ClampingScrollPhysics(),
                                shrinkWrap: true,
                                padding: const EdgeInsets.only(
                                  right: AppSpacing.md,
                                ),
                                itemCount: steps.length,
                                itemBuilder: (context, i) {
                                  final step = steps[i];
                                  final isLast = i == steps.length - 1;
                                  return IntrinsicHeight(
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Column(
                                          children: [
                                            // The step's own icon from the
                                            // API, falling back to the
                                            // ordinal when a step ships
                                            // without one.
                                            Container(
                                              width: 30,
                                              height: 30,
                                              alignment: Alignment.center,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: AppColors.surface,
                                                border: Border.all(
                                                  color: AppColors.gold
                                                      .withValues(alpha: 0.5),
                                                ),
                                              ),
                                              child: step.icon.isNotEmpty
                                                  ? Text(
                                                      step.icon,
                                                      style: const TextStyle(
                                                        fontSize: 14,
                                                      ),
                                                    )
                                                  : Text(
                                                      '${i + 1}',
                                                      style: AppText.mono(
                                                        11,
                                                        ls: 0,
                                                        w: FontWeight.w700,
                                                        c: AppColors.gold,
                                                      ),
                                                    ),
                                            ),
                                            if (!isLast)
                                              Expanded(
                                                child: Container(
                                                  width: 1,
                                                  color: AppColors.border,
                                                  margin: const EdgeInsets.only(
                                                    top: 5,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(width: AppSpacing.mdLg),
                                        Expanded(
                                          child: Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 18,
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Step ${i + 1} · '
                                                  '${step.heading.isNotEmpty ? step.heading : step.name}',
                                                  style: AppText.sans(
                                                    13.5,
                                                    weight: FontWeight.w500,
                                                    color: AppColors.text,
                                                  ),
                                                ),
                                                const SizedBox(height: 5),
                                                Text(
                                                  step.description,
                                                  style: AppText.sans(
                                                    12.5,
                                                    color: AppColors.textDim,
                                                    height: 1.6,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: AppSpacing.xxl),
                        _RatingPanel(
                          hack: shown,
                          busy: _rating,
                          onRate: _submitRating,
                        ),

                        if (hack.thingsToNote.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.md),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(
                                AppRadii.card,
                              ),
                              color: const Color(0xFF2B2415),
                              border: Border.all(
                                color: AppColors.gold.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      PhosphorIconsRegular.warningCircle,
                                      size: 14,
                                      color: AppColors.gold,
                                    ),
                                    const SizedBox(width: 8),
                                    const MonoLabel(
                                      'THINGS TO NOTE',
                                      size: 9.5,
                                      letterSpacing: 1.5,
                                      color: AppColors.gold,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: AppSpacing.md),
                                ...hack.thingsToNote.map(
                                  (note) => Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: Text(
                                      '•  $note',
                                      style: AppText.sans(
                                        12.5,
                                        color: AppColors.textMuted,
                                        height: 1.7,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: AppSpacing.xl),
                        Row(
                          children: [
                            Expanded(
                              child: GoldButton(
                                label: _saved ? 'Saved' : 'Save hack',
                                icon: _saved
                                    ? PhosphorIconsFill.bookmarkSimple
                                    : PhosphorIconsRegular.bookmarkSimple,
                                height: 50,
                                onTap: () => setState(() => _saved = !_saved),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            IconTile(
                              icon: PhosphorIconsRegular.shareNetwork,
                              size: 50,
                              iconSize: 18,
                              color: AppColors.textDim,
                              onTap: () =>
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Sharing this hack with your circle...',
                                      ),
                                      backgroundColor: AppColors.gold,
                                    ),
                                  ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  final Hack hack;
  final double height;

  const _Hero({required this.hack, required this.height});

  @override
  Widget build(BuildContext context) {
    // The hero deliberately paints under the status bar, so the back button
    // has to be pushed clear of it by hand. Pinning it at `top: 8` put it
    // under the notch on every phone with one.
    final topInset = MediaQuery.of(context).padding.top;

    return SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const _HeroPlaceholder(),

          if (hack.image.isNotEmpty) ...[
            // Backdrop: the same image, cropped to fill and blurred. It
            // fills whatever the contained image leaves over without the
            // dead letterbox bars a plain `contain` would show, and it is
            // never the thing being read, so cropping it costs nothing.
            ClipRect(
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                child: Transform.scale(
                  // Blur samples beyond the edge and would otherwise leave
                  // a soft transparent rim.
                  scale: 1.1,
                  child: Image.network(
                    hack.image,
                    fit: BoxFit.cover,
                    color: Colors.black.withValues(alpha: 0.45),
                    colorBlendMode: BlendMode.darken,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
              ),
            ),

            // The image itself, whole. `contain` is the point: these are
            // 2:1 illustrations with the subject spread across the full
            // width, so cropping to fill threw away the sides.
            Image.network(
              hack.image,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
              // A half-painted image over the placeholder looks broken, so
              // it is faded in only once fully decoded.
              frameBuilder: (context, child, frame, wasSyncLoaded) {
                if (wasSyncLoaded) return child;
                return AnimatedOpacity(
                  opacity: frame == null ? 0 : 1,
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  child: child,
                );
              },
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ],

          // Top scrim only — enough contrast for the back button without
          // dimming the image the way the old full-height scrim did.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: topInset + 64,
            child: const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x99000000), Colors.transparent],
                ),
              ),
            ),
          ),

          // A short fade into the page background, so the image meets the
          // content instead of ending on a hard line.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 40,
            child: const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, AppColors.background],
                ),
              ),
            ),
          ),

          Positioned(
            left: AppSpacing.xl,
            top: topInset + AppSpacing.sm,
            child: IconTile(
              icon: PhosphorIconsRegular.arrowLeft,
              iconSize: 17,
              background: AppColors.background.withValues(alpha: 0.78),
              onTap: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }
}

/// Both aggregate scores, and the reader's own stars.
///
/// The two are shown side by side rather than blended: the circle's opinion
/// is the signal this app exists to surface, and averaging it into a global
/// number would erase it.
class _RatingPanel extends StatelessWidget {
  final Hack hack;
  final bool busy;
  final void Function(Hack hack, int stars) onRate;

  const _RatingPanel({
    required this.hack,
    required this.busy,
    required this.onRate,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedSurface(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const MonoLabel(
            'RATINGS',
            size: 9.5,
            letterSpacing: 1.8,
            color: AppColors.textFaint,
          ),
          const SizedBox(height: AppSpacing.md),

          if (hack.circleRating.hasRatings) ...[
            RatingBadge(rating: hack.circleRating, fromCircle: true, size: 11),
            const SizedBox(height: 6),
          ],
          if (hack.platformRating.hasRatings)
            Row(
              children: [
                Flexible(
                  child: RatingBadge(rating: hack.platformRating, size: 11),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'on CardCircle',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                    style: AppText.sans(11, color: AppColors.textFaint),
                  ),
                ),
              ],
            ),
          if (!hack.circleRating.hasRatings && !hack.platformRating.hasRatings)
            Text(
              'Not rated yet — yours would be the first.',
              style: AppText.sans(12, color: AppColors.textDim),
            ),

          const SizedBox(height: AppSpacing.lg),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: AppSpacing.lg),

          Text(
            hack.myRating == null ? 'Rate this benefit' : 'Your rating',
            style: AppText.sans(
              12.5,
              weight: FontWeight.w500,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          RatingPicker(
            value: hack.myRating,
            busy: busy,
            onRate: (stars) => onRate(hack, stars),
          ),
        ],
      ),
    );
  }
}

/// The hero backdrop, shown while the image loads and left visible for
/// benefits that have no image.
class _HeroPlaceholder extends StatelessWidget {
  const _HeroPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: Color(0xFF1B1D29)),
      child: CustomPaint(painter: _DiagonalStripePainter()),
    );
  }
}

/// `repeating-linear-gradient(115deg, gold@.09 0 2px, transparent 2px 11px)`
/// from the prototype's hero placeholder — a field of thin diagonal stripes.
class _DiagonalStripePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.gold.withValues(alpha: 0.09)
      ..strokeWidth = 2;
    const spacing = 11.0;
    const angle = 115 * 3.14159265 / 180; // radians

    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(angle);
    final diagonal = size.width + size.height;
    for (double x = -diagonal; x < diagonal; x += spacing) {
      canvas.drawLine(Offset(x, -diagonal), Offset(x, diagonal), paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
