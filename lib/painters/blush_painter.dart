// lib/painters/blush_painter.dart
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../look_engine.dart';

class BlushPainter {
  final Face face;
  final Color blushColor;
  final double intensity;
  final FaceShape faceShape;

  final String lookStyle;
  final bool debugMode; // keeps console logs (optional)
  final bool isLiveMode;

  final Color? skinColor;
  final double sceneLuminance;
  final double? leftCheekLuminance;
  final double? rightCheekLuminance;

  final int faceId;

  // ✅ UPDATED: Increase "stay away from nose" limits
  static const double anchorUpFactor = 0.02;
  static const double anchorOutFactor = 0.055; // push anchor more toward cheekbone
  static const double anchorInLimitFactor = 0.16; // keep blush away from nose bridge

  BlushPainter({
    required this.face,
    required this.blushColor,
    required this.intensity,
    required this.faceShape,
    required this.lookStyle,
    required this.debugMode,
    required this.isLiveMode,
    this.skinColor,
    this.sceneLuminance = 0.5,
    this.leftCheekLuminance,
    this.rightCheekLuminance,
    required this.faceId,
  });

  void paint(Canvas canvas, Size size) {
    if (intensity <= 0) return;

    final box = face.boundingBox;
    final fw = box.width;
    final fh = box.height;

    // Calculate visibility boost based on blush color vs skin color
    final visBoost = _visibilityBoost(blushColor, skinColor);

    // Adjust intensity based on look style
    final lookStrength = _getLookStrength();
    final autoBoost = _autoBoostFromFaceSize(fw * fh);
    final darkKBoost = _darkLuminanceBoost(sceneLuminance);
    final brightKCut = _brightLuminanceCut(sceneLuminance);

    // Final adjusted intensity with visibility boost
    final k0 = intensity.clamp(0.0, 1.0);
    final k = (k0 * lookStrength * autoBoost * darkKBoost * brightKCut * visBoost)
        .clamp(0.0, 1.0);

    // Get cheek centers using contour-based placement
    final leftCenter = _getCheekCenter(true, box, fw, fh);
    final rightCenter = _getCheekCenter(false, box, fw, fh);

    _drawCheek(
      canvas,
      leftCenter,
      fw,
      leftCheekLuminance ?? sceneLuminance,
      k,
      true,
    );

    _drawCheek(
      canvas,
      rightCenter,
      fw,
      rightCheekLuminance ?? sceneLuminance,
      k,
      false,
    );

    // ❌ VISUAL DEBUG OVERLAY REMOVED:
    // Green circles + L/R % labels were here.
  }

  // ✅ NEW: Get cheek center using contour-based placement
  ui.Offset _getCheekCenter(bool left, ui.Rect faceBox, double faceW, double faceH) {
    final noseCenterX = faceBox.left + faceW * 0.5;

    // Calculate cheek anchor (starting point)
    final cheekAnchor = ui.Offset(
      left ? faceBox.left + faceW * anchorInLimitFactor : faceBox.right - faceW * anchorInLimitFactor,
      faceBox.top + faceH * 0.55 + faceH * anchorUpFactor,
    );

    // Try to get cheek contour points from ML Kit
    final cheekContour = left
        ? face.contours[FaceContourType.leftCheek]?.points
        : face.contours[FaceContourType.rightCheek]?.points;

    ui.Offset center;

    if (cheekContour != null && cheekContour.length >= 3) {
      // Use actual cheek contour points
      final offsets = cheekContour.map((p) => ui.Offset(p.x.toDouble(), p.y.toDouble())).toList();
      final cheekCenter = _centroid(offsets);

      // Blend: anchor gives stability, contour centroid gives correct placement
      center = _lerpOffset(cheekAnchor, cheekCenter, 0.70);
    } else {
      // Fallback: use face oval band approximation
      final cheekBand = _getFaceOvalBand(left, faceBox, faceW, faceH);
      final cheekCenter = _centroid(cheekBand);

      // Blend anchor with band centroid
      center = _lerpOffset(cheekAnchor, cheekCenter, 0.70);
    }

    // Push outward a bit more (towards ear) to avoid nose-side blush
    center = ui.Offset(
      center.dx + (left ? -1 : 1) * (faceW * anchorOutFactor),
      center.dy - (faceH * 0.008),
    );

    // Hard clamp: never allow blush center close to nose
    final minFromNose = faceW * 0.22;
    if (left) {
      if (center.dx > noseCenterX - minFromNose) {
        center = ui.Offset(noseCenterX - minFromNose, center.dy);
      }
    } else {
      if (center.dx < noseCenterX + minFromNose) {
        center = ui.Offset(noseCenterX + minFromNose, center.dy);
      }
    }

    return center;
  }

  // ✅ NEW: Get face oval band points (approximation)
  List<ui.Offset> _getFaceOvalBand(bool left, ui.Rect faceBox, double faceW, double faceH) {
    final band = <ui.Offset>[];
    final yStart = faceBox.top + faceH * 0.45;
    final yEnd = faceBox.top + faceH * 0.65;
    const steps = 5;

    for (int i = 0; i <= steps; i++) {
      final t = i / steps.toDouble();
      final y = yStart + (yEnd - yStart) * t;
      final x = left
          ? faceBox.left + faceW * 0.15 + faceW * 0.15 * sin(t * pi)
          : faceBox.right - faceW * 0.15 - faceW * 0.15 * sin(t * pi);
      band.add(ui.Offset(x, y));
    }

    return band;
  }

