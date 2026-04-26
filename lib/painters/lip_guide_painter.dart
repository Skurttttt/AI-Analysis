import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../look_engine.dart';

class LipGuidePainter extends CustomPainter {
  final Face face;
  final MakeupLookPreset preset;
  final Color lipColor;
  final double opacity;
  final bool showArrows;
  final bool showStepNumbers;

  const LipGuidePainter({
    required this.face,
    required this.preset,
    required this.lipColor,
    this.opacity = 1.0,
    this.showArrows = true,
    this.showStepNumbers = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final upperTop = _toOffsets(face.contours[FaceContourType.upperLipTop]?.points);
    final upperBottom =
        _toOffsets(face.contours[FaceContourType.upperLipBottom]?.points);
    final lowerTop = _toOffsets(face.contours[FaceContourType.lowerLipTop]?.points);
    final lowerBottom =
        _toOffsets(face.contours[FaceContourType.lowerLipBottom]?.points);

    if (upperTop.length < 4 ||
        upperBottom.length < 4 ||
        lowerTop.length < 4 ||
        lowerBottom.length < 4) {
      _drawFallback(canvas, size);
      return;
    }

    final guide = _buildLipGuide(
      upperTop: upperTop,
      upperBottom: upperBottom,
      lowerTop: lowerTop,
      lowerBottom: lowerBottom,
    );

    _drawGuide(canvas, guide);
  }

  List<Offset> _toOffsets(List<Point<int>>? pts) {
    if (pts == null) return const [];
    return pts
        .map((p) => Offset(p.x.toDouble(), p.y.toDouble()))
        .toList(growable: false);
  }

  _LipGuideData _buildLipGuide({
    required List<Offset> upperTop,
    required List<Offset> upperBottom,
    required List<Offset> lowerTop,
    required List<Offset> lowerBottom,
  }) {
    upperTop = _sortByX(upperTop);
    upperBottom = _sortByX(upperBottom);
    lowerTop = _sortByX(lowerTop);
    lowerBottom = _sortByX(lowerBottom);

    final all = [...upperTop, ...upperBottom, ...lowerTop, ...lowerBottom];
    final bounds = _boundsOf(all);
    final style = _styleForPreset(preset);

    final outer = _buildOuterLipPath(upperTop, lowerBottom);

    final fillRect = Rect.fromCenter(
      center: bounds.center,
      width: bounds.width * style.fillWidthFactor,
      height: bounds.height * style.fillHeightFactor,
    );

    final centerGlow = Rect.fromCenter(
      center: bounds.center,
      width: bounds.width * style.centerWidthFactor,
      height: bounds.height * style.centerHeightFactor,
    );

    final cupid = Offset(bounds.center.dx, bounds.top + bounds.height * 0.12);
    final leftCorner = Offset(bounds.left + bounds.width * 0.11, bounds.center.dy);
    final rightCorner =
        Offset(bounds.right - bounds.width * 0.11, bounds.center.dy);

    return _LipGuideData(
      outerPath: outer,
      bounds: bounds,
      fillRect: fillRect,
      centerGlowRect: centerGlow,
      cupidPoint: cupid,
      leftCorner: leftCorner,
      rightCorner: rightCorner,
      style: style,
    );
  }

  List<Offset> _sortByX(List<Offset> pts) {
    final copy = List<Offset>.from(pts);
    copy.sort((a, b) => a.dx.compareTo(b.dx));
    return copy;
  }

  Rect _boundsOf(List<Offset> pts) {
    double minX = pts.first.dx, maxX = pts.first.dx;
    double minY = pts.first.dy, maxY = pts.first.dy;
    for (final p in pts.skip(1)) {
      minX = min(minX, p.dx);
      maxX = max(maxX, p.dx);
      minY = min(minY, p.dy);
      maxY = max(maxY, p.dy);
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  Path _buildOuterLipPath(List<Offset> upperTop, List<Offset> lowerBottom) {
    final path = Path()..moveTo(upperTop.first.dx, upperTop.first.dy);

    for (int i = 1; i < upperTop.length; i++) {
      final prev = upperTop[i - 1];
      final curr = upperTop[i];
      final mid = Offset((prev.dx + curr.dx) / 2, (prev.dy + curr.dy) / 2);
      path.quadraticBezierTo(prev.dx, prev.dy, mid.dx, mid.dy);
    }
    path.lineTo(upperTop.last.dx, upperTop.last.dy);

    for (int i = lowerBottom.length - 1; i > 0; i--) {
      final prev = lowerBottom[i];
      final curr = lowerBottom[i - 1];
      final mid = Offset((prev.dx + curr.dx) / 2, (prev.dy + curr.dy) / 2);
      path.quadraticBezierTo(prev.dx, prev.dy, mid.dx, mid.dy);
    }
    path.lineTo(lowerBottom.first.dx, lowerBottom.first.dy);
    path.close();

    return path;
  }

  _LipGuideStyle _styleForPreset(MakeupLookPreset preset) {
    switch (preset) {
      case MakeupLookPreset.softGlam:
        return const _LipGuideStyle(
          guideColor: Color(0xFFE78AA5),
          fillWidthFactor: 0.88,
          fillHeightFactor: 0.80,
          centerWidthFactor: 0.34,
          centerHeightFactor: 0.38,
          showOverlineCue: true,
          centerBlendStrength: 0.32,
          cornerDepth: 0.18,
        );

      case MakeupLookPreset.emo:
        return const _LipGuideStyle(
          guideColor: Color(0xFF8C5BFF),
          fillWidthFactor: 0.94,
          fillHeightFactor: 0.86,
          centerWidthFactor: 0.26,
          centerHeightFactor: 0.28,
          showOverlineCue: false,
          centerBlendStrength: 0.10,
          cornerDepth: 0.36,
        );

      case MakeupLookPreset.dollKBeauty:
        return const _LipGuideStyle(
          guideColor: Color(0xFF5AC8FA),
          fillWidthFactor: 0.56,
          fillHeightFactor: 0.58,
          centerWidthFactor: 0.28,
          centerHeightFactor: 0.30,
          showOverlineCue: false,
          centerBlendStrength: 0.70,
          cornerDepth: 0.08,
        );

      case MakeupLookPreset.bronzedGoddess:
        return const _LipGuideStyle(
          guideColor: Color(0xFFFFA04A),
          fillWidthFactor: 0.89,
          fillHeightFactor: 0.82,
          centerWidthFactor: 0.32,
          centerHeightFactor: 0.35,
          showOverlineCue: true,
          centerBlendStrength: 0.24,
          cornerDepth: 0.20,
        );

      case MakeupLookPreset.boldEditorial:
        return const _LipGuideStyle(
          guideColor: Color(0xFFFF3B6B),
          fillWidthFactor: 0.95,
          fillHeightFactor: 0.88,
          centerWidthFactor: 0.24,
          centerHeightFactor: 0.25,
          showOverlineCue: true,
          centerBlendStrength: 0.08,
          cornerDepth: 0.30,
        );

      case MakeupLookPreset.debugPainterTest:
        return const _LipGuideStyle(
          guideColor: Color(0xFF00E5FF),
          fillWidthFactor: 0.95,
          fillHeightFactor: 0.90,
          centerWidthFactor: 0.24,
          centerHeightFactor: 0.25,
          showOverlineCue: true,
          centerBlendStrength: 0.08,
          cornerDepth: 0.30,
        );
    }
  }

  void _drawGuide(Canvas canvas, _LipGuideData g) {
    final guideColor = g.style.guideColor.withOpacity(0.95 * opacity);

    final outlinePaint = Paint()
      ..color = guideColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..isAntiAlias = true;

    final fillPaint = Paint()
      ..color = lipColor.withOpacity(0.22 * opacity)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final cornerPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(g.bounds.left, g.bounds.center.dy),
        Offset(g.bounds.right, g.bounds.center.dy),
        [
          lipColor.withOpacity(g.style.cornerDepth * opacity),
          lipColor.withOpacity(0.04 * opacity),
          lipColor.withOpacity(g.style.cornerDepth * opacity),
        ],
        const [0.0, 0.5, 1.0],
      )
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final centerPaint = Paint()
      ..shader = ui.Gradient.radial(
        g.centerGlowRect.center,
        max(g.centerGlowRect.width, g.centerGlowRect.height) * 0.7,
        [
          Colors.white.withOpacity(g.style.centerBlendStrength * 0.30 * opacity),
          Colors.white.withOpacity(0.0),
        ],
        const [0.0, 1.0],
      )
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final guideDottedPaint = Paint()
      ..color = guideColor.withOpacity(0.92)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..isAntiAlias = true;

    final arrowPaint = Paint()
      ..color = guideColor.withOpacity(0.88)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    // Outer lip shape
    canvas.drawPath(g.outerPath, outlinePaint);

    // Soft fill + corners + center
    canvas.save();
    canvas.clipPath(g.outerPath);
    canvas.drawRRect(
      RRect.fromRectAndRadius(g.fillRect, const Radius.circular(999)),
      fillPaint,
    );
    canvas.drawPath(g.outerPath, cornerPaint);
    canvas.drawRRect(
      RRect.fromRectAndRadius(g.centerGlowRect, const Radius.circular(999)),
      centerPaint,
    );
    canvas.restore();

    // Main fill zone hint
    _drawDottedOval(canvas, g.fillRect, guideDottedPaint);

    // Optional overline cue
    if (g.style.showOverlineCue) {
      _drawCupidOverlineCue(canvas, g, guideColor);
    }

    // Only keep small numbered markers on-image
    if (showStepNumbers) {
      _drawStepBadge(canvas, '1', g.cupidPoint.translate(-26, -12), guideColor);
      _drawStepBadge(canvas, '2', g.bounds.center.translate(0, -2), guideColor);
      _drawStepBadge(canvas, '3', g.rightCorner.translate(20, -4), guideColor);
    }

    // Minimal arrows
    if (showArrows) {
      _drawArrow(
        canvas,
        g.bounds.center.translate(-18, 0),
        g.bounds.center.translate(18, 0),
        arrowPaint,
      );
      _drawArrow(
        canvas,
        g.rightCorner.translate(-6, 0),
        g.rightCorner.translate(-18, 0),
        arrowPaint,
      );
      _drawArrow(
        canvas,
        g.leftCorner.translate(6, 0),
        g.leftCorner.translate(18, 0),
        arrowPaint,
      );
    }
  }

  void _drawDottedOval(Canvas canvas, Rect rect, Paint paint) {
    final path =
        Path()..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(999)));
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      const dash = 5.0;
      const gap = 4.0;
      while (distance < metric.length) {
        final next = min(distance + dash, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance += dash + gap;
      }
    }
  }

