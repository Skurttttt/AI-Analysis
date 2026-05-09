// lib/painters/makeup_overlay_painter.dart
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../utils.dart';
import '../look_engine.dart';

import 'lip_painter.dart';
import 'eyeshadow_painter.dart';
import 'eyeliner_painter.dart';
import 'blush_painter.dart';
import 'contour_highlight_painter.dart';
import 'eyebrow_painter.dart';

class MakeupOverlayPainter extends CustomPainter {
  /// Optional for backward compatibility.
  /// In ultra performance mode, ScanResultPage draws the image using RawImage
  /// in a separate RepaintBoundary, so this painter only draws makeup layers.
  final ui.Image? image;
  final Face face;

  final Color lipstickColor;
  final Color blushColor;
  final Color eyeshadowColor;

  /// Global opacity/intensity for the whole makeup look.
  final double intensity;

  /// Individual layer opacity controls.
  final double lipstickOpacity;
  final double blushOpacity;
  final double contourOpacity;
  final double eyeshadowOpacity;
  final double eyelinerOpacity;
  final double browOpacity;

  final FaceShape faceShape;
  final EyelinerStyle eyelinerStyle;
  final LipFinish lipFinish;

  final Color? skinColor;
  final double sceneLuminance;

  final MakeupLookPreset preset;
  final bool debugMode;
  final bool isLiveMode;
  final double? leftCheekLuminance;
  final double? rightCheekLuminance;

  final FaceProfile? profile;

  final bool showBrows;
  final bool showEyeshadow;
  final bool showEyeliner;
  final bool showBlush;
  final bool showContour;
  final bool showLips;

  MakeupOverlayPainter({
    this.image,
    required this.face,
    required this.lipstickColor,
    required this.blushColor,
    required this.eyeshadowColor,
    required this.intensity,
    required this.faceShape,
    required this.preset,
    this.eyelinerStyle = EyelinerStyle.subtle,
    this.lipFinish = LipFinish.glossy,
    this.skinColor,
    this.sceneLuminance = 0.5,
    this.debugMode = false,
    this.isLiveMode = false,
    this.leftCheekLuminance,
    this.rightCheekLuminance,
    this.profile,
    this.lipstickOpacity = 1.0,
    this.blushOpacity = 1.0,
    this.contourOpacity = 1.0,
    this.eyeshadowOpacity = 1.0,
    this.eyelinerOpacity = 1.0,
    this.browOpacity = 1.0,
    this.showBrows = true,
    this.showEyeshadow = true,
    this.showEyeliner = true,
    this.showBlush = true,
    this.showContour = true,
    this.showLips = true,
  });

