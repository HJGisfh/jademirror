import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

enum PetState { idle, listening, thinking, speaking }

class JadeSpiritPanel extends StatelessWidget {
  final String jadeName;
  final PetState state;
  final String statusText;

  const JadeSpiritPanel({
    super.key,
    required this.jadeName,
    this.state = PetState.idle,
    required this.statusText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink900.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          JadeSpiritPet(state: state),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '玉灵 · $jadeName',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppColors.ink500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class JadeSpiritPet extends StatefulWidget {
  final PetState state;
  final double size;

  const JadeSpiritPet({
    super.key,
    this.state = PetState.idle,
    this.size = 72,
  });

  @override
  State<JadeSpiritPet> createState() => _JadeSpiritPetState();
}

class _JadeSpiritPetState extends State<JadeSpiritPet> with TickerProviderStateMixin {
  late final AnimationController _breatheController;
  late final AnimationController _bobController;
  late final AnimationController _earController;
  late final AnimationController _blinkController;

  @override
  void initState() {
    super.initState();
    _breatheController = AnimationController(
      vsync: this,
      duration: AppDurations.breathe,
    )..repeat(reverse: true);

    _bobController = AnimationController(
      vsync: this,
      duration: AppDurations.bob,
    )..repeat(reverse: true);

    _earController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    )..repeat();

    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat();
  }

  @override
  void dispose() {
    _breatheController.dispose();
    _bobController.dispose();
    _earController.dispose();
    _blinkController.dispose();
    super.dispose();
  }

  Color get _bodyColor {
    switch (widget.state) {
      case PetState.listening:
        return AppColors.petListening;
      case PetState.thinking:
        return AppColors.petThinking;
      case PetState.speaking:
        return AppColors.petSpeaking;
      case PetState.idle:
        return AppColors.petIdle;
    }
  }

  Color get _glowColor {
    switch (widget.state) {
      case PetState.listening:
        return AppColors.petListening.withValues(alpha: 0.5);
      case PetState.thinking:
        return AppColors.petThinking.withValues(alpha: 0.4);
      case PetState.speaking:
        return AppColors.petSpeaking.withValues(alpha: 0.45);
      case PetState.idle:
        return AppColors.petIdle.withValues(alpha: 0.3);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _bobController,
      builder: (context, child) {
        final floatY = math.sin(_bobController.value * math.pi) * 2;
        return Transform.translate(
          offset: Offset(0, floatY),
          child: child,
        );
      },
      child: AnimatedBuilder(
        animation: _breatheController,
        builder: (context, child) {
          final scale = 1.0 + _breatheController.value * 0.03;
          return Transform.scale(
            scale: scale,
            alignment: Alignment.center,
            child: child,
          );
        },
        child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: _glowColor,
                      blurRadius: 20,
                      spreadRadius: 4,
                    ),
                  ],
                ),
              ),
              CustomPaint(
                size: Size(widget.size, widget.size),
                painter: _SpiritPetPainter(
                  bodyColor: _bodyColor,
                  cheekColor: AppColors.petCheek,
                  state: widget.state,
                  breatheValue: _breatheController.value,
                  earValue: _earController.value,
                  blinkValue: _blinkController.value,
                ),
              ),
              if (widget.state == PetState.listening) _buildPulseRing(),
              if (widget.state == PetState.speaking) _buildSoundBars(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPulseRing() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.8, end: 1.4),
      duration: const Duration(milliseconds: 1500),
      builder: (context, value, child) {
        return Container(
          width: widget.size * value,
          height: widget.size * value,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: _bodyColor.withValues(alpha: 0.5 * (1.4 - value)),
              width: 2,
            ),
          ),
        );
      },
      onEnd: () {},
    );
  }

  Widget _buildSoundBars() {
    return Positioned(
      bottom: -4,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(4, (i) {
          return TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.2, end: 0.8),
            duration: Duration(milliseconds: 500 + i * 100),
            builder: (context, value, child) {
              return Container(
                width: 3,
                height: 4 + value * 6,
                margin: const EdgeInsets.symmetric(horizontal: 1),
                decoration: BoxDecoration(
                  color: _bodyColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            },
          );
        }),
      ),
    );
  }
}

