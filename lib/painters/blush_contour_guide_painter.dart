import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../look_engine.dart';

class BlushContourGuidePainter extends CustomPainter {
  final Face face;
  final MakeupLookPreset preset;
  final Size imageSize;
  final Color blushColor;
  final Color contourColor;

  const BlushContourGuidePainter({
    required this.face,
    required this.preset,
    required this.imageSize,
    this.blushColor = const Color(0xFFFF4D97),
    this.contourColor = const Color(0xFF8B5A3C),
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

    Rect mapRect(Rect rect) {
      return Rect.fromLTRB(
        rect.left * transform.scale + transform.dx,
        rect.top * transform.scale + transform.dy,
        rect.right * transform.scale + transform.dx,
        rect.bottom * transform.scale + transform.dy,
      );
    }

    final faceRect = mapRect(face.boundingBox);

    if (faceRect.width <= 0 || faceRect.height <= 0) return;

    final style = _styleForPreset(preset);

    _drawBlushZones(canvas, faceRect, style);
    _drawContourZones(canvas, faceRect, style);
    _drawBlendGuide(canvas, faceRect);
    _drawStepLabels(canvas, faceRect, style);
  }

  _BlushContourStyle _styleForPreset(MakeupLookPreset preset) {
    switch (preset) {
      case MakeupLookPreset.softGlam:
        return const _BlushContourStyle(
          blushY: 0.53,
          blushX: 0.31,
          blushW: 0.24,
          blushH: 0.085,
          blushAngle: -0.20,
          contourY: 0.63,
          contourW: 0.28,
          contourH: 0.045,
          contourAngle: -0.28,
          blushOpacity: 0.22,
          contourOpacity: 0.18,
        );

      case MakeupLookPreset.emo:
        return const _BlushContourStyle(
          blushY: 0.57,
          blushX: 0.30,
          blushW: 0.25,
          blushH: 0.070,
          blushAngle: -0.12,
          contourY: 0.64,
          contourW: 0.34,
          contourH: 0.045,
          contourAngle: -0.18,
          blushOpacity: 0.16,
          contourOpacity: 0.24,
        );

      case MakeupLookPreset.dollKBeauty:
        return const _BlushContourStyle(
          blushY: 0.50,
          blushX: 0.36,
          blushW: 0.20,
          blushH: 0.080,
          blushAngle: -0.06,
          contourY: 0.64,
          contourW: 0.20,
          contourH: 0.035,
          contourAngle: -0.18,
          blushOpacity: 0.24,
          contourOpacity: 0.10,
        );

      case MakeupLookPreset.bronzedGoddess:
        return const _BlushContourStyle(
          blushY: 0.54,
          blushX: 0.30,
          blushW: 0.27,
          blushH: 0.080,
          blushAngle: -0.30,
          contourY: 0.63,
          contourW: 0.34,
          contourH: 0.050,
          contourAngle: -0.32,
          blushOpacity: 0.18,
          contourOpacity: 0.26,
        );

      case MakeupLookPreset.boldEditorial:
      case MakeupLookPreset.debugPainterTest:
        return const _BlushContourStyle(
          blushY: 0.53,
          blushX: 0.29,
          blushW: 0.30,
          blushH: 0.085,
          blushAngle: -0.36,
          contourY: 0.62,
          contourW: 0.36,
          contourH: 0.055,
          contourAngle: -0.36,
          blushOpacity: 0.24,
          contourOpacity: 0.28,
        );
    }
  }

  void _drawBlushZones(
    Canvas canvas,
    Rect faceRect,
    _BlushContourStyle style,
  ) {
    final blushPaint = Paint()
      ..color = blushColor.withOpacity(style.blushOpacity)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10)
      ..isAntiAlias = true;

    final blushBorderPaint = Paint()
      ..color = blushColor.withOpacity(0.48)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..isAntiAlias = true;

    final cheekW = faceRect.width * style.blushW;
    final cheekH = faceRect.height * style.blushH;

    final leftCheekCenter = Offset(
      faceRect.left + faceRect.width * style.blushX,
      faceRect.top + faceRect.height * style.blushY,
    );

    final rightCheekCenter = Offset(
      faceRect.left + faceRect.width * (1 - style.blushX),
      faceRect.top + faceRect.height * style.blushY,
    );

    _drawTiltedOval(
      canvas,
      center: leftCheekCenter,
      width: cheekW,
      height: cheekH,
      angle: style.blushAngle,
      fillPaint: blushPaint,
      borderPaint: blushBorderPaint,
    );

    _drawTiltedOval(
      canvas,
      center: rightCheekCenter,
      width: cheekW,
      height: cheekH,
      angle: -style.blushAngle,
      fillPaint: blushPaint,
      borderPaint: blushBorderPaint,
    );
  }

  void _drawContourZones(
    Canvas canvas,
    Rect faceRect,
    _BlushContourStyle style,
  ) {
    final contourPaint = Paint()
      ..color = contourColor.withOpacity(style.contourOpacity)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9)
      ..isAntiAlias = true;

    final contourLinePaint = Paint()
      ..color = contourColor.withOpacity(0.48)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.15
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    final cheekContourW = faceRect.width * style.contourW;
    final cheekContourH = faceRect.height * style.contourH;

    final leftContourCenter = Offset(
      faceRect.left + faceRect.width * 0.31,
      faceRect.top + faceRect.height * style.contourY,
    );

    final rightContourCenter = Offset(
      faceRect.left + faceRect.width * 0.69,
      faceRect.top + faceRect.height * style.contourY,
    );

