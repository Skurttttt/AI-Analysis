import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import 'look_engine.dart';
import 'painters/makeup_overlay_painter.dart';
import 'tutorial_step_preview.dart';
import 'utils.dart';

class StepPreviewRenderer {
  static Future<String> renderStepPreviewToFile({
    required ui.Image image,
    required Face face,
    required LookResult look,
    required FaceProfile? faceProfile,
    required MakeupLookPreset preset,
    required StepLayerConfig layerConfig,
    double intensity = 0.75,
    double sceneLuminance = 0.5,
    double leftCheekLuminance = 0.5,
    double rightCheekLuminance = 0.5,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final size = Size(
      image.width.toDouble(),
      image.height.toDouble(),
    );

    final lookConfig = LookEngine.configFromPreset(
      preset,
      profile: faceProfile,
    );

    final painter = MakeupOverlayPainter(
      image: image,
      face: face,
      lipstickColor: look.lipstickColor,
      blushColor: look.blushColor,
      eyeshadowColor: look.eyeshadowColor,
      intensity: intensity,
      faceShape: faceProfile?.faceShape ?? FaceShape.oval,
      preset: preset,
      debugMode: false,
      isLiveMode: false,
      eyelinerStyle: lookConfig.eyelinerStyle,
      lipFinish: lookConfig.glossyLips ? LipFinish.glossy : LipFinish.matte,
      skinColor: faceProfile != null
          ? Color.fromARGB(
              255,
              faceProfile.avgR,
              faceProfile.avgG,
              faceProfile.avgB,
            )
          : null,
      sceneLuminance: sceneLuminance,
      leftCheekLuminance: leftCheekLuminance,
      rightCheekLuminance: rightCheekLuminance,
      profile: faceProfile,
      showBrows: layerConfig.showBrows,
      showEyeshadow: layerConfig.showEyeshadow,
      showEyeliner: layerConfig.showEyeliner,
      showBlush: layerConfig.showBlush,
      showContour: layerConfig.showContour,
      showLips: layerConfig.showLips,
    );

    painter.paint(canvas, size);

    final picture = recorder.endRecording();
    final renderedImage = await picture.toImage(
      image.width,
      image.height,
    );

    final byteData = await renderedImage.toByteData(
      format: ui.ImageByteFormat.png,
    );

    if (byteData == null) {
      throw Exception('Failed to encode step preview image.');
    }

    final bytes = byteData.buffer.asUint8List();

    final dir = await Directory.systemTemp.createTemp('tutorial_step_');
    final file = File('${dir.path}/preview.png');
    await file.writeAsBytes(bytes, flush: true);

    return file.path;
  }
}