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
  final ui.Image image;
  final Face face;

  final Color lipstickColor;
  final Color blushColor;
  final Color eyeshadowColor;

  final double intensity;
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

  // ✅ NEW: selective layer toggles for step-by-step rendering
  final bool showBrows;
  final bool showEyeshadow;
  final bool showEyeliner;
  final bool showBlush;
  final bool showContour;
  final bool showLips;

  MakeupOverlayPainter({
    required this.image,
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
    this.showBrows = true,
    this.showEyeshadow = true,
    this.showEyeliner = true,
    this.showBlush = true,
    this.showContour = true,
    this.showLips = true,
  }) {
    debugPrint('🎨 MakeupOverlayPainter created');
    debugPrint('🎨 Eyeshadow color: $eyeshadowColor');
    debugPrint('🎨 Intensity: $intensity');
    debugPrint('🎨 Face tracking ID: ${face.trackingId}');
    debugPrint('🎨 FaceShape: $faceShape');
    debugPrint('🎨 EyelinerStyle: $eyelinerStyle');
    debugPrint('🎨 LipFinish: $lipFinish');
    debugPrint('🎨 Lipstick color: $lipstickColor');
    debugPrint('🎨 Blush color: $blushColor');
    debugPrint('🎨 Scene luminance: $sceneLuminance');
    debugPrint('🎨 Preset: $preset');
    debugPrint('🎨 Debug mode: $debugMode');
    debugPrint('🎨 Is live mode: $isLiveMode');
    debugPrint(
      '🎨 Layers => brows:$showBrows eyeshadow:$showEyeshadow eyeliner:$showEyeliner blush:$showBlush contour:$showContour lips:$showLips',
    );
    if (leftCheekLuminance != null && rightCheekLuminance != null) {
      debugPrint(
        '🎨 Cheek luminance: L=$leftCheekLuminance, R=$rightCheekLuminance',
      );
    }
    debugPrint('✅ MakeupOverlayPainter initialized');
  }

  @override
  void paint(Canvas canvas, Size size) {
    debugPrint('🎨 MakeupOverlayPainter.paint() called, size: $size');

    // Base image always draws first
    canvas.drawImage(image, Offset.zero, Paint());

    if (debugMode) {
      canvas.drawRect(
        Rect.fromLTWH(20, 20, 60, 60),
        Paint()
          ..color = Colors.green.withOpacity(0.8)
          ..style = PaintingStyle.fill,
      );
      debugPrint('🟢 GREEN SQUARE drawn at (20,20) size 60x60');
    }

    if (intensity <= 0) {
      debugPrint('⚠️ Skipping makeup - intensity is 0');
      return;
    }

    final effectiveIntensity = intensity.clamp(0.0, 1.0);
    debugPrint('🎨 Effective intensity: $effectiveIntensity');

    // Build eyeliner paths first because eyeshadow can use them
    debugPrint('🎨 Creating eyeliner painter...');
    final eyelinerPainter = EyelinerPainter(
      face: face,
      intensity: effectiveIntensity,
      style: eyelinerStyle,
    );

    debugPrint('🎨 Building eyeliner paths...');
    final paths = eyelinerPainter.buildPaths();
    debugPrint(
      '🎨 Eyeliner paths built: left=${paths.left != null}, right=${paths.right != null}',
    );

    debugPrint('🎨 Creating eyeshadow painter with eyeliner paths...');
    final eyeshadowPainter = EyeshadowPainter(
      face: face,
      eyeshadowColor: eyeshadowColor,
      intensity: effectiveIntensity,
      leftEyelinerPath: paths.left,
      rightEyelinerPath: paths.right,
      debugMode: debugMode,
    );

    final browColor = LookEngine.browColorFromPreset(
      preset,
      profile: profile,
    );

    debugPrint('🎨 Creating eyebrow painter...');
    final eyebrowPainter = EyebrowPainter(
      face: face,
      browColor: browColor,
      intensity: effectiveIntensity,
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
    );

    debugPrint('🎨 Creating blush painter...');
    final blushPainter = BlushPainter(
      face: face,
      blushColor: blushColor,
      intensity: effectiveIntensity,
      faceShape: faceShape,
      skinColor: skinColor,
      sceneLuminance: sceneLuminance,
      faceId: face.trackingId ?? -1,
      isLiveMode: isLiveMode,
      lookStyle: LookEngine.blushStyleFromPreset(preset),
      debugMode: debugMode,
    );

    debugPrint('🎨 Creating contour/highlight painter...');
    final contourPainter = ContourHighlightPainter(
      face: face,
      intensity: effectiveIntensity,
      faceShape: faceShape,
    );

    debugPrint('🎨 Creating lip painter...');
    final lipPainter = LipPainter(
      face: face,
      lipstickColor: lipstickColor,
      intensity: effectiveIntensity,
      lipFinish: lipFinish,
    );

    debugPrint('🎨 Drawing selected makeup layers...');

    // Brows
    if (showBrows) {
      debugPrint('🎨 1. Drawing eyebrows...');
      eyebrowPainter.paint(canvas, size);
    }

    // Eyeshadow
    if (showEyeshadow) {
      debugPrint('🎨 2. Drawing eyeshadow...');
      eyeshadowPainter.paint(canvas, size);
    }

    // Eyeliner
    if (showEyeliner) {
      debugPrint('🎨 3. Drawing eyeliner...');
      eyelinerPainter.paint(canvas, size);
    }

    // Blush
    if (showBlush) {
      debugPrint('🎨 4. Drawing blush...');
      blushPainter.paint(canvas, size);
    }

    // Contour
    if (showContour) {
      debugPrint('🎨 5. Drawing contour/highlight...');
      contourPainter.paint(canvas, size);
    }

    // Lips
    if (showLips) {
      debugPrint('🎨 6. Drawing lips...');
      lipPainter.paint(canvas, size);
    }

    debugPrint('✅ Selected makeup layers drawn');
  }

  @override
  bool shouldRepaint(covariant MakeupOverlayPainter old) {
    final intensityChanged = (old.intensity - intensity).abs() > 0.05;

    return old.image != image ||
        old.face != face ||
        intensityChanged ||
        old.faceShape != faceShape ||
        old.eyelinerStyle != eyelinerStyle ||
        old.preset != preset ||
        old.debugMode != debugMode ||
        old.isLiveMode != isLiveMode ||
        old.leftCheekLuminance != leftCheekLuminance ||
        old.rightCheekLuminance != rightCheekLuminance ||
        old.sceneLuminance != sceneLuminance ||
        old.profile != profile ||
        old.showBrows != showBrows ||
        old.showEyeshadow != showEyeshadow ||
        old.showEyeliner != showEyeliner ||
        old.showBlush != showBlush ||
        old.showContour != showContour ||
        old.showLips != showLips;
  }
}