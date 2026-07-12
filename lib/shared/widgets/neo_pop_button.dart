import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// Note: Ensure your AppColors are correctly imported
// import '../../core/theme/app_theme.dart';

enum NeoPopButtonStyle { elevated, flat, link }

class NeoPopButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final NeoPopButtonStyle style;

  /// Primary surface color. For [elevated] & [flat], this is the button face.
  final Color? color;

  /// Gradient applied to the button face. Overrides [color].
  final Gradient? gradient;

  /// Depth of the 3D edges in logical pixels.
  final double depth;

  /// Border radius of the button face.
  final double borderRadius;

  /// If true, button is disabled (greyed out, no press).
  final bool enabled;

  /// If true, shows a loading spinner instead of [child].
  final bool isLoading;

  /// Full width button.
  final bool fullWidth;

  /// Custom padding inside the button face.
  final EdgeInsetsGeometry? padding;

  /// Shadow color for the bottom/right 3D edges.
  final Color? shadowColor;

  /// Top highlight shimmer color (simulates light catching the top edge).
  final Color? shimmerColor;

  /// Optional ambient glow behind the button.
  final Color? glowColor;

  const NeoPopButton({
    super.key,
    required this.child,
    this.onPressed,
    this.style = NeoPopButtonStyle.elevated,
    this.color,
    this.gradient,
    this.depth = 6.0,
    this.borderRadius = 16.0,
    this.enabled = true,
    this.isLoading = false,
    this.fullWidth = true,
    this.padding,
    this.shadowColor,
    this.shimmerColor,
    this.glowColor,
  });

  /// Primary CTA (Vibrant gradient, deep elevated look)
  factory NeoPopButton.primary({
    Key? key,
    required Widget child,
    VoidCallback? onPressed,
    bool isLoading = false,
    bool enabled = true,
    bool fullWidth = true,
    double depth = 6.0,
    EdgeInsetsGeometry? padding,
  }) {
    return NeoPopButton(
      key: key,
      onPressed: onPressed,
      style: NeoPopButtonStyle.elevated,
      gradient: const LinearGradient(
        colors: [Color(0xFF00E5FF), Color(0xFF007799)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      shadowColor: const Color(0xFF004455),
      shimmerColor: Colors.white.withValues(alpha: 0.5),
      glowColor: const Color(0xFF00E5FF).withValues(alpha: 0.4),
      depth: depth,
      isLoading: isLoading,
      enabled: enabled,
      fullWidth: fullWidth,
      padding: padding,
      child: child,
    );
  }

  /// Secondary CTA (Premium dark surface, subtle flat depth)
  factory NeoPopButton.secondary({
    Key? key,
    required Widget child,
    VoidCallback? onPressed,
    bool isLoading = false,
    bool enabled = true,
    bool fullWidth = true,
  }) {
    return NeoPopButton(
      key: key,
      onPressed: onPressed,
      style: NeoPopButtonStyle.flat,
      color: const Color(0xFF1A1A1A), // Replace with AppColors.elevated
      shadowColor: const Color(0xFF050505),
      shimmerColor: Colors.white.withValues(alpha: 0.15),
      depth: 4.0,
      isLoading: isLoading,
      enabled: enabled,
      fullWidth: fullWidth,
      child: child,
    );
  }

  /// Outline / ghost style (glassy transparent face, flat)
  factory NeoPopButton.outline({
    Key? key,
    required Widget child,
    VoidCallback? onPressed,
    bool isLoading = false,
    bool enabled = true,
    bool fullWidth = true,
    Color borderColor = const Color(0xFF00E5FF), // Replace with AppColors.primary
  }) {
    return NeoPopButton(
      key: key,
      onPressed: onPressed,
      style: NeoPopButtonStyle.flat,
      color: Colors.transparent,
      shadowColor: borderColor.withValues(alpha: 0.4),
      glowColor: borderColor.withValues(alpha: 0.1),
      depth: 3.0,
      isLoading: isLoading,
      enabled: enabled,
      fullWidth: fullWidth,
      child: child,
    );
  }

  /// Link-style (Text only, subtle scale and fade)
  factory NeoPopButton.link({
    Key? key,
    required Widget child,
    VoidCallback? onPressed,
    bool enabled = true,
  }) {
    return NeoPopButton(
      key: key,
      onPressed: onPressed,
      style: NeoPopButtonStyle.link,
      enabled: enabled,
      fullWidth: false,
      child: child,
    );
  }

  @override
  State<NeoPopButton> createState() => _NeoPopButtonState();
}

class _NeoPopButtonState extends State<NeoPopButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pressAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    // Asymmetric animation: Fast press down, bouncy release
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
      reverseDuration: const Duration(milliseconds: 300),
    );
    _pressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeOutBack, // Adds the premium tactile pop
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _canPress =>
      widget.enabled && !widget.isLoading && widget.onPressed != null;

  void _onTapDown(TapDownDetails _) {
    if (!_canPress) return;
    setState(() => _isPressed = true);
    _controller.forward();
    HapticFeedback.lightImpact();
  }

  void _onTapUp(TapUpDetails _) {
    if (!_canPress) return;
    _controller.reverse().then((_) {
      if (mounted) setState(() => _isPressed = false);
    });
    HapticFeedback.mediumImpact();
    widget.onPressed?.call();
  }

  void _onTapCancel() {
    if (!_canPress) return;
    _controller.reverse().then((_) {
      if (mounted) setState(() => _isPressed = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.style == NeoPopButtonStyle.link) {
      return _buildLinkButton();
    }
    return _buildDepthButton();
  }

  // ─── Link Button ─────────────────────────────────────────
  Widget _buildLinkButton() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedBuilder(
        animation: _pressAnimation,
        builder: (context, _) {
          final double scale = 1.0 - (_pressAnimation.value * 0.04);
          return Transform.scale(
            scale: scale,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 100),
              opacity: !_canPress ? 0.4 : (_isPressed ? 0.7 : 1.0),
              child: widget.child,
            ),
          );
        },
      ),
    );
  }

  // ─── Elevated / Flat Depth Button ────────────────────────
  Widget _buildDepthButton() {
    final double depth = widget.style == NeoPopButtonStyle.elevated
        ? widget.depth
        : widget.depth * 0.5;

    final Color faceColor = widget.color ?? Colors.blueAccent;
    final Color shadowCol = widget.shadowColor ??
        HSLColor.fromColor(faceColor)
            .withLightness(
            (HSLColor.fromColor(faceColor).lightness * 0.4).clamp(0.0, 1.0))
            .toColor();

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedBuilder(
        animation: _pressAnimation,
        builder: (context, _) {
          final double pressedDepth = depth * (1 - _pressAnimation.value);
          final double translateY = depth * _pressAnimation.value;
          final double dropShadowOpacity = (1 - _pressAnimation.value).clamp(0.0, 1.0);

          return SizedBox(
            width: widget.fullWidth ? double.infinity : null,
            child: Padding(
              padding: EdgeInsets.only(
                bottom: depth,
                right: depth * 0.6,
              ),
              child: Transform.translate(
                offset: Offset(
                  _pressAnimation.value * depth * 0.3,
                  translateY,
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Ambient Drop Shadow
                    Positioned.fill(
                      child: Transform.translate(
                        offset: Offset(0, depth * 1.5),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(widget.borderRadius),
                            boxShadow: [
                              BoxShadow(
                                color: (widget.glowColor ?? shadowCol)
                                    .withValues(alpha: 0.4 * dropShadowOpacity),
                                blurRadius: 16,
                                spreadRadius: -2,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Bottom 3D edge with realistic ambient occlusion gradient
                    if (pressedDepth > 0.1)
                      Positioned(
                        bottom: -pressedDepth,
                        left: 1.5,
                        right: -pressedDepth * 0.6 + 1.5,
                        child: Container(
                          height: pressedDepth + widget.borderRadius * 0.4,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                shadowCol,
                                Color.lerp(shadowCol, Colors.black, 0.2)!,
                              ],
                            ),
                            borderRadius: BorderRadius.only(
                              bottomLeft: Radius.circular(widget.borderRadius),
                              bottomRight: Radius.circular(widget.borderRadius),
                            ),
                          ),
                        ),
                      ),

                    // Right 3D edge
                    if (pressedDepth > 0.1)
                      Positioned(
                        top: 1.5,
                        right: -pressedDepth * 0.6,
                        bottom: -pressedDepth + 1.5,
                        child: Container(
                          width: pressedDepth * 0.6 + widget.borderRadius * 0.4,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [
                                shadowCol.withValues(alpha: 0.9),
                                Color.lerp(shadowCol, Colors.black, 0.15)!.withValues(alpha: 0.9),
                              ],
                            ),
                            borderRadius: BorderRadius.only(
                              topRight: Radius.circular(widget.borderRadius),
                              bottomRight: Radius.circular(widget.borderRadius),
                            ),
                          ),
                        ),
                      ),

                    // Front Face
                    Container(
                      padding: widget.padding ??
                          const EdgeInsets.symmetric(
                              vertical: 18, horizontal: 24),
                      decoration: BoxDecoration(
                        color: widget.gradient == null ? faceColor : null,
                        gradient: widget.gradient,
                        borderRadius:
                        BorderRadius.circular(widget.borderRadius),
                        // Inner bevel highlight for premium molded feel
                        border: Border.all(
                          color: Colors.white.withValues(alpha: faceColor == Colors.transparent ? 0.0 : 0.15),
                          width: 1.0,
                        ),
                      ),
                      child: Stack(
                        children: [
                          // Content Layer
                          Center(
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 150),
                              opacity: _canPress ? 1.0 : 0.5,
                              child: widget.isLoading
                                  ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              )
                                  : widget.child,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Upgraded Text style with a subtle text shadow for better contrast
class NeoPopButtonText extends StatelessWidget {
  final String text;
  final Color color;
  final double fontSize;
  final FontWeight fontWeight;
  final double letterSpacing;
  final IconData? icon;
  final bool iconAfter;

  const NeoPopButtonText(
      this.text, {
        super.key,
        this.color = const Color(0xFFFFFFFF), // Default to white for premium contrast
        this.fontSize = 16, // Slightly reduced for elegance
        this.fontWeight = FontWeight.w700, // Reduced from w800 to look less heavy
        this.letterSpacing = 0.8, // Increased tracking for a modern feel
        this.icon,
        this.iconAfter = true,
      });

  @override
  Widget build(BuildContext context) {
    final textWidget = Text(
      text.toUpperCase(), // Uppercase often enhances the NeoPop brutalist/premium aesthetic
      style: TextStyle(
        color: color,
        fontSize: fontSize,
        fontWeight: fontWeight,
        letterSpacing: letterSpacing,
        // Subtle drop shadow behind text to separate it from gradients
        shadows: [
          Shadow(
            color: Colors.black.withValues(alpha: 0.15),
            offset: const Offset(0, 1.5),
            blurRadius: 2,
          ),
        ],
      ),
    );

    if (icon == null) return textWidget;

    final iconWidget = Icon(
      icon,
      color: color,
      size: fontSize + 4,
      shadows: [
        Shadow(
          color: Colors.black.withValues(alpha: 0.15),
          offset: const Offset(0, 1.5),
          blurRadius: 2,
        ),
      ],
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: iconAfter
          ? [textWidget, const SizedBox(width: 8), iconWidget]
          : [iconWidget, const SizedBox(width: 8), textWidget],
    );
  }
}