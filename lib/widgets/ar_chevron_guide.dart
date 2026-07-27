import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../utils/geo_utils.dart';

class ArChevronGuide extends StatefulWidget {
  final double? relativeAngle;
  final double? distanceMeters;
  final bool finalApproach;

  const ArChevronGuide({
    super.key,
    required this.relativeAngle,
    required this.distanceMeters,
    required this.finalApproach,
  });

  @override
  State<ArChevronGuide> createState() => _ArChevronGuideState();
}

class _ArChevronGuideState extends State<ArChevronGuide>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1450),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final relativeAngle = widget.relativeAngle;
    final signedAngle = relativeAngle == null
        ? 0.0
        : GeoUtils.normalizeSignedAngle(relativeAngle);
    final arrowRotation = signedAngle * math.pi / 180;
    final distance = widget.distanceMeters;
    final proximityScale = distance == null
        ? 1.0
        : (1.12 - (distance.clamp(0.0, 60.0) / 60.0) * 0.12)
            .toDouble();

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final floatOffset = -4 + _controller.value * 8;
          final glow = 0.18 + _controller.value * 0.18;
          return Align(
            alignment: const Alignment(0, 0.50),
            child: Transform.translate(
              offset: Offset(0, floatOffset),
              child: Transform.scale(
                scale: proximityScale,
                child: SizedBox(
                width: 250,
                height: 250,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned(
                      bottom: 25,
                      child: Container(
                        width: 154,
                        height: 38,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          gradient: RadialGradient(
                            colors: [
                              const Color(0xff0aa8ff)
                                  .withValues(alpha: glow),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                    Transform.rotate(
                      angle: arrowRotation,
                      child: Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, 0.0016)
                          ..rotateX(0.94),
                        child: CustomPaint(
                          size: const Size(178, 198),
                          painter: _GroundArrowPainter(
                            finalApproach: widget.finalApproach,
                            glowStrength: glow,
                          ),
                        ),
                      ),
                    ),
                    if (relativeAngle == null)
                      Positioned(
                        bottom: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.50),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Text(
                            'Calibrando brújula...',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _GroundArrowPainter extends CustomPainter {
  final bool finalApproach;
  final double glowStrength;

  const _GroundArrowPainter({
    required this.finalApproach,
    required this.glowStrength,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final bodyColor = finalApproach
        ? const Color(0xff23d67b)
        : const Color(0xff139cff);
    final lightColor = finalApproach
        ? const Color(0xff8dffc2)
        : const Color(0xff9be0ff);
    final darkColor = finalApproach
        ? const Color(0xff087e43)
        : const Color(0xff064a9a);

    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.46)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 13);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(centerX, size.height * 0.83),
        width: size.width * 0.76,
        height: size.height * 0.19,
      ),
      shadowPaint,
    );

    final glowPaint = Paint()
      ..color = bodyColor.withValues(alpha: glowStrength)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);
    canvas.drawPath(_arrowPath(size, const Offset(0, 5)), glowPaint);

    final extrusionPaint = Paint()
      ..shader = LinearGradient(
        colors: [darkColor, bodyColor.withValues(alpha: 0.90)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Offset.zero & size);
    canvas.drawPath(_arrowPath(size, const Offset(0, 12)), extrusionPaint);

    final facePaint = Paint()
      ..shader = LinearGradient(
        colors: [lightColor, bodyColor, darkColor],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        stops: const [0, 0.52, 1],
      ).createShader(Offset.zero & size);
    canvas.drawPath(_arrowPath(size, Offset.zero), facePaint);

    final outlinePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.88)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(_arrowPath(size, Offset.zero), outlinePaint);

    final highlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.58)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final highlight = Path()
      ..moveTo(centerX, size.height * 0.10)
      ..lineTo(centerX, size.height * 0.63);
    canvas.drawPath(highlight, highlightPaint);
  }

  Path _arrowPath(Size size, Offset offset) {
    final cx = size.width / 2 + offset.dx;
    final top = size.height * 0.05 + offset.dy;
    final neckTop = size.height * 0.45 + offset.dy;
    final bottom = size.height * 0.91 + offset.dy;
    final headHalf = size.width * 0.43;
    final neckHalf = size.width * 0.17;

    return Path()
      ..moveTo(cx, top)
      ..lineTo(cx + headHalf, neckTop)
      ..lineTo(cx + neckHalf, neckTop)
      ..lineTo(cx + neckHalf, bottom)
      ..quadraticBezierTo(cx, bottom + 8, cx - neckHalf, bottom)
      ..lineTo(cx - neckHalf, neckTop)
      ..lineTo(cx - headHalf, neckTop)
      ..close();
  }

  @override
  bool shouldRepaint(covariant _GroundArrowPainter oldDelegate) {
    return oldDelegate.finalApproach != finalApproach ||
        oldDelegate.glowStrength != glowStrength;
  }
}