    _drawTiltedOval(
      canvas,
      center: leftContourCenter,
      width: cheekContourW,
      height: cheekContourH,
      angle: style.contourAngle,
      fillPaint: contourPaint,
      borderPaint: contourLinePaint,
    );

    _drawTiltedOval(
      canvas,
      center: rightContourCenter,
      width: cheekContourW,
      height: cheekContourH,
      angle: -style.contourAngle,
      fillPaint: contourPaint,
      borderPaint: contourLinePaint,
    );

    final leftJawStart = Offset(
      faceRect.left + faceRect.width * 0.24,
      faceRect.top + faceRect.height * 0.78,
    );

    final leftJawEnd = Offset(
      faceRect.left + faceRect.width * 0.40,
      faceRect.top + faceRect.height * 0.86,
    );

    final rightJawStart = Offset(
      faceRect.left + faceRect.width * 0.76,
      faceRect.top + faceRect.height * 0.78,
    );

    final rightJawEnd = Offset(
      faceRect.left + faceRect.width * 0.60,
      faceRect.top + faceRect.height * 0.86,
    );

    canvas.drawLine(leftJawStart, leftJawEnd, contourLinePaint);
    canvas.drawLine(rightJawStart, rightJawEnd, contourLinePaint);
  }

  void _drawBlendGuide(Canvas canvas, Rect faceRect) {
    final blendPaint = Paint()
      ..color = blushColor.withOpacity(0.28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    final leftStart = Offset(
      faceRect.left + faceRect.width * 0.34,
      faceRect.top + faceRect.height * 0.58,
    );

    final leftEnd = Offset(
      faceRect.left + faceRect.width * 0.22,
      faceRect.top + faceRect.height * 0.48,
    );

    final rightStart = Offset(
      faceRect.left + faceRect.width * 0.66,
      faceRect.top + faceRect.height * 0.58,
    );

    final rightEnd = Offset(
      faceRect.left + faceRect.width * 0.78,
      faceRect.top + faceRect.height * 0.48,
    );

    _drawSoftArrow(canvas, leftStart, leftEnd, blendPaint);
    _drawSoftArrow(canvas, rightStart, rightEnd, blendPaint);
  }

  void _drawStepLabels(
    Canvas canvas,
    Rect faceRect,
    _BlushContourStyle style,
  ) {
    _drawSmallStepLabel(
      canvas,
      '1',
      Offset(
        faceRect.left + faceRect.width * style.blushX,
        faceRect.top + faceRect.height * (style.blushY - 0.065),
      ),
      blushColor,
    );

    _drawSmallStepLabel(
      canvas,
      '1',
      Offset(
        faceRect.left + faceRect.width * (1 - style.blushX),
        faceRect.top + faceRect.height * (style.blushY - 0.065),
      ),
      blushColor,
    );

    _drawSmallStepLabel(
      canvas,
      '2',
      Offset(
        faceRect.left + faceRect.width * 0.23,
        faceRect.top + faceRect.height * (style.contourY - 0.025),
      ),
      contourColor,
    );

    _drawSmallStepLabel(
      canvas,
      '2',
      Offset(
        faceRect.left + faceRect.width * 0.77,
        faceRect.top + faceRect.height * (style.contourY - 0.025),
      ),
      contourColor,
    );

    _drawSmallStepLabel(
      canvas,
      '3',
      Offset(
        faceRect.left + faceRect.width * 0.50,
        faceRect.top + faceRect.height * 0.71,
      ),
      blushColor,
    );
  }

  void _drawTiltedOval(
    Canvas canvas, {
    required Offset center,
    required double width,
    required double height,
    required double angle,
    required Paint fillPaint,
    required Paint borderPaint,
  }) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);

    final rect = Rect.fromCenter(
      center: Offset.zero,
      width: width,
      height: height,
    );

    canvas.drawOval(rect, fillPaint);
    canvas.drawOval(rect, borderPaint);

    canvas.restore();
  }

  void _drawSoftArrow(
    Canvas canvas,
    Offset start,
    Offset end,
    Paint paint,
  ) {
    canvas.drawLine(start, end, paint);

    final angle = math.atan2(end.dy - start.dy, end.dx - start.dx);
    const arrowSize = 5.0;

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

  void _drawSmallStepLabel(
    Canvas canvas,
    String text,
    Offset center,
    Color color,
  ) {
    final bgPaint = Paint()
      ..color = Colors.white.withOpacity(0.94)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final borderPaint = Paint()
      ..color = color.withOpacity(0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..isAntiAlias = true;

    canvas.drawCircle(center, 7.5, bgPaint);
    canvas.drawCircle(center, 7.5, borderPaint);

    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
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

  @override
  bool shouldRepaint(covariant BlushContourGuidePainter oldDelegate) {
    return oldDelegate.face != face ||
        oldDelegate.preset != preset ||
        oldDelegate.imageSize != imageSize ||
        oldDelegate.blushColor != blushColor ||
        oldDelegate.contourColor != contourColor;
  }
}

class _BlushContourStyle {
  final double blushY;
  final double blushX;
  final double blushW;
  final double blushH;
  final double blushAngle;
  final double contourY;
  final double contourW;
  final double contourH;
  final double contourAngle;
  final double blushOpacity;
  final double contourOpacity;

  const _BlushContourStyle({
    required this.blushY,
    required this.blushX,
    required this.blushW,
    required this.blushH,
    required this.blushAngle,
    required this.contourY,
    required this.contourW,
    required this.contourH,
    required this.contourAngle,
    required this.blushOpacity,
    required this.contourOpacity,
  });
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