import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../utils.dart'; // ✅ single source of truth for LipFinish + DrawingUtils

class LipPainter {
  final Face face;
  final Color lipstickColor;
  final double intensity;
  final LipFinish lipFinish;

  LipPainter({
    required this.face,
    required this.lipstickColor,
    required this.intensity,
    this.lipFinish = LipFinish.glossy,
  });

  void paint(Canvas canvas, Size size) {
    final k = intensity.clamp(0.0, 1.0);
    if (k <= 0.001) return;

    // ML Kit lip contours
    final upper = face.contours[FaceContourType.upperLipTop]?.points;
    final lower = face.contours[FaceContourType.lowerLipBottom]?.points;

    // If contours missing, do nothing (avoid weird artifacts)
    if (upper == null || lower == null || upper.length < 6 || lower.length < 6) return;

    // Convert to Offsets
    final upperPts = upper.map((p) => ui.Offset(p.x.toDouble(), p.y.toDouble())).toList();
    final lowerPts = lower.map((p) => ui.Offset(p.x.toDouble(), p.y.toDouble())).toList();

    // Build a closed lip region path (upper + reversed lower)
    final lipPath = _buildLipRegionPath(upperPts, lowerPts);

    // Bounds / scale-aware blur
    final bounds = lipPath.getBounds();
    final lipW = bounds.width;
    final lipH = bounds.height;
    if (lipW <= 1 || lipH <= 1) return;

    final sigmaBase = max(lipW, lipH) * 0.035; // tuned for lips
    final sigmaSoft = sigmaBase * 0.9;
    final sigmaFeather = sigmaBase * 1.35;

    // Center for gradients
    final center = bounds.center;

    // Finish tuning
    final isMatte = lipFinish == LipFinish.matte;

    // Matte = more pigment, less shine
    // Glossy = slightly lighter pigment + highlight
    final pigment = isMatte ? 0.62 : 0.48;
    final feather = isMatte ? 0.18 : 0.14;

    final baseShader = ui.Gradient.radial(
      center,
      max(lipW, lipH) * 0.95,
      [
        lipstickColor.withOpacity(pigment * k),
        lipstickColor.withOpacity((pigment * 0.55) * k),
        lipstickColor.withOpacity(0.0),
      ],
      const [0.0, 0.70, 1.0],
    );

    final featherShader = ui.Gradient.radial(
      center,
      max(lipW, lipH) * 1.25,
      [
        lipstickColor.withOpacity(feather * k),
        lipstickColor.withOpacity((feather * 0.35) * k),
        lipstickColor.withOpacity(0.0),
      ],
      const [0.0, 0.78, 1.0],
    );

    // Layer so blending looks like it sits on lips (not sticker)
    // Keep the offscreen layer tight. Large saveLayer bounds are expensive on GPU.
    final layerBounds = bounds.inflate(max(10.0, max(lipW, lipH) * 0.35));
    canvas.saveLayer(layerBounds, Paint());

    // PASS 1: pigment (visible)
    canvas.drawPath(
      lipPath,
      Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.fill
        ..shader = baseShader
        ..blendMode = BlendMode.srcOver
        ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, sigmaSoft),
    );

    // PASS 2: depth (keeps it from looking flat)
    canvas.drawPath(
      lipPath,
      Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.fill
        ..shader = ui.Gradient.radial(
          center,
          max(lipW, lipH) * 0.75,
          [
            lipstickColor.withOpacity(0.10 * k),
            lipstickColor.withOpacity(0.0),
          ],
          const [0.0, 1.0],
        )
        ..blendMode = BlendMode.multiply
        ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, sigmaSoft * 0.9),
    );

    // PASS 3: feather edge (kills hard boundary)
    canvas.drawPath(
      lipPath,
      Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.fill
        ..shader = featherShader
        ..blendMode = BlendMode.softLight
        ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, sigmaFeather),
    );

    // PASS 4: gloss highlight (only if glossy)
    if (!isMatte) {
      // highlight band slightly above center
      final highlightCenter = ui.Offset(center.dx, center.dy - lipH * 0.18);
      final highlightShader = ui.Gradient.radial(
        highlightCenter,
        max(lipW, lipH) * 0.55,
        [
          Colors.white.withOpacity(0.12 * k),
          Colors.white.withOpacity(0.0),
        ],
        const [0.0, 1.0],
      );

      canvas.drawPath(
        lipPath,
        Paint()
          ..isAntiAlias = true
          ..style = PaintingStyle.fill
          ..shader = highlightShader
          ..blendMode = BlendMode.screen
          ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, sigmaSoft * 0.85),
      );
    }

    // PASS 5: slight edge stroke (very subtle)
    canvas.drawPath(
      lipPath,
      Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(0.8, lipW * 0.03)
        ..color = lipstickColor.withOpacity(0.06 * k)
        ..blendMode = BlendMode.softLight
        ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, sigmaFeather * 0.95),
    );

    canvas.restore();
  }

  Path _buildLipRegionPath(List<ui.Offset> upper, List<ui.Offset> lower) {
    // Smooth upper & lower with Catmull-Rom from your utils
    final upperPath = DrawingUtils.catmullRomToBezierPath(upper, tension: 0.72);
    final lowerRev = lower.reversed.toList();
    final lowerPath = DrawingUtils.catmullRomToBezierPath(lowerRev, tension: 0.72);

    // Combine into closed region
    final p = Path();
    // Start at first upper point
    p.addPath(upperPath, ui.Offset.zero);
    // Connect to lower
    p.lineTo(lowerRev.first.dx, lowerRev.first.dy);
    p.addPath(lowerPath, ui.Offset.zero);
    p.close();
    return p;
  }
}
