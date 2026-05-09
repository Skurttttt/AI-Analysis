import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../config/makeup_look_config.dart';
import '../config/styles/blush_style.dart';

class BlushContourGuidePainter extends CustomPainter {
  final Face face;
  final MakeupLookConfig config;
  final Size imageSize;
  final Color blushColor;
  final Color contourColor;

  const BlushContourGuidePainter({
    required this.face,
    required this.config,
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

    final style = config.blush;

    _drawBlushZones(canvas, faceRect, style);
    _drawContourZones(canvas, faceRect, style);
    _drawBlendGuide(canvas, faceRect);
    _drawStepLabels(canvas, faceRect, style);
  }

  void _drawBlushZones(
    Canvas canvas,
    Rect faceRect,
    BlushContourStyle style,
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
    BlushContourStyle style,
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
    BlushContourStyle style,
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
        oldDelegate.config != config ||
        oldDelegate.imageSize != imageSize ||
        oldDelegate.blushColor != blushColor ||
        oldDelegate.contourColor != contourColor;
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