  double _layerIntensity(double layerOpacity) {
    return (intensity.clamp(0.0, 1.0) * layerOpacity.clamp(0.0, 1.0))
        .clamp(0.0, 1.0);
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Backward compatibility only. In ultra mode this is null, because the
    // base photo is drawn by RawImage in ScanResultPage and does not repaint.
    final baseImage = image;
    if (baseImage != null) {
      canvas.drawImage(baseImage, Offset.zero, Paint());
    }

    if (debugMode) {
      canvas.drawRect(
        Rect.fromLTWH(20, 20, 60, 60),
        Paint()
          ..color = Colors.green.withOpacity(0.8)
          ..style = PaintingStyle.fill,
      );
    }

    final globalIntensity = intensity.clamp(0.0, 1.0);
    if (globalIntensity <= 0.001) return;

    final browIntensity = _layerIntensity(browOpacity);
    final eyeshadowIntensity = _layerIntensity(eyeshadowOpacity);
    final eyelinerIntensity = _layerIntensity(eyelinerOpacity);
    final blushIntensity = _layerIntensity(blushOpacity);
    final contourIntensity = _layerIntensity(contourOpacity);
    final lipIntensity = _layerIntensity(lipstickOpacity);

    final shouldPaintBrows = showBrows && browIntensity > 0.001;
    final shouldPaintEyeshadow = showEyeshadow && eyeshadowIntensity > 0.001;
    final shouldPaintEyeliner = showEyeliner && eyelinerIntensity > 0.001;
    final shouldPaintBlush = showBlush && blushIntensity > 0.001;
    final shouldPaintContour = showContour && contourIntensity > 0.001;
    final shouldPaintLips = showLips && lipIntensity > 0.001;

    if (!shouldPaintBrows &&
        !shouldPaintEyeshadow &&
        !shouldPaintEyeliner &&
        !shouldPaintBlush &&
        !shouldPaintContour &&
        !shouldPaintLips) {
      return;
    }

    EyelinerPainter? eyelinerPainter;
    dynamic eyelinerPaths;

    if (shouldPaintEyeshadow || shouldPaintEyeliner) {
      eyelinerPainter = EyelinerPainter(
        face: face,
        intensity: eyelinerIntensity,
        style: eyelinerStyle,
      );
      eyelinerPaths = eyelinerPainter.buildPaths();
    }

    if (shouldPaintBrows) {
      EyebrowPainter(
        face: face,
        browColor: LookEngine.browColorFromPreset(preset),
        intensity: browIntensity,
        thickness: 1.05,
        hairStrokes: true,
        sceneLuminance: sceneLuminance,
        debugMode: debugMode,
        debugShowPoints: false,
        debugBrowColor: const Color(0xFF1A0E0A),
        debugBrowOpacity: 0.55,
        isMirrored: isLiveMode,
        emaAlpha: 0.84,
        holdLastGood: const Duration(milliseconds: 250),
      ).paint(canvas, size);
    }

    if (shouldPaintEyeshadow && eyelinerPaths != null) {
      EyeshadowPainter(
        face: face,
        eyeshadowColor: eyeshadowColor,
        intensity: eyeshadowIntensity,
        leftEyelinerPath: eyelinerPaths.left,
        rightEyelinerPath: eyelinerPaths.right,
        debugMode: debugMode,
      ).paint(canvas, size);
    }

    if (shouldPaintEyeliner && eyelinerPainter != null) {
      eyelinerPainter.paint(canvas, size);
    }

    if (shouldPaintBlush) {
      BlushPainter(
        face: face,
        blushColor: blushColor,
        intensity: blushIntensity,
        faceShape: faceShape,
        skinColor: skinColor,
        sceneLuminance: sceneLuminance,
        leftCheekLuminance: leftCheekLuminance,
        rightCheekLuminance: rightCheekLuminance,
        faceId: face.trackingId ?? -1,
        isLiveMode: isLiveMode,
        lookStyle: LookEngine.blushStyleFromPreset(preset),
        debugMode: debugMode,
      ).paint(canvas, size);
    }

    if (shouldPaintContour) {
      ContourHighlightPainter(
        face: face,
        intensity: contourIntensity,
        faceShape: faceShape,
      ).paint(canvas, size);
    }

    if (shouldPaintLips) {
      LipPainter(
        face: face,
        lipstickColor: lipstickColor,
        intensity: lipIntensity,
        lipFinish: lipFinish,
      ).paint(canvas, size);
    }
  }

  @override
  bool shouldRepaint(covariant MakeupOverlayPainter old) {
    return old.image != image ||
        old.face != face ||
        old.intensity != intensity ||
        old.lipstickOpacity != lipstickOpacity ||
        old.blushOpacity != blushOpacity ||
        old.contourOpacity != contourOpacity ||
        old.eyeshadowOpacity != eyeshadowOpacity ||
        old.eyelinerOpacity != eyelinerOpacity ||
        old.browOpacity != browOpacity ||
        old.faceShape != faceShape ||
        old.eyelinerStyle != eyelinerStyle ||
        old.lipFinish != lipFinish ||
        old.lipstickColor != lipstickColor ||
        old.blushColor != blushColor ||
        old.eyeshadowColor != eyeshadowColor ||
        old.skinColor != skinColor ||
        old.sceneLuminance != sceneLuminance ||
        old.preset != preset ||
        old.debugMode != debugMode ||
        old.isLiveMode != isLiveMode ||
        old.leftCheekLuminance != leftCheekLuminance ||
        old.rightCheekLuminance != rightCheekLuminance ||
        old.profile != profile ||
        old.showBrows != showBrows ||
        old.showEyeshadow != showEyeshadow ||
        old.showEyeliner != showEyeliner ||
        old.showBlush != showBlush ||
        old.showContour != showContour ||
        old.showLips != showLips;
  }
}
