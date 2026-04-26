import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class BasePrepGuidePainter extends CustomPainter {
  final Face face;
  final Color guideColor;

  const BasePrepGuidePainter({
    required this.face,
    this.guideColor = const Color(0xFFFF4D97),
  });

  @override
  void paint(Canvas canvas, Size size) {
    final faceRect = face.boundingBox;
    if (faceRect.width <= 0 || faceRect.height <= 0) return;

    final faceW = faceRect.width;
    final faceH = faceRect.height;
    final center = faceRect.center;

    // =========================
    // 1. SOFT GLOW (PREMIUM LOOK)
    // =========================

    // T-Zone glow (forehead + nose)
    _drawAirbrushGlow(
      canvas,
      Rect.fromCenter(
        center: Offset(center.dx, faceRect.top + faceH * 0.34),
        width: faceW * 0.26,
        height: faceH * 0.48,
      ),
      guideColor.withOpacity(0.14),
    );

    // Nose highlight
    _drawAirbrushGlow(
      canvas,
      Rect.fromCenter(
        center: Offset(center.dx, faceRect.top + faceH * 0.46),
        width: faceW * 0.16,
        height: faceH * 0.32,
      ),
      Colors.white.withOpacity(0.12),
    );

    // Cheeks glow
    _drawAirbrushGlow(
      canvas,
      Rect.fromCenter(
        center: Offset(faceRect.left + faceW * 0.30, faceRect.top + faceH * 0.56),
        width: faceW * 0.34,
        height: faceH * 0.24,
      ),
      guideColor.withOpacity(0.14),
    );

    _drawAirbrushGlow(
      canvas,
      Rect.fromCenter(
        center: Offset(faceRect.right - faceW * 0.30, faceRect.top + faceH * 0.56),
        width: faceW * 0.34,
        height: faceH * 0.24,
      ),
      guideColor.withOpacity(0.14),
    );

    // =========================
    // 2. INSTRUCTION LINES
    // =========================

    // T-Zone vertical (Prime)
    _drawSoftFlowLine(
      canvas,
      from: Offset(center.dx, faceRect.top + faceH * 0.25),
      control: Offset(center.dx + 4, faceRect.top + faceH * 0.40),
      to: Offset(center.dx, faceRect.top + faceH * 0.54),
      emphasize: true,
    );

    // LEFT cheek (Blend)
    _drawSoftFlowLine(
      canvas,
      from: Offset(center.dx - faceW * 0.08, faceRect.top + faceH * 0.55),
      control: Offset(faceRect.left + faceW * 0.28, faceRect.top + faceH * 0.58),
      to: Offset(faceRect.left + faceW * 0.18, faceRect.top + faceH * 0.53),
    );

    // RIGHT cheek (Blend)
    _drawSoftFlowLine(
      canvas,
      from: Offset(center.dx + faceW * 0.08, faceRect.top + faceH * 0.55),
      control: Offset(faceRect.right - faceW * 0.28, faceRect.top + faceH * 0.58),
      to: Offset(faceRect.right - faceW * 0.18, faceRect.top + faceH * 0.53),
    );

    // =========================
    // 3. UNDER-EYE LINES (NO DOTS)
    // =========================

    _drawUnderEyeGuide(canvas, faceRect, faceW, faceH);

    // =========================
    // 4. LABELS
    // =========================

    _drawLabel(
      canvas,
      'Prime',
      Offset(center.dx - 20, faceRect.top + faceH * 0.21),
    );

    _drawLabel(
      canvas,
      'Blend',
      Offset(faceRect.left + faceW * 0.17, faceRect.top + faceH * 0.61),
    );

    _drawLabel(
      canvas,
      'Blend',
      Offset(faceRect.right - faceW * 0.34, faceRect.top + faceH * 0.61),
    );
  }

  // =========================
  // GLOW
  // =========================

  void _drawAirbrushGlow(Canvas canvas, Rect rect, Color color) {
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          color,
          color.withOpacity(color.opacity * 0.4),
          Colors.transparent,
        ],
        stops: const [0.0, 0.6, 1.0],
      ).createShader(rect)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20)
      ..style = PaintingStyle.fill;

    canvas.drawOval(rect, paint);
  }

  // =========================
  // FLOW LINES
  // =========================

  void _drawSoftFlowLine(
    Canvas canvas, {
    required Offset from,
    required Offset control,
    required Offset to,
    bool emphasize = false,
  }) {
    final glowPaint = Paint()
      ..color = guideColor.withOpacity(emphasize ? 0.18 : 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = emphasize ? 5 : 4;

    final linePaint = Paint()
      ..color = guideColor.withOpacity(0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final path = Path()
      ..moveTo(from.dx, from.dy)
      ..quadraticBezierTo(control.dx, control.dy, to.dx, to.dy);

    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, linePaint);

    _drawArrowHead(canvas, control, to, linePaint);
  }

  void _drawArrowHead(Canvas canvas, Offset control, Offset to, Paint paint) {
    final angle = atan2(to.dy - control.dy, to.dx - control.dx);
    const size = 5.0;

    final p1 = Offset(
      to.dx - size * cos(angle - pi / 6),
      to.dy - size * sin(angle - pi / 6),
    );

    final p2 = Offset(
      to.dx - size * cos(angle + pi / 6),
      to.dy - size * sin(angle + pi / 6),
    );

    canvas.drawLine(to, p1, paint);
    canvas.drawLine(to, p2, paint);
  }

  // =========================
  // UNDER EYE LINES (FIXED)
  // =========================

  void _drawUnderEyeGuide(
    Canvas canvas,
    Rect faceRect,
    double faceW,
    double faceH,
  ) {
    final paint = Paint()
      ..color = guideColor.withOpacity(0.65)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final pathLeft = Path()
      ..moveTo(faceRect.left + faceW * 0.25, faceRect.top + faceH * 0.45)
      ..quadraticBezierTo(
        faceRect.left + faceW * 0.34,
        faceRect.top + faceH * 0.48,
        faceRect.left + faceW * 0.43,
        faceRect.top + faceH * 0.45,
      );

    final pathRight = Path()
      ..moveTo(faceRect.right - faceW * 0.43, faceRect.top + faceH * 0.45)
      ..quadraticBezierTo(
        faceRect.right - faceW * 0.34,
        faceRect.top + faceH * 0.48,
        faceRect.right - faceW * 0.25,
        faceRect.top + faceH * 0.45,
      );

    canvas.drawPath(pathLeft, paint);
    canvas.drawPath(pathRight, paint);

    _drawLabelCenter(canvas,
        Offset(faceRect.left + faceW * 0.34, faceRect.top + faceH * 0.50), "Brighten");

    _drawLabelCenter(canvas,
        Offset(faceRect.right - faceW * 0.34, faceRect.top + faceH * 0.50), "Brighten");
  }

  // =========================
  // LABELS
  // =========================

  void _drawLabel(Canvas canvas, String text, Offset pos) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Color(0xFFFF4D97),
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final bg = Paint()
      ..color = Colors.white.withOpacity(0.65);

    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(pos.dx - 6, pos.dy - 4, tp.width + 12, tp.height + 8),
      const Radius.circular(8),
    );

    canvas.drawRRect(rect, bg);
    tp.paint(canvas, pos);
  }

  void _drawLabelCenter(Canvas canvas, Offset pos, String text) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Color(0xFFFF4D97),
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final bg = Paint()
      ..color = Colors.white.withOpacity(0.65);

    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        pos.dx - tp.width / 2 - 6,
        pos.dy - 4,
        tp.width + 12,
        tp.height + 8,
      ),
      const Radius.circular(8),
    );

    canvas.drawRRect(rect, bg);
    tp.paint(canvas, Offset(pos.dx - tp.width / 2, pos.dy));
  }

  @override
  bool shouldRepaint(covariant BasePrepGuidePainter oldDelegate) {
    return oldDelegate.face != face || oldDelegate.guideColor != guideColor;
  }
}