class _SpiritPetPainter extends CustomPainter {
  final Color bodyColor;
  final Color cheekColor;
  final PetState state;
  final double breatheValue;
  final double earValue;
  final double blinkValue;

  _SpiritPetPainter({
    required this.bodyColor,
    required this.cheekColor,
    required this.state,
    required this.breatheValue,
    required this.earValue,
    required this.blinkValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final scale = size.width / 100;

    _drawBody(canvas, center, scale);
    _drawHead(canvas, center, scale);
    _drawEars(canvas, center, scale);
    _drawFace(canvas, center, scale);
    _drawLimbs(canvas, center, scale);
    _drawGem(canvas, center, scale);
  }

  void _drawBody(Canvas canvas, Offset center, double scale) {
    final bodyPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.2, -0.2),
        radius: 0.55,
        colors: [
          bodyColor,
          bodyColor.withValues(alpha: 0.85),
          bodyColor.withValues(alpha: 0.6),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: 46 * scale));

    final bodyPath = Path();
    bodyPath.addOval(Rect.fromCenter(
      center: Offset(center.dx, center.dy + 4 * scale),
      width: 56 * scale,
      height: 52 * scale,
    ));
    canvas.drawPath(bodyPath, bodyPaint);
  }

  void _drawHead(Canvas canvas, Offset center, double scale) {
    final headPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.2, -0.2),
        radius: 0.55,
        colors: [
          bodyColor,
          bodyColor.withValues(alpha: 0.85),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: 36 * scale));

    final headPath = Path();
    headPath.addOval(Rect.fromCenter(
      center: Offset(center.dx, center.dy - 12 * scale),
      width: 36 * scale,
      height: 32 * scale,
    ));
    canvas.drawPath(headPath, headPaint);
  }

  void _drawEars(Canvas canvas, Offset center, double scale) {
    final earPaint = Paint()..color = bodyColor.withValues(alpha: 0.8);

    final earTwitch = math.sin(earValue * math.pi * 2) * 3;

    final leftEarPath = Path();
    leftEarPath.addOval(Rect.fromCenter(
      center: Offset(center.dx - 14 * scale, center.dy - 24 * scale + earTwitch * scale),
      width: 12 * scale,
      height: 20 * scale,
    ));
    canvas.drawPath(leftEarPath, earPaint);

    final rightEarPath = Path();
    rightEarPath.addOval(Rect.fromCenter(
      center: Offset(center.dx + 14 * scale, center.dy - 24 * scale - earTwitch * scale),
      width: 12 * scale,
      height: 20 * scale,
    ));
    canvas.drawPath(rightEarPath, earPaint);
  }

  void _drawFace(Canvas canvas, Offset center, double scale) {
    final eyePaint = Paint()..color = const Color(0xFF2d4a3e);
    final eyeHighlightPaint = Paint()..color = Colors.white.withValues(alpha: 0.8);
    final cheekPaint = Paint()
      ..shader = RadialGradient(
        colors: [cheekColor.withValues(alpha: 0.7), cheekColor.withValues(alpha: 0)],
      ).createShader(Rect.fromCircle(center: center, radius: 8 * scale));

    final eyeY = center.dy - 12 * scale;
    final leftEyeX = center.dx - 8 * scale;
    final rightEyeX = center.dx + 8 * scale;

    if (state == PetState.thinking) {
      final eyeY2 = eyeY + 1 * scale;
      canvas.drawLine(
        Offset(leftEyeX - 4 * scale, eyeY2),
        Offset(leftEyeX + 4 * scale, eyeY2),
        Paint()
          ..color = const Color(0xFF2d4a3e)
          ..strokeWidth = 2 * scale
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawLine(
        Offset(rightEyeX - 4 * scale, eyeY2),
        Offset(rightEyeX + 4 * scale, eyeY2),
        Paint()
          ..color = const Color(0xFF2d4a3e)
          ..strokeWidth = 2 * scale
          ..strokeCap = StrokeCap.round,
      );

      final bubblePaint = Paint()..color = bodyColor.withValues(alpha: 0.5);
      canvas.drawCircle(Offset(center.dx + 22 * scale, center.dy - 28 * scale), 2.5 * scale, bubblePaint);
      canvas.drawCircle(Offset(center.dx + 28 * scale, center.dy - 34 * scale), 1.8 * scale, bubblePaint);
      canvas.drawCircle(Offset(center.dx + 32 * scale, center.dy - 38 * scale), 1.2 * scale, bubblePaint);
    } else {
      final blinkFactor = blinkValue < 0.1 ? blinkValue * 10 : (blinkValue > 0.9 ? (1 - blinkValue) * 10 : 1);
      final eyeHeight = (state == PetState.listening ? 5.5 : 4.5) * scale * blinkFactor;

      canvas.drawOval(
        Rect.fromCenter(center: Offset(leftEyeX, eyeY), width: 8 * scale, height: eyeHeight * 2),
        eyePaint,
      );
      canvas.drawOval(
        Rect.fromCenter(center: Offset(rightEyeX, eyeY), width: 8 * scale, height: eyeHeight * 2),
        eyePaint,
      );

      canvas.drawOval(
        Rect.fromCenter(center: Offset(leftEyeX + 1.5 * scale, eyeY - 1.5 * scale), width: 3 * scale, height: 3.6 * scale),
        eyeHighlightPaint,
      );
      canvas.drawOval(
        Rect.fromCenter(center: Offset(rightEyeX + 1.5 * scale, eyeY - 1.5 * scale), width: 3 * scale, height: 3.6 * scale),
        eyeHighlightPaint,
      );
    }

    if (state == PetState.speaking) {
      final mouthPaint = Paint()..color = const Color(0xFF2d4a3e).withValues(alpha: 0.5);
      canvas.drawOval(
        Rect.fromCenter(center: Offset(center.dx, center.dy - 1 * scale), width: 8 * scale, height: 6 * scale),
        mouthPaint,
      );
    } else if (state == PetState.listening) {
      final mouthPaint = Paint()..color = const Color(0xFF2d4a3e).withValues(alpha: 0.6);
      canvas.drawOval(
        Rect.fromCenter(center: Offset(center.dx, center.dy), width: 6 * scale, height: 5 * scale),
        mouthPaint,
      );
    } else {
      final smilePath = Path();
      smilePath.moveTo(center.dx - 6 * scale, center.dy - 1 * scale);
      smilePath.quadraticBezierTo(center.dx, center.dy + 3 * scale, center.dx + 6 * scale, center.dy - 1 * scale);
      canvas.drawPath(
        smilePath,
        Paint()
          ..color = const Color(0xFF2d4a3e)
          ..strokeWidth = 1.5 * scale
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );
    }

    canvas.drawCircle(Offset(center.dx - 16 * scale, center.dy - 6 * scale), 4 * scale, cheekPaint);
    canvas.drawCircle(Offset(center.dx + 16 * scale, center.dy - 6 * scale), 4 * scale, cheekPaint);
  }

  void _drawLimbs(Canvas canvas, Offset center, double scale) {
    final limbPaint = Paint()..color = bodyColor.withValues(alpha: 0.7);

    canvas.drawOval(
      Rect.fromCenter(center: Offset(center.dx - 20 * scale, center.dy + 12 * scale), width: 10 * scale, height: 7 * scale),
      limbPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(center.dx + 20 * scale, center.dy + 12 * scale), width: 10 * scale, height: 7 * scale),
      limbPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(center.dx - 10 * scale, center.dy + 28 * scale), width: 12 * scale, height: 8 * scale),
      limbPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(center.dx + 10 * scale, center.dy + 28 * scale), width: 12 * scale, height: 8 * scale),
      limbPaint,
    );
  }

  void _drawGem(Canvas canvas, Offset center, double scale) {
    final gemPaint = Paint()..color = const Color(0xFF5a9b82).withValues(alpha: 0.6);
    final gemShinePaint = Paint()..color = const Color(0xFF8dd4b8).withValues(alpha: 0.5);

    canvas.drawOval(
      Rect.fromCenter(center: Offset(center.dx, center.dy + 10 * scale), width: 8 * scale, height: 7 * scale),
      gemPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(center.dx, center.dy + 9 * scale), width: 4 * scale, height: 3 * scale),
      gemShinePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _SpiritPetPainter oldDelegate) {
    return oldDelegate.bodyColor != bodyColor ||
        oldDelegate.state != state ||
        oldDelegate.breatheValue != breatheValue ||
        oldDelegate.earValue != earValue ||
        oldDelegate.blinkValue != blinkValue;
  }
}
