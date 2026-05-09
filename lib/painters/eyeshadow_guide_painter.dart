import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../config/makeup_look_config.dart';

class EyeshadowGuidePalette {
  final Color lidColor;
  final Color creaseColor;
  final Color outerColor;
  final Color guideColor;

  const EyeshadowGuidePalette({
    required this.lidColor,
    required this.creaseColor,
    required this.outerColor,
    this.guideColor = const Color(0xFFFF4D97),
  });
}

class EyeshadowGuidePainter extends CustomPainter {
  final Face face;
  final MakeupLookConfig config;
  final EyeshadowGuidePalette palette;

  const EyeshadowGuidePainter({
    required this.face,
    required this.config,
    required this.palette,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final leftEye = _toOffsets(face.contours[FaceContourType.leftEye]?.points);
    final rightEye = _toOffsets(face.contours[FaceContourType.rightEye]?.points);

    if (leftEye.length >= 6) {
      _drawEye(canvas, leftEye, isLeftEye: true);
    }

    if (rightEye.length >= 6) {
      _drawEye(canvas, rightEye, isLeftEye: false);
    }
  }

  List<Offset> _toOffsets(List<Point<int>>? points) {
    if (points == null) return const [];

    return points
        .map((p) => Offset(p.x.toDouble(), p.y.toDouble()))
        .toList(growable: false);
  }

  void _drawEye(
    Canvas canvas,
    List<Offset> eyePoints, {
    required bool isLeftEye,
  }) {
    final points = List<Offset>.from(eyePoints)
      ..sort((a, b) => a.dx.compareTo(b.dx));

    final eyeBounds = _boundsOf(points);
    final eyeW = max(eyeBounds.width, 1.0);
    final eyeH = max(eyeBounds.height, 8.0);
    
    final style = config.eyeshadow;

    final innerX = eyeBounds.left;
    final outerX = eyeBounds.right;
    final centerX = eyeBounds.center.dx;

    final actualOuterX = isLeftEye ? innerX : outerX;
    final outerDirection = isLeftEye ? -1.0 : 1.0;

    // 1) Lid zone — main shade placement.
    final lidRect = Rect.fromCenter(
      center: Offset(centerX, eyeBounds.center.dy - eyeH * 0.08),
      width: eyeW * 0.88,
      height: eyeH * style.lidHeight,
    );

    _drawLidZone(
      canvas,
      lidRect,
      palette.lidColor.withOpacity(style.lidOpacity),
    );

    // 2) Crease guide — blend above lid.
    final creaseStart = Offset(
      eyeBounds.left + eyeW * 0.12,
      eyeBounds.top - eyeH * 0.18,
    );

    final creaseEnd = Offset(
      eyeBounds.right - eyeW * 0.12,
      eyeBounds.top - eyeH * 0.18,
    );

    final creaseControl = Offset(
      centerX,
      eyeBounds.top - eyeH * style.creaseLift,
    );

    final creasePath = Path()
      ..moveTo(creaseStart.dx, creaseStart.dy)
      ..quadraticBezierTo(
        creaseControl.dx,
        creaseControl.dy,
        creaseEnd.dx,
        creaseEnd.dy,
      );

    _drawCreaseZone(
      canvas,
      creasePath,
      palette.creaseColor.withOpacity(style.creaseOpacity),
    );

    // 3) Outer depth / outer V.
    final outerCenter = Offset(
      actualOuterX,
      eyeBounds.center.dy - eyeH * style.outerLift,
    );

    if (style.showOuterV) {
      _drawOuterDepth(
        canvas,
        outerCenter: outerCenter,
        eyeW: eyeW,
        eyeH: eyeH,
        direction: outerDirection,
        color: palette.outerColor.withOpacity(style.outerOpacity),
        sizeFactor: style.outerSize,
      );
    } else {
      _drawSoftOvalZone(
        canvas,
        Rect.fromCenter(
          center: outerCenter,
          width: eyeW * style.outerSize,
          height: eyeH * 0.72,
        ),
        palette.outerColor.withOpacity(style.outerOpacity),
        blur: 6,
      );
    }

    if (style.showLowerLash) {
      _drawLowerLashSoftShade(
        canvas,
        eyeBounds,
        palette.outerColor.withOpacity(0.28),
      );
    }

    // ========== VISUAL GUIDES ==========
    
    // 1) LID LINE (Step 1) - Shows "Swipe across eyelid"
    final lidLine = Path()
      ..moveTo(eyeBounds.left + eyeW * 0.2, eyeBounds.center.dy)
      ..lineTo(eyeBounds.right - eyeW * 0.2, eyeBounds.center.dy);

    canvas.drawPath(
      lidLine,
      Paint()
        ..color = palette.guideColor.withOpacity(0.5)
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    _drawSmallStepLabel(
      canvas,
      '1',
      Offset(centerX, eyeBounds.center.dy - 10),
      palette.guideColor,
    );

    // 2) CREASE ARC (Step 2) - Shows "Blend upward"
    _drawSmallStepLabel(
      canvas,
      '2',
      Offset(centerX, creaseControl.dy - 8),
      palette.guideColor,
    );

    // 3) DEPTH LINE (Step 3) - Shows outer corner definition
    final depthLine = Path()
      ..moveTo(actualOuterX, eyeBounds.center.dy)
      ..lineTo(
        actualOuterX + outerDirection * eyeW * 0.18,
        eyeBounds.center.dy - eyeH * 0.25,
      );

    canvas.drawPath(
      depthLine,
      Paint()
        ..color = palette.guideColor.withOpacity(0.6)
        ..strokeWidth = 1.3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    _drawSmallStepLabel(
      canvas,
      '3',
      Offset(
        actualOuterX + outerDirection * eyeW * 0.22,
        eyeBounds.center.dy - eyeH * 0.28,
      ),
      palette.guideColor,
    );
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

  void _drawLidZone(Canvas canvas, Rect rect, Color color) {
    _drawSoftOvalZone(canvas, rect, color, blur: 7);

    final guidePaint = Paint()
      ..color = palette.guideColor.withOpacity(0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    canvas.drawOval(rect.deflate(1.5), guidePaint);
  }

  void _drawCreaseZone(Canvas canvas, Path path, Color color) {
    final glowPaint = Paint()
      ..color = color.withOpacity(0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7.0
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3)
      ..isAntiAlias = true;

    final guidePaint = Paint()
      ..color = palette.guideColor.withOpacity(0.58)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.25
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    canvas.drawPath(path, glowPaint);
    _drawDashedPath(canvas, path, guidePaint, dash: 4, gap: 4);
  }

  void _drawOuterDepth(
    Canvas canvas, {
    required Offset outerCenter,
    required double eyeW,
    required double eyeH,
    required double direction,
    required Color color,
    required double sizeFactor,
  }) {
    final w = eyeW * sizeFactor;
    final h = eyeH * 1.20;

    final path = Path()
      ..moveTo(outerCenter.dx, outerCenter.dy - h * 0.55)
      ..quadraticBezierTo(
        outerCenter.dx + direction * w * 0.85,
        outerCenter.dy,
        outerCenter.dx,
        outerCenter.dy + h * 0.55,
      )
      ..quadraticBezierTo(
        outerCenter.dx + direction * w * 0.20,
        outerCenter.dy,
        outerCenter.dx,
        outerCenter.dy - h * 0.55,
      );

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5)
      ..isAntiAlias = true;

    canvas.drawPath(path, paint);

    final outlinePaint = Paint()
      ..color = palette.guideColor.withOpacity(0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    canvas.drawPath(path, outlinePaint);
  }

  void _drawLowerLashSoftShade(Canvas canvas, Rect bounds, Color color) {
    final path = Path()
      ..moveTo(bounds.left + bounds.width * 0.22, bounds.bottom + bounds.height * 0.22)
      ..quadraticBezierTo(
        bounds.center.dx,
        bounds.bottom + bounds.height * 0.42,
        bounds.right - bounds.width * 0.22,
        bounds.bottom + bounds.height * 0.22,
      );

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5)
      ..isAntiAlias = true;

    canvas.drawPath(path, paint);
  }

  void _drawSoftOvalZone(
    Canvas canvas,
    Rect rect,
    Color color, {
    double blur = 6,
  }) {
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          color,
          color.withOpacity(color.opacity * 0.45),
          Colors.transparent,
        ],
        stops: const [0.0, 0.62, 1.0],
      ).createShader(rect)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    canvas.drawOval(rect, paint);
  }

  void _drawSmallStepLabel(Canvas canvas, String text, Offset position, Color color) {
    final bgPaint = Paint()
      ..color = Colors.white.withOpacity(0.9)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    canvas.drawCircle(position, 7, bgPaint);
    canvas.drawCircle(position, 7, borderPaint);

    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: 8,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    tp.paint(canvas, position.translate(-tp.width / 2, -tp.height / 2));
  }

  void _drawDashedPath(
    Canvas canvas,
    Path path,
    Paint paint, {
    required double dash,
    required double gap,
  }) {
    for (final metric in path.computeMetrics()) {
      double distance = 0;

      while (distance < metric.length) {
        final next = min(distance + dash, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant EyeshadowGuidePainter oldDelegate) {
    return oldDelegate.face != face ||
        oldDelegate.config != config ||
        oldDelegate.palette != palette;
  }
}