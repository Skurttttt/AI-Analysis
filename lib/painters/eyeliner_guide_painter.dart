import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../look_engine.dart';

class EyelinerGuidePainter extends CustomPainter {
  final Face face;
  final MakeupLookPreset preset;
  final Color guideColor;

  const EyelinerGuidePainter({
    required this.face,
    required this.preset,
    this.guideColor = const Color(0xFFFF4D97),
  });

  @override
  void paint(Canvas canvas, Size size) {
    final leftEye =
        _toOffsets(face.contours[FaceContourType.leftEye]?.points);
    final rightEye =
        _toOffsets(face.contours[FaceContourType.rightEye]?.points);

    if (leftEye.length >= 6) {
      _drawEyeLiner(canvas, leftEye, isLeftEye: true);
    }

    if (rightEye.length >= 6) {
      _drawEyeLiner(canvas, rightEye, isLeftEye: false);
    }
  }

  List<Offset> _toOffsets(List<Point<int>>? points) {
    if (points == null) return const [];

    return points
        .map((p) => Offset(p.x.toDouble(), p.y.toDouble()))
        .toList(growable: false);
  }

  _EyelinerStyle _styleForPreset(MakeupLookPreset preset) {
    switch (preset) {
      case MakeupLookPreset.softGlam:
        return const _EyelinerStyle(
          wingLength: 0.34,
          wingLift: 0.52,
          lineThickness: 2.0,
          startInset: 0.20,
          angleGuideOpacity: 0.25,
        );

      case MakeupLookPreset.emo:
        return const _EyelinerStyle(
          wingLength: 0.48,
          wingLift: 0.40,
          lineThickness: 2.8,
          startInset: 0.06,
          angleGuideOpacity: 0.36,
        );

      case MakeupLookPreset.dollKBeauty:
        return const _EyelinerStyle(
          wingLength: 0.22,
          wingLift: 0.20,
          lineThickness: 1.7,
          startInset: 0.30,
          angleGuideOpacity: 0.18,
        );

      case MakeupLookPreset.bronzedGoddess:
        return const _EyelinerStyle(
          wingLength: 0.38,
          wingLift: 0.48,
          lineThickness: 2.2,
          startInset: 0.14,
          angleGuideOpacity: 0.28,
        );

      case MakeupLookPreset.boldEditorial:
      case MakeupLookPreset.debugPainterTest:
        return const _EyelinerStyle(
          wingLength: 0.58,
          wingLift: 0.64,
          lineThickness: 3.0,
          startInset: 0.04,
          angleGuideOpacity: 0.38,
        );
    }
  }

