// lib/contour_highlight_painter.dart
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../look_engine.dart'; // FaceShape

/// Soft, natural contour + highlight designed for real-time AR.
/// - Uses only face.boundingBox so it’s stable across devices.
/// - Uses very soft gradients + blur so it blends with skin.
/// - FaceShape slightly tweaks placement so it doesn’t look “one-size-fits-all”.
class ContourHighlightPainter {
  final Face face;
  final double intensity;
  final FaceShape faceShape;

  ContourHighlightPainter({
    required this.face,
    required this.intensity,
    required this.faceShape,
  });

  void paint(Canvas canvas, Size size) {
    final k = intensity.clamp(0.0, 1.0);
    if (k <= 0.001) return;

    final box = face.boundingBox;

    // Safety: don’t draw if bounding box looks invalid.
    if (box.width <= 1 || box.height <= 1) return;

    final faceW = box.width;
    final faceH = box.height;

    // Clip to a slightly expanded face region so contour/highlight never leaks.
    final clip = ui.Rect.fromLTRB(
      box.left - faceW * 0.08,
      box.top - faceH * 0.08,
      box.right + faceW * 0.08,
      box.bottom + faceH * 0.12,
    );

    canvas.save();
    canvas.clipRect(clip);

    // ----------------------------------------
    // Face-shape micro-adjustments
    // ----------------------------------------
    // These values are intentionally subtle (industry-style: “barely there”).
    double cheekHighlightY; // higher = closer to eye area
    double cheekContourY; // lower = more under cheekbone
    double jawStrength; // how strong jaw shadow is

    switch (faceShape) {
      case FaceShape.round:
        cheekHighlightY = 0.56; // slightly higher to lift
        cheekContourY = 0.72;
        jawStrength = 0.95;
        break;
      case FaceShape.square:
        cheekHighlightY = 0.58;
        cheekContourY = 0.74; // a bit lower
        jawStrength = 1.10; // square looks better with slightly defined jaw
        break;
      case FaceShape.heart:
        cheekHighlightY = 0.57;
        cheekContourY = 0.73;
        jawStrength = 0.90;
        break;
      case FaceShape.oval:
        cheekHighlightY = 0.57;
        cheekContourY = 0.73;
        jawStrength = 1.00;
        break;
      case FaceShape.unknown:
        cheekHighlightY = 0.57;
        cheekContourY = 0.73;
        jawStrength = 1.00;
        break;
    }

    // Pose gating: if head is turned too much, reduce the effect so it doesn’t “slide”.
    final yaw = (face.headEulerAngleY ?? 0.0).abs();
    final roll = (face.headEulerAngleZ ?? 0.0).abs();

    // 1.0 at normal pose → down to ~0.55 at high yaw/roll
    final poseAttenuation =
        (1.0 - (max(yaw / 35.0, roll / 35.0))).clamp(0.55, 1.0);

    final kk = (k * poseAttenuation).clamp(0.0, 1.0);

    // A very gentle global scaling so contour never overwhelms.
    final contourK = (0.22 * kk).clamp(0.0, 0.22);
    final highlightK = (0.26 * kk).clamp(0.0, 0.26);

    // ----------------------------------------
    // 1) Nose bridge highlight
    // ----------------------------------------
    // A soft vertical highlight down the bridge; fades out at bottom.
    final noseCenterX = box.left + faceW * 0.50;
    final noseTopY = box.top + faceH * 0.34;
    final noseBottomY = box.top + faceH * 0.62;

    final noseRect = ui.Rect.fromCenter(
      center: ui.Offset(noseCenterX, (noseTopY + noseBottomY) * 0.5),
      width: max(8.0, faceW * 0.055),
      height: max(12.0, (noseBottomY - noseTopY)),
    );

    final noseHighlightPaint = Paint()
      ..shader = ui.Gradient.linear(
        ui.Offset(noseRect.center.dx, noseRect.top),
        ui.Offset(noseRect.center.dx, noseRect.bottom),
        [
          Colors.white.withOpacity(0.28 * highlightK),
          Colors.white.withOpacity(0.08 * highlightK),
          Colors.white.withOpacity(0.0),
        ],
        [0.0, 0.55, 1.0],
      )
      ..blendMode = BlendMode.screen
      ..isAntiAlias = true
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 12);

    canvas.drawRRect(
      RRect.fromRectXY(noseRect, noseRect.width, noseRect.width),
      noseHighlightPaint,
    );

