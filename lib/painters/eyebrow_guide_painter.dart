import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../look_engine.dart';

class EyebrowGuidePainter extends CustomPainter {
  final Face face;
  final MakeupLookPreset preset;
  final Color guideColor;

  const EyebrowGuidePainter({
    required this.face,
    required this.preset,
    this.guideColor = const Color(0xFFFF4D97),
  });

  @override
  void paint(Canvas canvas, Size size) {
    final leftTop =
        _toOffsets(face.contours[FaceContourType.leftEyebrowTop]?.points);
    final leftBottom =
        _toOffsets(face.contours[FaceContourType.leftEyebrowBottom]?.points);
    final rightTop =
        _toOffsets(face.contours[FaceContourType.rightEyebrowTop]?.points);
    final rightBottom =
        _toOffsets(face.contours[FaceContourType.rightEyebrowBottom]?.points);

    if (leftTop.length >= 3 || leftBottom.length >= 3) {
      final bounds = _boundsOf([...leftTop, ...leftBottom]);
      final style = _styleForPreset(preset);
      _drawBrowGuide(canvas, bounds, style, isLeft: true);
    }

    if (rightTop.length >= 3 || rightBottom.length >= 3) {
      final bounds = _boundsOf([...rightTop, ...rightBottom]);
      final style = _styleForPreset(preset);
      _drawBrowGuide(canvas, bounds, style, isLeft: false);
    }
  }

  List<Offset> _toOffsets(List<Point<int>>? points) {
    if (points == null) return const [];
    return points
        .map((p) => Offset(p.x.toDouble(), p.y.toDouble()))
        .toList(growable: false);
  }

  _BrowStyle _styleForPreset(MakeupLookPreset preset) {
    switch (preset) {
      case MakeupLookPreset.softGlam:
        return const _BrowStyle(
          archPosition: 0.58,
          archLift: 0.075,
          tailDrop: 0.035,
          strokeWidth: 2.2,
          glowWidth: 7.0,
          opacity: 0.90,
        );

      case MakeupLookPreset.emo:
        return const _BrowStyle(
          archPosition: 0.50,
          archLift: 0.02,
          tailDrop: 0.02,
          strokeWidth: 2.3,
          glowWidth: 7.0,
          opacity: 0.92,
        );

      case MakeupLookPreset.dollKBeauty:
        return const _BrowStyle(
          archPosition: 0.54,
          archLift: 0.035,
          tailDrop: 0.01,
          strokeWidth: 2.0,
          glowWidth: 6.5,
          opacity: 0.85,
        );

      case MakeupLookPreset.bronzedGoddess:
        return const _BrowStyle(
          archPosition: 0.59,
          archLift: 0.11,
          tailDrop: 0.03,
          strokeWidth: 2.4,
          glowWidth: 7.2,
          opacity: 0.92,
        );

      case MakeupLookPreset.boldEditorial:
        return const _BrowStyle(
          archPosition: 0.62,
          archLift: 0.16,
          tailDrop: 0.00,
          strokeWidth: 2.9,
          glowWidth: 8.0,
          opacity: 0.98,
        );

      case MakeupLookPreset.debugPainterTest:
        return const _BrowStyle(
          archPosition: 0.60,
          archLift: 0.10,
          tailDrop: 0.00,
          strokeWidth: 3.0,
          glowWidth: 8.0,
          opacity: 1.0,
        );
    }
  }