  void _drawCupidOverlineCue(Canvas canvas, _LipGuideData g, Color color) {
    final paint = Paint()
      ..color = color.withOpacity(0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..isAntiAlias = true;

    final w = g.bounds.width;
    final h = g.bounds.height;

    final left = Offset(g.bounds.center.dx - w * 0.11, g.bounds.top + h * 0.12);
    final mid = Offset(g.bounds.center.dx, g.bounds.top - h * 0.02);
    final right = Offset(g.bounds.center.dx + w * 0.11, g.bounds.top + h * 0.12);

    final path = Path()
      ..moveTo(left.dx, left.dy)
      ..quadraticBezierTo(
        g.bounds.center.dx - w * 0.04,
        g.bounds.top + h * 0.02,
        mid.dx,
        mid.dy,
      )
      ..quadraticBezierTo(
        g.bounds.center.dx + w * 0.04,
        g.bounds.top + h * 0.02,
        right.dx,
        right.dy,
      );

    canvas.drawPath(path, paint);
  }

  void _drawArrow(Canvas canvas, Offset from, Offset to, Paint paint) {
    canvas.drawLine(from, to, paint);

    final angle = atan2(to.dy - from.dy, to.dx - from.dx);
    const size = 4.2;

    final a1 = angle + pi * 0.82;
    final a2 = angle - pi * 0.82;

    final p1 = Offset(to.dx + cos(a1) * size, to.dy + sin(a1) * size);
    final p2 = Offset(to.dx + cos(a2) * size, to.dy + sin(a2) * size);

    canvas.drawLine(to, p1, paint);
    canvas.drawLine(to, p2, paint);
  }

  void _drawStepBadge(Canvas canvas, String text, Offset center, Color color) {
    final circlePaint = Paint()
      ..color = Colors.white.withOpacity(0.94)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final borderPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..isAntiAlias = true;

    canvas.drawCircle(center, 11, circlePaint);
    canvas.drawCircle(center, 11, borderPaint);

    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    tp.paint(canvas, center.translate(-tp.width / 2, -tp.height / 2));
  }

  void _drawFallback(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFF4D97).withOpacity(0.9 * opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..isAntiAlias = true;

    final rect = Rect.fromCenter(
      center: Offset(size.width * 0.5, size.height * 0.68),
      width: size.width * 0.22,
      height: size.height * 0.08,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(999)),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant LipGuidePainter oldDelegate) {
    return oldDelegate.face != face ||
        oldDelegate.preset != preset ||
        oldDelegate.lipColor != lipColor ||
        oldDelegate.opacity != opacity ||
        oldDelegate.showArrows != showArrows ||
        oldDelegate.showStepNumbers != showStepNumbers;
  }
}

class _LipGuideData {
  final Path outerPath;
  final Rect bounds;
  final Rect fillRect;
  final Rect centerGlowRect;
  final Offset cupidPoint;
  final Offset leftCorner;
  final Offset rightCorner;
  final _LipGuideStyle style;

  const _LipGuideData({
    required this.outerPath,
    required this.bounds,
    required this.fillRect,
    required this.centerGlowRect,
    required this.cupidPoint,
    required this.leftCorner,
    required this.rightCorner,
    required this.style,
  });
}

class _LipGuideStyle {
  final Color guideColor;
  final double fillWidthFactor;
  final double fillHeightFactor;
  final double centerWidthFactor;
  final double centerHeightFactor;
  final bool showOverlineCue;
  final double centerBlendStrength;
  final double cornerDepth;

  const _LipGuideStyle({
    required this.guideColor,
    required this.fillWidthFactor,
    required this.fillHeightFactor,
    required this.centerWidthFactor,
    required this.centerHeightFactor,
    required this.showOverlineCue,
    required this.centerBlendStrength,
    required this.cornerDepth,
  });
}