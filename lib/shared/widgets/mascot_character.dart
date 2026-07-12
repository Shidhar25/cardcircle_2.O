import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'dart:math' as math;
import 'package:flutter/material.dart';

class MascotCharacter extends StatefulWidget {
  final double size;
  final String mood; // 'idle' | 'happy' | 'celebrate' | 'thinking'

  const MascotCharacter({
    super.key,
    this.size = 180,
    this.mood = 'idle',
  });

  @override
  State<MascotCharacter> createState() => _MascotCharacterState();
}

class _MascotCharacterState extends State<MascotCharacter> with TickerProviderStateMixin {
  late AnimationController _floatController;
  late Animation<double> _floatAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimation();
  }

  void _setupAnimation() {
    _floatController = AnimationController(
      duration: _getFloatDuration(),
      vsync: this,
    )..repeat(reverse: true);

    _floatAnimation = TweenSequence<double>([
      TweenSequenceItem(
          tween: Tween(begin: 0.0, end: -15.0).chain(CurveTween(curve: Curves.easeInOutSine)),
          weight: 50
      ),
      TweenSequenceItem(
          tween: Tween(begin: -15.0, end: 0.0).chain(CurveTween(curve: Curves.easeInOutSine)),
          weight: 50
      ),
    ]).animate(_floatController);
  }

  @override
  void didUpdateWidget(covariant MascotCharacter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mood != widget.mood) {
      _floatController.duration = _getFloatDuration();
      _floatController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _floatController.dispose();
    super.dispose();
  }

  // --- Dynamic Mappings based on String Mood ---

  Duration _getFloatDuration() {
    switch (widget.mood) {
      case 'celebrate': return const Duration(milliseconds: 800);
      case 'thinking': return const Duration(milliseconds: 4000);
      default: return const Duration(milliseconds: 2500);
    }
  }

  Color get _emotionColor {
    switch (widget.mood) {
      case 'happy': return const Color(0xFF00FF7F);
      case 'celebrate': return const Color(0xFFFFD700);
      case 'thinking': return const Color(0xFFD500F9);
      case 'idle':
      default: return const Color(0xFF00E5FF);
    }
  }

  Matrix4 get _bodyTransform {
    final matrix = Matrix4.identity()..setEntry(3, 2, 0.001);
    switch (widget.mood) {
      case 'thinking': return matrix..rotateZ(0.12)..rotateY(-0.15);
      case 'celebrate': return matrix..rotateX(0.1)..scale(1.05, 1.05, 1.05);
      default: return matrix;
    }
  }

  Offset get _faceOffset {
    switch (widget.mood) {
      case 'celebrate': return const Offset(0.0, -10.0);
      case 'thinking': return const Offset(-10.0, -5.0);
      default: return Offset.zero;
    }
  }

  Map<String, dynamic> _getEyeSpecs(bool isLeftEye) {
    double height = 22.0, width = 14.0;
    BorderRadius radius = BorderRadius.circular(50);

    switch (widget.mood) {
      case 'happy':
        height = 15.0; width = 20.0;
        radius = const BorderRadius.vertical(top: Radius.circular(50), bottom: Radius.circular(5));
        break;
      case 'celebrate':
        height = 35.0; width = 25.0;
        break;
      case 'thinking':
        height = isLeftEye ? 24.0 : 8.0;
        width = isLeftEye ? 16.0 : 12.0;
        break;
      default: break;
    }
    return {'height': height, 'width': width, 'radius': radius};
  }

  Map<String, dynamic> _getMouthSpecs() {
    double height = 4.0, width = 18.0, xOffset = 0.0;
    BorderRadius radius = BorderRadius.circular(10);

    switch (widget.mood) {
      case 'happy':
        height = 14.0; width = 30.0;
        radius = const BorderRadius.vertical(bottom: Radius.circular(25), top: Radius.circular(4));
        break;
      case 'celebrate':
        height = 24.0; width = 20.0;
        radius = BorderRadius.circular(20);
        break;
      case 'thinking':
        height = 6.0; width = 10.0; xOffset = 18.0;
        break;
      default: break;
    }
    return {'height': height, 'width': width, 'radius': radius, 'xOffset': xOffset};
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _floatAnimation,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Ambient Background Aura
            AnimatedContainer(
              duration: const Duration(milliseconds: 600),
              width: widget.size * 1.2,
              height: widget.size * 1.2,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _emotionColor.withOpacity(0.15),
                    blurRadius: 100,
                    spreadRadius: 20,
                  ),
                ],
              ),
            ),

            // The Main Mascot Body
            Transform.translate(
              offset: Offset(0, _floatAnimation.value),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOutBack,
                transform: _bodyTransform,
                transformAlignment: Alignment.center,
                width: widget.size,
                height: widget.size * 0.65,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color.lerp(const Color(0xFF28282A), _emotionColor, 0.1)!,
                      Color.lerp(const Color(0xFF121214), _emotionColor, 0.05)!,
                      Colors.black
                    ],
                    stops: const [0.0, 0.4, 1.0],
                  ),
                  boxShadow: [
                    BoxShadow(color: _emotionColor.withOpacity(0.5), blurRadius: 25, spreadRadius: -2),
                    BoxShadow(color: _emotionColor.withOpacity(0.2), blurRadius: 60, spreadRadius: 15),
                  ],
                  border: Border.all(
                    color: Color.lerp(Colors.white, _emotionColor, 0.3)!.withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                child: Stack(
                  children: [
                    // Iridescent Holographic Overlay
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: ShaderMask(
                          shaderCallback: (bounds) => LinearGradient(
                            begin: Alignment(-1.5 + (_floatAnimation.value / 10), -1.0),
                            end: Alignment(1.5 + (_floatAnimation.value / 10), 1.0),
                            colors: [
                              Colors.white.withOpacity(0.0),
                              Colors.deepPurpleAccent.withOpacity(0.2),
                              Colors.cyanAccent.withOpacity(0.3),
                              Colors.amberAccent.withOpacity(0.2),
                              Colors.white.withOpacity(0.0),
                            ],
                            stops: const [0.1, 0.4, 0.5, 0.6, 0.9],
                          ).createShader(bounds),
                          child: Container(color: Colors.white),
                        ),
                      ),
                    ),

                    // Emotional Face
                    Center(
                      child: AnimatedSlide(
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeOutCubic,
                        offset: Offset(_faceOffset.dx / widget.size, _faceOffset.dy / widget.size),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _buildEye(isLeftEye: true),
                                const SizedBox(width: 45),
                                _buildEye(isLeftEye: false),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _buildMouth(),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEye({required bool isLeftEye}) {
    final specs = _getEyeSpecs(isLeftEye);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.elasticOut,
      height: specs['height'],
      width: specs['width'],
      decoration: BoxDecoration(
        color: _emotionColor,
        borderRadius: specs['radius'],
        boxShadow: [
          BoxShadow(color: _emotionColor, blurRadius: 15, spreadRadius: 4),
          const BoxShadow(color: Colors.white, blurRadius: 4, spreadRadius: 0),
        ],
      ),
    );
  }

  Widget _buildMouth() {
    final specs = _getMouthSpecs();
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.elasticOut,
      transform: Matrix4.translationValues(specs['xOffset'], 0, 0),
      height: specs['height'],
      width: specs['width'],
      decoration: BoxDecoration(
        color: _emotionColor,
        borderRadius: specs['radius'],
        boxShadow: [
          BoxShadow(color: _emotionColor, blurRadius: 10, spreadRadius: 2),
          const BoxShadow(color: Colors.white, blurRadius: 2, spreadRadius: 0),
        ],
      ),
    );
  }
}