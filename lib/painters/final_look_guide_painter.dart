import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class FinalLookGuidePainter extends CustomPainter {
  final Face face;
  final Size imageSize;

  const FinalLookGuidePainter({
    required this.face,
    required this.imageSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 ||
        size.height <= 0 ||
        imageSize.width <= 0 ||
        imageSize.height <= 0) {
      return;
    }

    final transform = _boxFitCoverTransform(
      originalImageSize: imageSize,
      canvasSize: size,
    );

    Offset mapPoint(math.Point<int> point) {
      return Offset(
        point.x.toDouble() * transform.scale + transform.dx,
        point.y.toDouble() * transform.scale + transform.dy,
      );
    }

    Rect mapRect(Rect rect) {
      return Rect.fromLTRB(
        rect.left * transform.scale + transform.dx,
        rect.top * transform.scale + transform.dy,
        rect.right * transform.scale + transform.dx,
        rect.bottom * transform.scale + transform.dy,
      );
    }

    final faceRect = mapRect(face.boundingBox);

    final nose = face.landmarks[FaceLandmarkType.noseBase];
    final leftEye = face.landmarks[FaceLandmarkType.leftEye];
    final rightEye = face.landmarks[FaceLandmarkType.rightEye];

    if (nose == null) return;

    final noseCenter = mapPoint(nose.position);

    final eyeCenter = (leftEye != null && rightEye != null)
        ? Offset(
            (mapPoint(leftEye.position).dx + mapPoint(rightEye.position).dx) / 2,
            (mapPoint(leftEye.position).dy + mapPoint(rightEye.position).dy) / 2,
          )
        : Offset(
            noseCenter.dx,
            faceRect.top + faceRect.height * 0.34,
          );

    // FIX 2: X intersection - moved up to just above nose tip
    final center = Offset(
      noseCenter.dx,
      noseCenter.dy - faceRect.height * 0.18,
    );

    final tGuidePaint = Paint()
      ..color = const Color(0xFFFF4D97).withOpacity(0.50)
      ..strokeWidth = 1.55
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;

    final xGuidePaint = Paint()
      ..color = const Color(0xFFFF4D97).withOpacity(0.36)
      ..strokeWidth = 1.25
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;

    final softGlowPaint = Paint()
      ..color = const Color(0xFFFF4D97).withOpacity(0.08)
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;

    final labelPaint = Paint()
      ..color = const Color(0xFFFF4D97).withOpacity(0.90)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final double topY =
        math.max(8.0, faceRect.top + faceRect.height * 0.02).toDouble();

    final double bottomY =
        math.min(size.height - 8.0, faceRect.bottom - faceRect.height * 0.03)
            .toDouble();

    // FIX 3: X lines shortened - reduced from edges
    final double leftX =
        math.max(8.0, faceRect.left + faceRect.width * 0.08).toDouble();

    final double rightX =
        math.min(size.width - 8.0, faceRect.right - faceRect.width * 0.08)
            .toDouble();

    final double xTopY = eyeCenter.dy - faceRect.height * 0.045;
    final double xBottomY = faceRect.bottom - faceRect.height * 0.12;

    final tTop = Offset(center.dx, topY);
    final tBottom = Offset(center.dx, bottomY);

    // Curved forehead T-line
    final tCurveLeft = Offset(
      faceRect.left + faceRect.width * 0.18,
      topY + faceRect.height * 0.035,
    );

    final tCurveRight = Offset(
      faceRect.right - faceRect.width * 0.18,
      topY + faceRect.height * 0.035,
    );

    // FIX 1: T curve - more dome-shaped (increased from 0.025 to 0.06)
    final tCurveControl = Offset(
      center.dx,
      topY - faceRect.height * 0.06,
    );

    final tCurvePath = Path()
      ..moveTo(tCurveLeft.dx, tCurveLeft.dy)
      ..quadraticBezierTo(
        tCurveControl.dx,
        tCurveControl.dy,
        tCurveRight.dx,
        tCurveRight.dy,
      );

    final xTopLeft = Offset(leftX, xTopY);
    final xBottomRight = Offset(rightX, xBottomY);

    final xTopRight = Offset(rightX, xTopY);
    final xBottomLeft = Offset(leftX, xBottomY);

    // Soft glow layer
    _drawDashedGuide(
      canvas,
      xTopLeft,
      xBottomRight,
      softGlowPaint,
      drawArrow: false,
    );
    _drawDashedGuide(
      canvas,
      xTopRight,
      xBottomLeft,
      softGlowPaint,
      drawArrow: false,
    );
    _drawDashedGuide(
      canvas,
      tTop,
      tBottom,
      softGlowPaint,
      drawArrow: false,
    );
    _drawDashedPath(canvas, tCurvePath, softGlowPaint, dash: 5.5, gap: 5.0);

    // Main guide layer
    _drawDashedGuide(
      canvas,
      xTopLeft,
      xBottomRight,
      xGuidePaint,
      drawArrow: true,
    );
    _drawDashedGuide(
      canvas,
      xTopRight,
      xBottomLeft,
      xGuidePaint,
      drawArrow: true,
    );
    _drawDashedGuide(
      canvas,
      tTop,
      tBottom,
      tGuidePaint,
      drawArrow: true,
    );
    _drawDashedPath(canvas, tCurvePath, tGuidePaint, dash: 5.5, gap: 5.0);

    // FIX 4: Labels - T MOTION position changed from -26 to -18
    _drawSoftLabel(
      canvas,
      text: 'T MOTION',
      position: Offset(center.dx, math.max(6.0, topY - 18).toDouble()),
      bgPaint: labelPaint,
      centerAlign: true,
    );

    _drawSoftLabel(
      canvas,
      text: 'X MOTION',
      position: Offset(
        math.max(8.0, faceRect.left - faceRect.width * 0.06).toDouble(),
        center.dy - faceRect.height * 0.10,
      ),
      bgPaint: labelPaint,
      centerAlign: false,
    );

    _drawSoftLabel(
      canvas,
      text: 'X MOTION',
      position: Offset(
        math.min(size.width - 84.0, faceRect.right - faceRect.width * 0.18)
            .toDouble(),
        center.dy - faceRect.height * 0.10,
      ),
      bgPaint: labelPaint,
      centerAlign: false,
    );
  }

  _ImageTransform _boxFitCoverTransform({
    required Size originalImageSize,
    required Size canvasSize,
  }) {
    final imageAspect = originalImageSize.width / originalImageSize.height;
    final canvasAspect = canvasSize.width / canvasSize.height;

    double scale;
    double dx = 0;
    double dy = 0;

    if (imageAspect > canvasAspect) {
      scale = canvasSize.height / originalImageSize.height;
      dx = (canvasSize.width - originalImageSize.width * scale) / 2;
    } else {
      scale = canvasSize.width / originalImageSize.width;
      dy = (canvasSize.height - originalImageSize.height * scale) / 2;
    }

    return _ImageTransform(scale: scale, dx: dx, dy: dy);
  }

  void _drawDashedGuide(
    Canvas canvas,
    Offset start,
    Offset end,
    Paint paint, {
    required bool drawArrow,
  }) {
    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..lineTo(end.dx, end.dy);

    _drawDashedPath(canvas, path, paint, dash: 5.5, gap: 5.0);

    if (drawArrow) {
      _drawSmallArrowHead(canvas, start, end, paint);
    }
  }

  void _drawSmallArrowHead(Canvas canvas, Offset start, Offset end, Paint paint) {
    final angle = math.atan2(end.dy - start.dy, end.dx - start.dx);
    const arrowSize = 7.0;

    final p1 = Offset(
      end.dx - arrowSize * math.cos(angle - math.pi / 6),
      end.dy - arrowSize * math.sin(angle - math.pi / 6),
    );

    final p2 = Offset(
      end.dx - arrowSize * math.cos(angle + math.pi / 6),
      end.dy - arrowSize * math.sin(angle + math.pi / 6),
    );

    canvas.drawLine(end, p1, paint);
    canvas.drawLine(end, p2, paint);
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
        final next = math.min(distance + dash, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance += dash + gap;
      }
    }
  }

  void _drawSoftLabel(
    Canvas canvas, {
    required String text,
    required Offset position,
    required Paint bgPaint,
    required bool centerAlign,
  }) {
    const hPad = 7.0;
    const vPad = 4.0;

    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 8.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final left = centerAlign ? position.dx - tp.width / 2 - hPad : position.dx;

    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        left,
        position.dy,
        tp.width + hPad * 2,
        tp.height + vPad * 2,
      ),
      const Radius.circular(7),
    );

    canvas.drawRRect(rect, bgPaint);

    tp.paint(canvas, Offset(left + hPad, position.dy + vPad));
  }

  @override
  bool shouldRepaint(covariant FinalLookGuidePainter oldDelegate) {
    return oldDelegate.face != face || oldDelegate.imageSize != imageSize;
  }
}

class _ImageTransform {
  final double scale;
  final double dx;
  final double dy;

  const _ImageTransform({
    required this.scale,
    required this.dx,
    required this.dy,
  });
}