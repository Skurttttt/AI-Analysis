// lib/look_engine.dart
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'skin_analyzer.dart';

enum FaceShape { oval, round, square, heart, unknown }

// 1A) EyelinerStyle enum (kept)
enum EyelinerStyle {
  none,
  thin, // thin eyeliner no wing
  subtle, // subtle liner
  emoWing, // heavier emo wing
}

// ✅ Presets: required 5 looks + debugPainterTest (keep)
enum MakeupLookPreset {
  emo,
  softGlam,
  dollKBeauty,
  bronzedGoddess,
  boldEditorial,

  debugPainterTest, // 🔧 MUST remain
}

// ✅ Clean labels (kept)
extension MakeupLookPresetLabel on MakeupLookPreset {
  String get label {
    switch (this) {
      case MakeupLookPreset.emo:
        return 'Emo';
      case MakeupLookPreset.softGlam:
        return 'Soft Glam';
      case MakeupLookPreset.dollKBeauty:
        return 'Doll / K-Beauty';
      case MakeupLookPreset.bronzedGoddess:
        return 'Bronzed Goddess';
      case MakeupLookPreset.boldEditorial:
        return 'Bold Editorial';
      case MakeupLookPreset.debugPainterTest:
        return '🔧 Debug Painter Test';
    }
  }
}

/// ✅ Your existing analysis model (kept)
class FaceProfile {
  final SkinTone skinTone;
  final Undertone undertone;
  final FaceShape faceShape;

  final int avgR;
  final int avgG;
  final int avgB;

  final double skinConfidence;
  final double undertoneConfidence;

  const FaceProfile({
    required this.skinTone,
    required this.undertone,
    required this.faceShape,
    required this.avgR,
    required this.avgG,
    required this.avgB,
    required this.skinConfidence,
    required this.undertoneConfidence,
  });

  factory FaceProfile.fromAnalysis(Face face, SkinAnalysisResult skin) {
    final shape = _detectFaceShape(face);
    return FaceProfile(
      skinTone: skin.tone,
      undertone: skin.undertone,
      faceShape: shape,
      avgR: skin.avgR,
      avgG: skin.avgG,
      avgB: skin.avgB,
      skinConfidence: skin.confidence,
      undertoneConfidence: _calculateUndertoneConfidence(skin),
    );
  }

  static double _calculateUndertoneConfidence(SkinAnalysisResult a) {
    return (a.confidence).clamp(0.0, 1.0);
  }

  static FaceShape _detectFaceShape(Face face) {
    final box = face.boundingBox;
    final w = box.width;
    final h = box.height;

    if (w <= 0 || h <= 0) return FaceShape.unknown;

    final ratio = w / h;
    if (ratio > 0.95) return FaceShape.round;
    if (ratio < 0.75) return FaceShape.oval;
    return FaceShape.square;
  }
}

/// ✅ Instructions page model (kept)
class LookResult {
  final String lookName;
  final Color lipstickColor;
  final Color blushColor;
  final Color eyeshadowColor;
  final List<String> steps;

  const LookResult({
    required this.lookName,
    required this.lipstickColor,
    required this.blushColor,
    required this.eyeshadowColor,
    required this.steps,
  });
}