    // Small tip highlight (very subtle)
    final tip = ui.Offset(noseCenterX, box.top + faceH * 0.64);
    final tipPaint = Paint()
      ..shader = ui.Gradient.radial(
        tip,
        max(10.0, faceW * 0.06),
        [
          Colors.white.withOpacity(0.16 * highlightK),
          Colors.white.withOpacity(0.0),
        ],
        [0.0, 1.0],
      )
      ..blendMode = BlendMode.screen
      ..isAntiAlias = true
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 14);

    canvas.drawCircle(tip, max(6.0, faceW * 0.015), tipPaint);

    // ----------------------------------------
    // 2) Cheekbone highlights (left & right)
    // ----------------------------------------
    void drawCheekHighlight({required bool left}) {
      final cx = left ? (box.left + faceW * 0.32) : (box.left + faceW * 0.68);
      final cy = box.top + faceH * cheekHighlightY;

      final rect = ui.Rect.fromCenter(
        center: ui.Offset(cx, cy),
        width: faceW * 0.20,
        height: faceH * 0.07,
      );

      final paint = Paint()
        ..shader = ui.Gradient.radial(
          rect.center,
          max(rect.width, rect.height) * 0.75,
          [
            Colors.white.withOpacity(0.22 * highlightK),
            Colors.white.withOpacity(0.05 * highlightK),
            Colors.white.withOpacity(0.0),
          ],
          [0.0, 0.55, 1.0],
        )
        ..blendMode = BlendMode.screen
        ..isAntiAlias = true
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 16);

      canvas.drawRect(rect, paint);
    }

    drawCheekHighlight(left: true);
    drawCheekHighlight(left: false);

    // ----------------------------------------
    // 3) Cheek contour (below cheekbone)
    // ----------------------------------------
    // Using a soft radial dark that fades out.
    void drawCheekContour({required bool left}) {
      final cx = left ? (box.left + faceW * 0.34) : (box.left + faceW * 0.66);
      final cy = box.top + faceH * cheekContourY;

      final rect = ui.Rect.fromCenter(
        center: ui.Offset(cx, cy),
        width: faceW * 0.26,
        height: faceH * 0.10,
      );

      final paint = Paint()
        ..shader = ui.Gradient.radial(
          rect.center,
          max(rect.width, rect.height),
          [
            Colors.black.withOpacity(0.18 * contourK),
            Colors.black.withOpacity(0.06 * contourK),
            Colors.black.withOpacity(0.0),
          ],
          [0.0, 0.55, 1.0],
        )
        ..blendMode = BlendMode.multiply
        ..isAntiAlias = true
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 18);

      canvas.drawRect(rect, paint);
    }

    drawCheekContour(left: true);
    drawCheekContour(left: false);

    // ----------------------------------------
    // 4) Jawline contour
    // ----------------------------------------
    // A soft band at the bottom of the face for definition.
    final jawTop = box.top + faceH * 0.84;
    final jawBottom = box.top + faceH * 0.94;

    final jawRect = ui.Rect.fromLTRB(
      box.left + faceW * 0.16,
      jawTop,
      box.right - faceW * 0.16,
      jawBottom,
    );

    final jawPaint = Paint()
      ..shader = ui.Gradient.linear(
        ui.Offset(jawRect.left, jawRect.center.dy),
        ui.Offset(jawRect.right, jawRect.center.dy),
        [
          Colors.black.withOpacity(0.07 * contourK * jawStrength),
          Colors.black.withOpacity(0.14 * contourK * jawStrength),
          Colors.black.withOpacity(0.07 * contourK * jawStrength),
        ],
        [0.0, 0.5, 1.0],
      )
      ..blendMode = BlendMode.multiply
      ..isAntiAlias = true
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 20);

    canvas.drawRect(jawRect, jawPaint);

    // ----------------------------------------
    // 5) Temple contour (very subtle)
    // ----------------------------------------
    // Helps shape the face without looking like “paint”.
    void drawTempleContour({required bool left}) {
      final cx = left ? (box.left + faceW * 0.22) : (box.left + faceW * 0.78);
      final cy = box.top + faceH * 0.42;

      final rect = ui.Rect.fromCenter(
        center: ui.Offset(cx, cy),
        width: faceW * 0.20,
        height: faceH * 0.22,
      );

      final paint = Paint()
        ..shader = ui.Gradient.radial(
          rect.center,
          max(rect.width, rect.height),
          [
            Colors.black.withOpacity(0.10 * contourK),
            Colors.black.withOpacity(0.0),
          ],
          [0.0, 1.0],
        )
        ..blendMode = BlendMode.multiply
        ..isAntiAlias = true
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 22);

      canvas.drawRect(rect, paint);
    }

    drawTempleContour(left: true);
    drawTempleContour(left: false);

    canvas.restore();
  }
}