  void _drawBrowGuide(
    Canvas canvas,
    Rect bounds,
    _BrowStyle style, {
    required bool isLeft,
  }) {
    final browW = bounds.width;
    final browH = bounds.height;

    // --- Base points ---
    Offset start;
    Offset arch;
    Offset tail;

    if (isLeft) {
      start = Offset(
        bounds.right - browW * 0.05,
        bounds.center.dy + browH * 0.05,
      );

      tail = Offset(
        bounds.left + browW * 0.05,
        bounds.center.dy + browH * style.tailDrop,
      );

      final archX = bounds.right - browW * style.archPosition;

      final baseY = _lerp(start.dy, tail.dy, style.archPosition);

      arch = Offset(
        archX,
        baseY - browH * style.archLift,
      );
    } else {
      start = Offset(
        bounds.left + browW * 0.05,
        bounds.center.dy + browH * 0.05,
      );

      tail = Offset(
        bounds.right - browW * 0.05,
        bounds.center.dy + browH * style.tailDrop,
      );

      final archX = bounds.left + browW * style.archPosition;

      final baseY = _lerp(start.dy, tail.dy, style.archPosition);

      arch = Offset(
        archX,
        baseY - browH * style.archLift,
      );
    }

    // --- Smooth natural curve (2-step bezier for realism) ---
    final mid1 = Offset.lerp(start, arch, 0.5)!;
    final mid2 = Offset.lerp(arch, tail, 0.5)!;

    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..quadraticBezierTo(
        mid1.dx,
        mid1.dy - browH * 0.03,
        arch.dx,
        arch.dy,
      )
      ..quadraticBezierTo(
        mid2.dx,
        mid2.dy,
        tail.dx,
        tail.dy,
      );

    // --- Glow (soft outer) ---
    final glowPaint = Paint()
      ..color = Colors.pinkAccent.withOpacity(0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = style.glowWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, glowPaint);

    // --- Main stroke (tapered effect simulated) ---
    final mainPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.pinkAccent.withOpacity(0.95),
          Colors.pinkAccent.withOpacity(0.75),
          Colors.pinkAccent.withOpacity(0.55),
        ],
        stops: const [0.0, 0.6, 1.0],
      ).createShader(bounds)
      ..style = PaintingStyle.stroke
      ..strokeWidth = style.strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, mainPaint);

    // --- Points ---
    if (isLeft) {
      _drawPoint(canvas, start, '3');
      _drawPoint(canvas, arch, '2');
      _drawPoint(canvas, tail, '1');
    } else {
      _drawPoint(canvas, start, '1');
      _drawPoint(canvas, arch, '2');
      _drawPoint(canvas, tail, '3');
    }
  }

  double _lerp(double a, double b, double t) {
    return a + (b - a) * t;
  }

  Rect _boundsOf(List<Offset> points) {
    double minX = points.first.dx;
    double maxX = points.first.dx;
    double minY = points.first.dy;
    double maxY = points.first.dy;

    for (final p in points.skip(1)) {
      minX = min(minX, p.dx);
      maxX = max(maxX, p.dx);
      minY = min(minY, p.dy);
      maxY = max(maxY, p.dy);
    }

    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  void _drawPoint(Canvas canvas, Offset center, String label) {
    final shadowPaint = Paint()
      ..color = guideColor.withOpacity(0.16)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final fillPaint = Paint()
      ..color = Colors.white.withOpacity(0.98)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final borderPaint = Paint()
      ..color = guideColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..isAntiAlias = true;

    canvas.drawCircle(center, 14, shadowPaint);
    canvas.drawCircle(center, 11.5, fillPaint);
    canvas.drawCircle(center, 11.5, borderPaint);

    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: guideColor,
          fontSize: 11.5,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    tp.paint(canvas, center.translate(-tp.width / 2, -tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant EyebrowGuidePainter oldDelegate) {
    return oldDelegate.face != face ||
        oldDelegate.preset != preset ||
        oldDelegate.guideColor != guideColor;
  }
}

class _BrowStyle {
  final double archPosition;
  final double archLift;
  final double tailDrop;
  final double strokeWidth;
  final double glowWidth;
  final double opacity;

  const _BrowStyle({
    required this.archPosition,
    required this.archLift,
    required this.tailDrop,
    required this.strokeWidth,
    required this.glowWidth,
    required this.opacity,
  });
}