// ✅ REPLACED LookEngine class with simplified version
class LookEngine {
  /// ✅ MAIN GENERATOR
  static LookResult generateLook({
    required FaceProfile profile,
    required MakeupLookPreset preset,
  }) {
    switch (preset) {
      case MakeupLookPreset.softGlam:
        return LookResult(
          lookName: 'Soft Glam',
          lipstickColor: const Color(0xFFD86A7F),
          blushColor: const Color(0xFFFF9DAA),
          eyeshadowColor: const Color(0xFFBFA6A0),
          steps: [
            'Apply a light eyeshadow base all over the lid.',
            'Blend a medium shade into the crease.',
            'Add a darker shade to the outer corner for depth.',
            'Apply blush to the apples of the cheeks.',
            'Finish with a soft pink lipstick.',
          ],
        );

      case MakeupLookPreset.emo:
        return LookResult(
          lookName: 'Emo',
          lipstickColor: const Color(0xFF5A0F1C),
          blushColor: const Color(0xFF7A1F2B),
          eyeshadowColor: const Color(0xFF2B1B1B),
          steps: [
            'Apply dark smoky eyeshadow all over the lid.',
            'Blend upward for a gradient effect.',
            'Apply dramatic eyeliner with a wing.',
            'Keep blush minimal and muted.',
            'Finish with dark berry lipstick.',
          ],
        );

      case MakeupLookPreset.dollKBeauty:
        return LookResult(
          lookName: 'Doll / K-Beauty',
          lipstickColor: const Color(0xFFFFB7C5),
          blushColor: const Color(0xFFFFC0CB),
          eyeshadowColor: const Color(0xFFF5E6E8),
          steps: [
            'Apply light, shimmery eyeshadow all over the lid.',
            'Use a soft pink blush on the upper cheeks.',
            'Apply thin, natural eyeliner.',
            'Finish with gradient lip color.',
          ],
        );

      case MakeupLookPreset.bronzedGoddess:
        return LookResult(
          lookName: 'Bronzed Goddess',
          lipstickColor: const Color(0xFFD4A373),
          blushColor: const Color(0xFFE6B89C),
          eyeshadowColor: const Color(0xFFC49A6C),
          steps: [
            'Apply bronze/gold eyeshadow on the lid.',
            'Warm up the crease with a terracotta shade.',
            'Apply bronzer/blush hybrid to cheeks.',
            'Finish with warm nude lipstick.',
          ],
        );

      case MakeupLookPreset.boldEditorial:
        return LookResult(
          lookName: 'Bold Editorial',
          lipstickColor: const Color(0xFFE63946),
          blushColor: const Color(0xFFFF6B6B),
          eyeshadowColor: const Color(0xFF457B9D),
          steps: [
            'Apply bold, graphic eyeshadow design.',
            'Use strong, sculpted blush placement.',
            'Apply dramatic, graphic eyeliner.',
            'Finish with bold, statement lip color.',
          ],
        );

      case MakeupLookPreset.debugPainterTest:
        return const LookResult(
          lookName: '🔧 Debug Painter Test',
          lipstickColor: Color(0xFFFF0000),
          blushColor: Color.fromARGB(102, 255, 112, 195),
          eyeshadowColor: Color(0xFF0000FF),
          steps: [
            'This is a DEBUG mode to test all painters.',
            'All makeup elements should be visible:',
            '- Bright red lips',
            '- Bright magenta blush',
            '- Bright blue eyeshadow',
            '- Dramatic emo-wing eyeliner',
            '- Brows should be LIGHT BROWN for placement checking',
            'Use this to verify all painters are working.',
          ],
        );
    }
  }

  /// ✅ EYELINER STYLE (used by overlay)
  static EyelinerStyle eyelinerStyleFromPreset(
    MakeupLookPreset preset,
  ) {
    switch (preset) {
      case MakeupLookPreset.softGlam:
        return EyelinerStyle.subtle;

      case MakeupLookPreset.emo:
        return EyelinerStyle.emoWing;
        
      case MakeupLookPreset.dollKBeauty:
        return EyelinerStyle.thin;
        
      case MakeupLookPreset.bronzedGoddess:
        return EyelinerStyle.subtle;
        
      case MakeupLookPreset.boldEditorial:
        return EyelinerStyle.emoWing;
        
      case MakeupLookPreset.debugPainterTest:
        return EyelinerStyle.emoWing;
    }
  }

  /// ✅ BROW COLOR (used by brow painter)
  static Color browColorFromPreset(MakeupLookPreset preset) {
    switch (preset) {
      case MakeupLookPreset.softGlam:
        return const Color(0xFF6D4C41);
      case MakeupLookPreset.emo:
        return const Color(0xFF1A1A1A);
      case MakeupLookPreset.dollKBeauty:
        return const Color(0xFF5D4037);
      case MakeupLookPreset.bronzedGoddess:
        return const Color(0xFF4E342E);
      case MakeupLookPreset.boldEditorial:
        return const Color(0xFF3E2723);
      case MakeupLookPreset.debugPainterTest:
        return const Color(0xFFB07A4A); // Light brown for debug
    }
  }

  /// ✅ BLUSH STYLE (used by blush painter)
  // ✅ FIXED: Changed from dynamic to String return type
  static String blushStyleFromPreset(MakeupLookPreset preset) {
    switch (preset) {
      case MakeupLookPreset.softGlam:
        return 'soft';
      case MakeupLookPreset.emo:
        return 'sharp';
      case MakeupLookPreset.dollKBeauty:
        return 'soft';
      case MakeupLookPreset.bronzedGoddess:
        return 'warm';
      case MakeupLookPreset.boldEditorial:
        return 'sharp';
      case MakeupLookPreset.debugPainterTest:
        return 'bold';
    }
  }
}