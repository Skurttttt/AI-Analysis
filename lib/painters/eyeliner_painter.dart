// lib/painters/eyeliner_painter.dart
import 'dart:ui' as ui;
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../utils.dart';
import '../look_engine.dart';

class EyelinerPaths {
  final Path? left;
  final Path? right;
  final Path? combined;
  const EyelinerPaths({this.left, this.right, this.combined});
}

class EyelinerPainter {
  final Face face;
  final double intensity;
  final EyelinerStyle style;

  /// ✅ Kept for compatibility
  Path? lastEyelinerPath;

  /// ✅ NEW: per-eye paths
  Path? lastLeftEyelinerPath;
  Path? lastRightEyelinerPath;

  EyelinerPainter({
    required this.face,
    required this.intensity,
    required this.style,
  });

  List<ui.Offset>? _contourPoints(FaceContourType type) {
    final pts = face.contours[type]?.points;
    if (pts == null || pts.length < 3) return null;
    return pts.map((p) => ui.Offset(p.x.toDouble(), p.y.toDouble())).toList();
  }

  Rect _boundsOf(List<ui.Offset> pts) {
    double minX = pts.first.dx, maxX = pts.first.dx;
    double minY = pts.first.dy, maxY = pts.first.dy;
    for (final p in pts.skip(1)) {
      minX = min(minX, p.dx);
      maxX = max(maxX, p.dx);
      minY = min(minY, p.dy);
      maxY = max(maxY, p.dy);
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  List<ui.Offset> _upperLidPoints(List<ui.Offset> eyePts) {
    double minY = eyePts.first.dy, maxY = eyePts.first.dy;
    double minX = eyePts.first.dx, maxX = eyePts.first.dx;

    for (final p in eyePts.skip(1)) {
      minY = min(minY, p.dy);
      maxY = max(maxY, p.dy);
      minX = min(minX, p.dx);
      maxX = max(maxX, p.dx);
    }

    final centerY = (minY + maxY) / 2.0;
    final upper = eyePts.where((p) => p.dy <= centerY).toList();
    if (upper.length < 3) return [];

    upper.sort((a, b) => a.dx.compareTo(b.dx));

    final filtered = <ui.Offset>[];
    for (int i = 0; i < upper.length; i++) {
      if (i == 0 || i == upper.length - 1 || i % 2 == 0) filtered.add(upper[i]);
    }
    return filtered;
  }

  double _eyeOpennessRatio(List<ui.Offset> eyePts) {
    double minY = eyePts.first.dy, maxY = eyePts.first.dy;
    double minX = eyePts.first.dx, maxX = eyePts.first.dx;
    for (final p in eyePts.skip(1)) {
      minY = min(minY, p.dy);
      maxY = max(maxY, p.dy);
      minX = min(minX, p.dx);
      maxX = max(maxX, p.dx);
    }
    final w = max(1.0, maxX - minX);
    final h = max(1.0, maxY - minY);
    return h / w;
  }

  ui.Offset _normalize(ui.Offset v) {
    final len = sqrt(v.dx * v.dx + v.dy * v.dy);
    if (len < 1e-6) return const ui.Offset(1, 0);
    return ui.Offset(v.dx / len, v.dy / len);
  }

  List<ui.Offset> _extendUpperLid({
    required List<ui.Offset> upperOrdered,
    required bool eyeOnLeftSideOfImage,
    required Rect eyeBounds,
    required double openness,
  }) {
    if (upperOrdered.length < 4) return upperOrdered;

    final outerIdx = eyeOnLeftSideOfImage ? 0 : (upperOrdered.length - 1);
    final inwardIdx = eyeOnLeftSideOfImage ? 1 : (upperOrdered.length - 2);

    final outer = upperOrdered[outerIdx];
    final inward = upperOrdered[inwardIdx];

    var tangent = ui.Offset(outer.dx - inward.dx, outer.dy - inward.dy);
    tangent = _normalize(tangent);

    final baseExt = (eyeBounds.width * 0.125).clamp(3.2, 14.8);
    final openBoost = ui.lerpDouble(
      0.95,
      1.18,
      ((openness - 0.14) / 0.12).clamp(0.0, 1.0),
    )!;
    final extLen = (baseExt * openBoost).clamp(3.0, 15.0);

    final upBias = ui.Offset(0, -(eyeBounds.height * 0.035).clamp(0.4, 2.2));

    final ext1 = outer + tangent * (extLen * 0.55) + upBias;
    final ext2 = outer + tangent * (extLen * 1.00) + upBias;

    final out = List<ui.Offset>.from(upperOrdered);

    if (eyeOnLeftSideOfImage) {
      out.insert(0, ext2);
      out.insert(0, ext1);
    } else {
      out.add(ext1);
      out.add(ext2);
    }

    return out;
  }

  void _drawVariableStroke({
    required Canvas canvas,
    required Path path,
    required double baseWidth,
    required double baseAlpha,
    required double innerTaperFrac,
    required bool taperFromStart,
    required Paint Function(double width, double alpha) paintFactory,
    int segments = 42,
  }) {
    final metrics = path.computeMetrics().toList();
    if (metrics.isEmpty) return;

    final totalLen = metrics.fold<double>(0, (s, m) => s + m.length);
    if (totalLen <= 1e-6) return;

    double globalStart = 0.0;

    for (final metric in metrics) {
      final mLen = metric.length;
      if (mLen <= 1e-6) continue;

      for (int i = 0; i < segments; i++) {
        final t0 = i / segments;
        final t1 = (i + 1) / segments;

        final s0 = metric.length * t0;
        final s1 = metric.length * t1;

        final g0 = (globalStart + s0) / totalLen;
        final g1 = (globalStart + s1) / totalLen;
        final gMid = (g0 + g1) * 0.5;

        final innerT = taperFromStart ? gMid : (1.0 - gMid);

        double taper = 1.0;
        if (innerTaperFrac > 0) {
          final x = (innerT / innerTaperFrac).clamp(0.0, 1.0);
          taper = x * x * (3 - 2 * x);
        }

        final w = max(0.35, baseWidth * (0.25 + 0.75 * taper));
        final a = (baseAlpha * taper).clamp(0.0, 1.0);
        if (a <= 0.001) continue;

        final seg = metric.extractPath(s0, s1);
        canvas.drawPath(seg, paintFactory(w, a));
      }

      globalStart += mLen;
    }
  }

  /// ✅ NEW: build paths WITHOUT drawing (so eyeshadow can be drawn first)
  EyelinerPaths buildPaths() {
    lastEyelinerPath = null;
    lastLeftEyelinerPath = null;
    lastRightEyelinerPath = null;

    final k = intensity.clamp(0.0, 1.0);
    if (k <= 0.0) return const EyelinerPaths();

    if (style == EyelinerStyle.none) {
      return const EyelinerPaths();
    }

    final combined = Path();
    Path? leftPath;
    Path? rightPath;

    Path? buildForEye(FaceContourType eyeType) {
      final eyePtsRaw = _contourPoints(eyeType);
      if (eyePtsRaw == null || eyePtsRaw.length < 6) return null;

      final faceBox = face.boundingBox;
      final faceCenterX = faceBox.left + faceBox.width * 0.5;

      final eyeBounds = _boundsOf(eyePtsRaw);
      final eyeCenterX = eyeBounds.center.dx;

      final eyeOnLeftSideOfImage = eyeCenterX < faceCenterX;

      final upper = _upperLidPoints(eyePtsRaw);
      if (upper.length < 4) return null;

      final openness = _eyeOpennessRatio(eyePtsRaw);

      final lift = max(0.6, (faceBox.height * 0.0025));
      final settleDown = (eyeBounds.height * 0.013).clamp(0.4, 1.4);
      final upperLifted = upper.map((p) => ui.Offset(p.dx, p.dy - lift + settleDown)).toList();

      final ordered = List<ui.Offset>.from(upperLifted)..sort((a, b) => a.dx.compareTo(b.dx));

      final extended = _extendUpperLid(
        upperOrdered: ordered,
        eyeOnLeftSideOfImage: eyeOnLeftSideOfImage,
        eyeBounds: eyeBounds,
        openness: openness,
      );

      final linerPath = DrawingUtils.catmullRomToBezierPath(extended, tension: 0.72);

      final eyeCombined = Path()..addPath(linerPath, Offset.zero);

      // Wing logic (same as your current logic, path-only)
      final allowByOpenness = openness > 0.16;
      final yaw = face.headEulerAngleY ?? 0.0;
      final roll = face.headEulerAngleZ ?? 0.0;
      final allowByPose = yaw.abs() < 18 && roll.abs() < 22;

      final styleAllowsWing = style == EyelinerStyle.subtle || style == EyelinerStyle.emoWing;
      if (!(allowByOpenness && allowByPose && styleAllowsWing)) return eyeCombined;

      final endIdx = eyeOnLeftSideOfImage ? 0 : (extended.length - 1);
      final prevIdx = eyeOnLeftSideOfImage ? min(2, extended.length - 1) : max(extended.length - 3, 0);

      final end = extended[endIdx];
      final prev = extended[prevIdx];

      final lidDir = ui.Offset(end.dx - prev.dx, end.dy - prev.dy);
      final outwardSign = eyeOnLeftSideOfImage ? -1.0 : 1.0;
      if (lidDir.dx.sign != outwardSign.sign) return eyeCombined;

      final wingLen = (eyeBounds.width * 0.14).clamp(3.0, 14.0).toDouble();
      final wingUp = (eyeBounds.height * 0.10).clamp(1.5, 10.0).toDouble();

      final wingEnd = ui.Offset(end.dx + outwardSign * wingLen, end.dy - wingUp);

      final wingPath = Path()
        ..moveTo(end.dx, end.dy)
        ..quadraticBezierTo(
          end.dx + outwardSign * (wingLen * 0.55),
          end.dy - (wingUp * 0.65),
          wingEnd.dx,
          wingEnd.dy,
        );

      eyeCombined.addPath(wingPath, Offset.zero);

      if (style == EyelinerStyle.emoWing) {
        final emoWingLen = wingLen * 1.5;
        final emoWingUp = wingUp * 1.3;

        final emoWingEnd = ui.Offset(end.dx + outwardSign * emoWingLen, end.dy - emoWingUp);

        final emoWingPath = Path()
          ..moveTo(end.dx, end.dy)
          ..quadraticBezierTo(
            end.dx + outwardSign * (emoWingLen * 0.6),
            end.dy - (emoWingUp * 0.7),
            emoWingEnd.dx,
            emoWingEnd.dy,
          );

        eyeCombined.addPath(emoWingPath, Offset.zero);
      }

      return eyeCombined;
    }

    leftPath = buildForEye(FaceContourType.leftEye);
    rightPath = buildForEye(FaceContourType.rightEye);

    if (leftPath != null) combined.addPath(leftPath, Offset.zero);
    if (rightPath != null) combined.addPath(rightPath, Offset.zero);

    lastLeftEyelinerPath = leftPath;
    lastRightEyelinerPath = rightPath;
    lastEyelinerPath = combined;

    return EyelinerPaths(left: leftPath, right: rightPath, combined: combined);
  }

  /// ✅ KEEP your eyeliner rendering EXACTLY the same
  void paint(Canvas canvas, Size size) {
    final k = intensity.clamp(0.0, 1.0);
    
    // ✅ Early exit to avoid unnecessary work
    if (k <= 0.01) return;
    
    if (style == EyelinerStyle.none) return;

    // Ensure paths exist even if caller didn't call buildPaths()
    if (lastEyelinerPath == null || lastLeftEyelinerPath == null || lastRightEyelinerPath == null) {
      buildPaths();
    }

    // your existing style config stays the same
    // ignore: unused_local_variable
    double baseWidth = 1.6;
    // ignore: unused_local_variable
    double alpha = 0.7;

    switch (style) {
      case EyelinerStyle.none:
        return;
      case EyelinerStyle.thin:
        baseWidth = 1.2;
        alpha = 0.6;
        break;
      case EyelinerStyle.subtle:
        baseWidth = 1.8;
        alpha = 0.75;
        break;
      case EyelinerStyle.emoWing:
        baseWidth = 2.8;
        alpha = 0.95;
        break;
    }

    void drawEyePath(Path? eyePath, FaceContourType eyeType) {
      if (eyePath == null) return;
      final eyePtsRaw = _contourPoints(eyeType);
      if (eyePtsRaw == null || eyePtsRaw.length < 6) return;

      final eyeBounds = _boundsOf(eyePtsRaw);
      final baseW = (eyeBounds.height * 0.085).clamp(1.2, 4.2).toDouble();

      // 1) lash-bed shadow
      final lashBedShadow = Paint()
        ..color = Colors.black.withOpacity((0.14 * k).clamp(0.0, 0.30))
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..isAntiAlias = true
        ..strokeWidth = baseW * 1.05
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 4);

      canvas.drawPath(eyePath.shift(const Offset(0, 0.6)), lashBedShadow);

      // 2) soft blur base
      final blurPaint = Paint()
        ..color = Colors.black.withOpacity((0.16 * k).clamp(0.0, 0.32))
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..isAntiAlias = true
        ..strokeWidth = baseW * 2.10
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 9);

      canvas.drawPath(eyePath, blurPaint);

      // 3) core line
      const innerTaperFrac = 0.24;

      // Determine taper direction using same logic
      final faceBox = face.boundingBox;
      final faceCenterX = faceBox.left + faceBox.width * 0.5;
      final eyeOnLeftSideOfImage = eyeBounds.center.dx < faceCenterX;
      final taperFromStart = !eyeOnLeftSideOfImage;

      _drawVariableStroke(
        canvas: canvas,
        path: eyePath,
        baseWidth: baseW,
        baseAlpha: (0.62 * k).clamp(0.0, 0.90),
        innerTaperFrac: innerTaperFrac,
        taperFromStart: taperFromStart,
        segments: 46,
        paintFactory: (w, a) {
          return Paint()
            ..color = Colors.black.withOpacity(a)
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..isAntiAlias = true
            ..strokeWidth = w;
        },
      );
    }

    // Draw each eye exactly as before (same look), but now per-eye
    drawEyePath(lastLeftEyelinerPath, FaceContourType.leftEye);
    drawEyePath(lastRightEyelinerPath, FaceContourType.rightEye);

    // compatibility
    lastEyelinerPath ??= (Path()
      ..addPath(lastLeftEyelinerPath ?? Path(), Offset.zero)
      ..addPath(lastRightEyelinerPath ?? Path(), Offset.zero));
  }
}