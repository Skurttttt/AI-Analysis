// lib/painters/eyeshadow_painter.dart
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../utils.dart';

class EyeshadowPainter {
  final Face face;
  final Color eyeshadowColor;
  final double intensity;

  // ✅ per-eye eyeliner boundary
  final Path? leftEyelinerPath;
  final Path? rightEyelinerPath;

  // ✅ fix your compile error: supports debugMode named param
  final bool debugMode;

  EyeshadowPainter({
    required this.face,
    required this.eyeshadowColor,
    required this.intensity,
    this.leftEyelinerPath,
    this.rightEyelinerPath,
    this.debugMode = false,
  });

  void paint(Canvas canvas, Size size) {
    if (intensity <= 0.001) return;

    _paintEye(
      canvas: canvas,
      eyeType: FaceContourType.leftEye,
      eyelinerPath: leftEyelinerPath,
    );

    _paintEye(
      canvas: canvas,
      eyeType: FaceContourType.rightEye,
      eyelinerPath: rightEyelinerPath,
    );
  }

  void _paintEye({
    required Canvas canvas,
    required FaceContourType eyeType,
    required Path? eyelinerPath,
  }) {
    if (eyelinerPath == null) return;

    final pts = face.contours[eyeType]?.points;
    if (pts == null || pts.length < 6) return;

    final eyeOffsets = pts.map((p) => Offset(p.x.toDouble(), p.y.toDouble())).toList();
    final eyeBounds = DrawingUtils.boundsOf(eyeOffsets);

    final eyeW = eyeBounds.width;
    final eyeH = eyeBounds.height;

    // ✅ 1) Region above eyeliner (eyelid area) - then subtract eyeball hole
    final region = Path.from(eyelinerPath);

    region.addRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(
          eyeBounds.left - eyeW * 0.08,
          eyeBounds.top - eyeH * 1.35,
          eyeBounds.right + eyeW * 0.08,
          eyeBounds.top + eyeH * 0.12,
        ),
        Radius.circular(eyeH * 0.35),
      ),
    );

    final eyeHole = DrawingUtils.pathFromPoints(eyeOffsets);
    final finalRegion = Path.combine(PathOperation.difference, region, eyeHole);

    // ✅ 2) Main lid wash (realistic, not muddy)
    final lidShader = ui.Gradient.linear(
      Offset(eyeBounds.center.dx, eyeBounds.top + eyeH * 0.25),
      Offset(eyeBounds.center.dx, eyeBounds.top - eyeH * 1.05),
      [
        eyeshadowColor.withOpacity(0.30 * intensity),
        eyeshadowColor.withOpacity(0.16 * intensity),
        Colors.transparent,
      ],
      const [0.0, 0.55, 1.0],
    );

    final lidPaint = Paint()
      ..shader = lidShader
      ..blendMode = BlendMode.softLight
      ..isAntiAlias = true
      ..maskFilter = ui.MaskFilter.blur(
        ui.BlurStyle.normal,
        (eyeH * 0.55).clamp(4.0, 18.0),
      );

    canvas.drawPath(finalRegion, lidPaint);

    // ✅ 3) Crease depth (industry/capstone realism)
    final isLeft = eyeType == FaceContourType.leftEye;
    final outerX = isLeft ? eyeBounds.left : eyeBounds.right;

    final creaseShader = ui.Gradient.radial(
      Offset(outerX, eyeBounds.top - eyeH * 0.25),
      (eyeW * 0.95).clamp(18.0, 90.0),
      [
        eyeshadowColor.withOpacity(0.18 * intensity),
        eyeshadowColor.withOpacity(0.06 * intensity),
        Colors.transparent,
      ],
      const [0.0, 0.55, 1.0],
    );

    final creasePaint = Paint()
      ..shader = creaseShader
      ..blendMode = BlendMode.multiply
      ..isAntiAlias = true
      ..maskFilter = ui.MaskFilter.blur(
        ui.BlurStyle.normal,
        (eyeH * 0.40).clamp(3.0, 14.0),
      );

    canvas.drawPath(finalRegion, creasePaint);

    if (debugMode) {
      final dbg = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..color = Colors.green.withOpacity(0.7);
      canvas.drawRect(eyeBounds, dbg);
    }
  }
}