  void _drawCheek(Canvas canvas, Offset center, double faceW, double lum, double k, bool left) {
    final t = (1 - lum).clamp(0.0, 1.0);

    // Adjust softness based on look style
    final baseSoftness = ui.lerpDouble(1.2, 1.6, t)!;
    final styleSoftness = _getSoftnessFromLookStyle();
    final softness = baseSoftness * styleSoftness;

    // Adjust radius based on face shape
    final baseRadius = faceW * 0.16;
    final shapeRadius = _getRadiusFromFaceShape();
    final radius = baseRadius * softness * shapeRadius;

    // Base opacity with intensity adjustment
    final baseOpacity = k * ui.lerpDouble(0.35, 0.55, t)!;

    // Adjust opacity based on look style
    final styleOpacity = _getOpacityFromLookStyle();
    final finalOpacity = baseOpacity * styleOpacity;

    final shader = ui.Gradient.radial(
      center,
      radius,
      [
        blushColor.withOpacity(finalOpacity),
        blushColor.withOpacity(finalOpacity * 0.25),
        blushColor.withOpacity(0.0),
      ],
      const [0.0, 0.55, 1.0],
    );

    final paint = Paint()
      ..shader = shader
      ..blendMode = _getBlendModeFromLookStyle()
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, _getBlurRadiusFromLookStyle());

    canvas.drawCircle(center, radius, paint);
  }

  // ✅ Helper methods
  ui.Offset _centroid(List<ui.Offset> pts) {
    if (pts.isEmpty) return ui.Offset.zero;
    double sx = 0, sy = 0;
    for (final p in pts) {
      sx += p.dx;
      sy += p.dy;
    }
    return ui.Offset(sx / pts.length, sy / pts.length);
  }

  ui.Offset _lerpOffset(ui.Offset a, ui.Offset b, double t) {
    return ui.Offset(
      ui.lerpDouble(a.dx, b.dx, t)!,
      ui.lerpDouble(a.dy, b.dy, t)!,
    );
  }

  double _visibilityBoost(Color blush, Color? skin) {
    if (skin == null) return 1.0;

    final blushLum = _luminance01(blush);
    final skinLum = _luminance01(skin);
    final deltaLum = (blushLum - skinLum).abs();
    final sat = _saturation01(blush);

    final lumBoost = ui.lerpDouble(
      1.0,
      1.35,
      ((0.14 - deltaLum) / 0.14).clamp(0.0, 1.0),
    )!;

    final satBoost = ui.lerpDouble(
      1.0,
      1.20,
      ((0.28 - sat) / 0.28).clamp(0.0, 1.0),
    )!;

    return (lumBoost * satBoost).clamp(1.0, 1.55);
  }

  double _luminance01(Color color) {
    return (0.2126 * color.red + 0.7152 * color.green + 0.0722 * color.blue) / 255.0;
  }

  double _saturation01(Color color) {
    final maxVal = max(max(color.red, color.green), color.blue) / 255.0;
    final minVal = min(min(color.red, color.green), color.blue) / 255.0;
    if (maxVal == 0) return 0.0;
    return (maxVal - minVal) / maxVal;
  }

  double _getLookStrength() {
    switch (lookStyle) {
      case 'natural':
        return 0.8;
      case 'soft':
        return 0.9;
      case 'emo':
        return 0.4;
      case 'bold':
        return 1.3;
      default:
        return 1.0;
    }
  }

  double _getSoftnessFromLookStyle() {
    switch (lookStyle) {
      case 'natural':
        return 1.0;
      case 'soft':
        return 1.2;
      case 'emo':
        return 0.8;
      case 'bold':
        return 0.9;
      default:
        return 1.0;
    }
  }

  double _getOpacityFromLookStyle() {
    switch (lookStyle) {
      case 'natural':
        return 1.0;
      case 'soft':
        return 0.9;
      case 'emo':
        return 0.6;
      case 'bold':
        return 1.2;
      default:
        return 1.0;
    }
  }

  BlendMode _getBlendModeFromLookStyle() {
    switch (lookStyle) {
      case 'natural':
        return BlendMode.softLight;
      case 'soft':
        return BlendMode.multiply;
      case 'emo':
        return BlendMode.darken;
      case 'bold':
        return BlendMode.hardLight;
      default:
        return BlendMode.softLight;
    }
  }

  double _getBlurRadiusFromLookStyle() {
    switch (lookStyle) {
      case 'natural':
        return 22;
      case 'soft':
        return 28;
      case 'emo':
        return 16;
      case 'bold':
        return 20;
      default:
        return 22;
    }
  }

  double _getRadiusFromFaceShape() {
    switch (faceShape) {
      case FaceShape.oval:
        return 0.9;
      case FaceShape.round:
        return 1.1;
      case FaceShape.square:
        return 1.0;
      case FaceShape.heart:
        return 0.85;
      case FaceShape.unknown:
        return 1.0;
    }
  }

  double _autoBoostFromFaceSize(double faceArea) {
    const minArea = 5000.0;
    const maxArea = 30000.0;
    final t = ((faceArea - minArea) / (maxArea - minArea)).clamp(0.0, 1.0);
    return ui.lerpDouble(1.3, 0.9, t)!;
  }

  double _darkLuminanceBoost(double sceneLum) {
    if (sceneLum < 0.3) {
      return ui.lerpDouble(1.4, 1.0, sceneLum / 0.3)!;
    }
    return 1.0;
  }

  double _brightLuminanceCut(double sceneLum) {
    if (sceneLum > 0.7) {
      return ui.lerpDouble(1.0, 0.7, (sceneLum - 0.7) / 0.3)!;
    }
    return 1.0;
  }
}