  void _drawEyeLiner(
    Canvas canvas,
    List<Offset> eyePoints, {
    required bool isLeftEye,
  }) {
    final points = List<Offset>.from(eyePoints)
      ..sort((a, b) => a.dx.compareTo(b.dx));

    final eyeBounds = _boundsOf(points);
    final eyeW = max(eyeBounds.width, 1.0);
    final eyeH = max(eyeBounds.height, 8.0);
    final style = _styleForPreset(preset);

    final innerX = isLeftEye ? eyeBounds.right : eyeBounds.left;
    final outerX = isLeftEye ? eyeBounds.left : eyeBounds.right;
    final direction = isLeftEye ? -1.0 : 1.0;

    final lashStart = Offset(
      innerX - direction * eyeW * style.startInset,
      eyeBounds.top + eyeH * 0.62,
    );

    final lashMid = Offset(
      eyeBounds.center.dx,
      eyeBounds.top + eyeH * 0.28,
    );

    final outerCorner = Offset(
      outerX,
      eyeBounds.top + eyeH * 0.56,
    );

    final wingTip = Offset(
      outerCorner.dx + direction * eyeW * style.wingLength,
      outerCorner.dy - eyeH * style.wingLift,
    );

    final flickControl = Offset(
      outerCorner.dx + direction * eyeW * 0.15,
      outerCorner.dy - eyeH * 0.22,
    );

    final angleStart = Offset(
      outerCorner.dx - direction * eyeW * 0.10,
      eyeBounds.bottom + eyeH * 0.18,
    );

    _drawAngleGuide(
      canvas: canvas,
      start: angleStart,
      end: wingTip,
      opacity: style.angleGuideOpacity,
    );

    final lashPath = Path()
      ..moveTo(lashStart.dx, lashStart.dy)
      ..quadraticBezierTo(
        lashMid.dx,
        lashMid.dy,
        outerCorner.dx,
        outerCorner.dy,
      );

    final wingPath = Path()
      ..moveTo(outerCorner.dx, outerCorner.dy)
      ..quadraticBezierTo(
        flickControl.dx,
        flickControl.dy,
        wingTip.dx,
        wingTip.dy,
      );

    final glowPaint = Paint()
      ..color = guideColor.withOpacity(0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = style.lineThickness + 4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    final lashPaint = Paint()
      ..color = guideColor.withOpacity(0.82)
      ..style = PaintingStyle.stroke
      ..strokeWidth = style.lineThickness
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    final outerEdgePaint = Paint()
      ..color = guideColor.withOpacity(0.98)
      ..style = PaintingStyle.stroke
      ..strokeWidth = style.lineThickness + 0.45
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    canvas.drawPath(lashPath, glowPaint);
    canvas.drawPath(lashPath, lashPaint);

    canvas.drawPath(wingPath, glowPaint);
    canvas.drawPath(wingPath, outerEdgePaint);

    final outerEdgeStart = Offset.lerp(lashMid, outerCorner, 0.45)!;

    final outerEdgePath = Path()
      ..moveTo(outerEdgeStart.dx, outerEdgeStart.dy)
      ..quadraticBezierTo(
        Offset.lerp(lashMid, outerCorner, 0.75)!.dx,
        Offset.lerp(lashMid, outerCorner, 0.75)!.dy - eyeH * 0.10,
        outerCorner.dx,
        outerCorner.dy,
      );

    canvas.drawPath(outerEdgePath, outerEdgePaint);

    _drawArrowHint(
      canvas,
      start: Offset.lerp(lashStart, lashMid, 0.55)!,
      end: Offset.lerp(lashMid, outerCorner, 0.75)!,
      opacity: 0.55,
    );

    _drawArrowHint(
      canvas,
      start: outerCorner,
      end: wingTip,
      opacity: 0.75,
    );

    _drawWingTipAccent(
      canvas,
      wingTip: wingTip,
      direction: direction,
      eyeW: eyeW,
      eyeH: eyeH,
      thickness: style.lineThickness,
    );

    _drawSmallStepLabel(
      canvas,
      '1',
      Offset.lerp(lashStart, lashMid, 0.52)!.translate(0, -eyeH * 0.55),
    );

    _drawSmallStepLabel(
      canvas,
      '2',
      outerCorner.translate(-direction * eyeW * 0.06, -eyeH * 0.72),
    );

    _drawSmallStepLabel(
      canvas,
      '3',
      wingTip.translate(direction * eyeW * 0.07, -eyeH * 0.08),
    );
  }

  void _drawWingTipAccent(
    Canvas canvas, {
    required Offset wingTip,
    required double direction,
    required double eyeW,
    required double eyeH,
    required double thickness,
  }) {
    final accentPaint = Paint()
      ..color = guideColor.withOpacity(0.95)
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1.2, thickness * 0.75)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    final upper = Offset(
      wingTip.dx - direction * eyeW * 0.08,
      wingTip.dy + eyeH * 0.03,
    );

    final lower = Offset(
      wingTip.dx - direction * eyeW * 0.06,
      wingTip.dy + eyeH * 0.16,
    );

    canvas.drawLine(upper, wingTip, accentPaint);
    canvas.drawLine(lower, wingTip, accentPaint);
  }

  void _drawArrowHint(
    Canvas canvas, {
    required Offset start,
    required Offset end,
    required double opacity,
  }) {
    final paint = Paint()
      ..color = guideColor.withOpacity(opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.15
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    canvas.drawLine(start, end, paint);

    final angle = atan2(end.dy - start.dy, end.dx - start.dx);
    const arrowSize = 4.5;

    final arrowPoint1 = Offset(
      end.dx - arrowSize * cos(angle - pi / 6),
      end.dy - arrowSize * sin(angle - pi / 6),
    );

    final arrowPoint2 = Offset(
      end.dx - arrowSize * cos(angle + pi / 6),
      end.dy - arrowSize * sin(angle + pi / 6),
    );

    canvas.drawLine(end, arrowPoint1, paint);
    canvas.drawLine(end, arrowPoint2, paint);
  }

  void _drawAngleGuide({
    required Canvas canvas,
    required Offset start,
    required Offset end,
    required double opacity,
  }) {
    final paint = Paint()
      ..color = guideColor.withOpacity(opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.05
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..lineTo(end.dx, end.dy);

    _drawDashedPath(canvas, path, paint, dash: 4, gap: 4);
  }

  void _drawSmallStepLabel(Canvas canvas, String text, Offset center) {
    final bgPaint = Paint()
      ..color = Colors.white.withOpacity(0.96)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final borderPaint = Paint()
      ..color = guideColor.withOpacity(0.95)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..isAntiAlias = true;

    canvas.drawCircle(center, 7.3, bgPaint);
    canvas.drawCircle(center, 7.3, borderPaint);

    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: guideColor,
          fontSize: 8.0,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    tp.paint(
      canvas,
      center.translate(-tp.width / 2, -tp.height / 2),
    );
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

  @override
  bool shouldRepaint(covariant EyelinerGuidePainter oldDelegate) {
    return oldDelegate.face != face ||
        oldDelegate.preset != preset ||
        oldDelegate.guideColor != guideColor;
  }
}

class _EyelinerStyle {
  final double wingLength;
  final double wingLift;
  final double lineThickness;
  final double startInset;
  final double angleGuideOpacity;

  const _EyelinerStyle({
    required this.wingLength,
    required this.wingLift,
    required this.lineThickness,
    required this.startInset,
    required this.angleGuideOpacity,
  });
}