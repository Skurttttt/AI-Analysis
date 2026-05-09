// lib/painters/eyebrow_painter.dart
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

// -----------------------------------------------------------------------------
// Small structs (moved to top-level)
// -----------------------------------------------------------------------------

class _Validated {
  final List<ui.Offset> points;
  final double opacityFactor;
  const _Validated({required this.points, required this.opacityFactor});
}

class _CorridorConstrained {
  final List<ui.Offset> center;
  final List<ui.Offset> top;
  final List<ui.Offset> bottom;
  const _CorridorConstrained({
    required this.center,
    required this.top,
    required this.bottom,
  });
}

class EyebrowPainter {
  final Face face;

  /// Production brow color (used only when debugMode == false)
  final Color browColor;

  /// User intensity (0..1)
  final double intensity;

  /// Brow thickness multiplier
  final double thickness;

  /// Scene luminance (0..1) - used only in production
  final double sceneLuminance;

  /// Optional debug overlay
  final bool debugMode;

  /// If the camera preview is mirrored.
  /// If you already mirror the image before ML, set this to false.
  final bool isMirrored;

  /// ✅ FIX #1: Compatibility only (kept so older callers compile).
  /// Styling is intentionally out of scope for this task.
  final bool hairStrokes;

  /// ✅ NEW: Debug brow color (super dark brown)
  final Color debugBrowColor;

  /// ✅ NEW: Debug brow opacity
  final double debugBrowOpacity;

  /// ✅ NEW: Whether to show debug points (small circles) in debug mode
  final bool debugShowPoints;

  /// EMA stabilization strength (0..0.98)
  /// Higher = smoother (less jitter), but slightly more lag.
  final double emaAlpha;

  /// How long to keep caches
  final Duration emaTtl;

  /// When landmarks disappear, keep last good points briefly to prevent flicker
  final Duration holdLastGood;

  /// Minimum number of eyebrow points required for "good"
  final int minPoints;

  EyebrowPainter({
    required this.face,
    required this.browColor,
    required this.intensity,
    this.thickness = 1.0,
    this.sceneLuminance = 0.50,
    this.debugMode = false,
    this.isMirrored = false,
    // ✅ FIX #1: Add hairStrokes parameter for compatibility
    this.hairStrokes = false,
    // ✅ NEW: Add debug brow color and opacity
    this.debugBrowColor = const Color(0xFF1A0E0A), // super dark brown
    this.debugBrowOpacity = 0.55,
    // ✅ NEW: Whether to show debug points (small circles) in debug mode
    this.debugShowPoints = false, // ✅ Default to false for cleaner debug
    this.emaAlpha = 0.82,
    this.emaTtl = const Duration(seconds: 6),
    this.holdLastGood = const Duration(milliseconds: 250),
    this.minPoints = 4,
  });

  // ---------------------------------------------------------------------------
  // CACHES (static: shared across frames)
  // ---------------------------------------------------------------------------

  // EMA cache (same count points)
  static final Map<String, List<ui.Offset>> _emaCache = {};
  static final Map<String, DateTime> _emaTouched = {};

  // Last-good cache (survives brief landmark dropouts)
  static final Map<String, List<ui.Offset>> _lastGood = {};
  static final Map<String, DateTime> _lastGoodTouched = {};
  static final Map<String, int> _missingFrames = {};

  // Ultra performance: cache pruning should not scan maps every paint.
  static DateTime _lastPrune = DateTime.fromMillisecondsSinceEpoch(0);
  static const Duration _pruneInterval = Duration(seconds: 2);

  // ✅ FIX #2: Use braces for string interpolation
  String _key(String side) {
    final tid = face.trackingId;
    if (tid == null) {
      return 'NO_TRACK_${side}_${identityHashCode(face)}'; // ✅ FIXED
    }
    return 'TID_${tid}_$side';
  }

  void _pruneCaches() {
    final now = DateTime.now();
    if (now.difference(_lastPrune) < _pruneInterval) return;
    _lastPrune = now;

    final dead = <String>[];

    _emaTouched.forEach((k, t) {
      if (now.difference(t) > emaTtl) dead.add(k);
    });

    for (final k in dead) {
      _emaTouched.remove(k);
      _emaCache.remove(k);
    }

    final deadGood = <String>[];
    _lastGoodTouched.forEach((k, t) {
      if (now.difference(t) > emaTtl) deadGood.add(k);
    });

    for (final k in deadGood) {
      _lastGoodTouched.remove(k);
      _lastGood.remove(k);
      _missingFrames.remove(k);
    }
  }

  // ---------------------------------------------------------------------------
  // ENTRY
  // ---------------------------------------------------------------------------

  void paint(Canvas canvas, Size size) {
    final k0 = intensity.clamp(0.0, 1.0);
    if (k0 <= 0.001) return;

    _pruneCaches();

    // Fetch TOP + BOTTOM contours
    var leftTop = _contourOffsets(
      face.contours[FaceContourType.leftEyebrowTop]?.points,
    );
    var leftBot = _contourOffsets(
      face.contours[FaceContourType.leftEyebrowBottom]?.points,
    );

    var rightTop = _contourOffsets(
      face.contours[FaceContourType.rightEyebrowTop]?.points,
    );
    var rightBot = _contourOffsets(
      face.contours[FaceContourType.rightEyebrowBottom]?.points,
    );

    // Centerlines
    var leftTrace = _browCenterline(top: leftTop, bottom: leftBot, t: 0.65);
    var rightTrace = _browCenterline(top: rightTop, bottom: rightBot, t: 0.65);

    // Eye contours for constraints
    var leftEye = _contourOffsets(
      face.contours[FaceContourType.leftEye]?.points,
    );
    var rightEye = _contourOffsets(
      face.contours[FaceContourType.rightEye]?.points,
    );

    final hasAny =
        leftTrace.length >= minPoints || rightTrace.length >= minPoints;
    final hasAnyCached = _lastGood.isNotEmpty;
    if (!hasAny && !hasAnyCached) return;

    // Detect swapped left/right (MLKit can flip in some pipelines)
    if (leftTrace.length >= minPoints && rightTrace.length >= minPoints) {
      final lx = _avgX(leftTrace);
      final rx = _avgX(rightTrace);
      final looksSwapped = lx > rx;
      if (looksSwapped) {
        // swap centerline
        final tmpTrace = leftTrace;
        leftTrace = rightTrace;
        rightTrace = tmpTrace;

        // swap top/bottom too (IMPORTANT for boundary-safe hair strokes)
        final tmpTop = leftTop;
        leftTop = rightTop;
        rightTop = tmpTop;

        final tmpBot = leftBot;
        leftBot = rightBot;
        rightBot = tmpBot;

        // swap eyes too (so constraints remain correct)
        final tmpEye = leftEye;
        leftEye = rightEye;
        rightEye = tmpEye;
      }
    }

    final mirrorOrdering = isMirrored;

    _drawBrowSide(
      canvas: canvas,
      sideKey: _key('L'),
      rawCenter: leftTrace,
      rawTop: leftTop,
      rawBottom: leftBot,
      eyePts: leftEye,
      isLeft: true,
      k0: k0,
      mirrorOrdering: mirrorOrdering,
    );

    _drawBrowSide(
      canvas: canvas,
      sideKey: _key('R'),
      rawCenter: rightTrace,
      rawTop: rightTop,
      rawBottom: rightBot,
      eyePts: rightEye,
      isLeft: false,
      k0: k0,
      mirrorOrdering: mirrorOrdering,
    );
  }

  // ---------------------------------------------------------------------------
  // BROW CENTERLINE HELPER
  // ---------------------------------------------------------------------------

  List<ui.Offset> _browCenterline({
    required List<ui.Offset> top,
    required List<ui.Offset> bottom,
    double t = 0.65,
  }) {
    if (top.length < 4 || bottom.length < 4) return const [];

    // Force stable geometry count for real rendering
    const int targetN = 18;

    final topR = _resampleAny(top, targetN);
    final botR = _resampleAny(bottom, targetN);

    final tt = t.clamp(0.0, 1.0);

    return List<ui.Offset>.generate(targetN, (i) {
      final a = topR[i];
      final b = botR[i];
      return ui.Offset(
        ui.lerpDouble(a.dx, b.dx, tt)!,
        ui.lerpDouble(a.dy, b.dy, tt)!,
      );
    });
  }

  // ---------------------------------------------------------------------------
  // SIDE PROCESSING PIPELINE
  // ---------------------------------------------------------------------------

  void _drawBrowSide({
    required Canvas canvas,
    required String sideKey,
    required List<ui.Offset> rawCenter,
    required List<ui.Offset> rawTop,
    required List<ui.Offset> rawBottom,
    required List<ui.Offset> eyePts,
    required bool isLeft,
    required double k0,
    required bool mirrorOrdering,
  }) {
    final box = face.boundingBox;
    final faceW = max(1.0, box.width);
    final faceH = max(1.0, box.height);

    // 1) Validate centerline only (prevents flicker). If centerline is bad, we fade / fallback.
    final validated = _validateOrFallback(
      key: sideKey,
      raw: rawCenter,
      minPoints: minPoints,
    );
    if (validated.points.isEmpty) return;

    // 2) Order all three sets consistently (inner -> tail)
    var centerOrdered = _orderBrowPoints(
      validated.points,
      isLeft: isLeft,
      mirrorOrdering: mirrorOrdering,
    );

    var topOrdered = _orderBrowPoints(
      rawTop,
      isLeft: isLeft,
      mirrorOrdering: mirrorOrdering,
    );

    var botOrdered = _orderBrowPoints(
      rawBottom,
      isLeft: isLeft,
      mirrorOrdering: mirrorOrdering,
    );

    // 3) Constrain above eye — apply SAME constraint to center/top/bottom
    final constrained = _constrainBrowCorridorAboveEye(
      center: centerOrdered,
      top: topOrdered,
      bottom: botOrdered,
      eye: eyePts,
      faceBox: box,
      faceH: faceH,
    );

    centerOrdered = constrained.center;
    topOrdered = constrained.top;
    botOrdered = constrained.bottom;

    // 4) EMA smooth center + corridor (stability without heavy lag)
    final centerSmoothed = _emaSmoothPoints(key: sideKey, raw: centerOrdered);

    // Use separate keys for top/bottom smoothing (same caches, cheap)
    final topSmoothed = _emaSmoothPoints(key: '${sideKey}_T', raw: topOrdered);
    final botSmoothed = _emaSmoothPoints(key: '${sideKey}_B', raw: botOrdered);

    // 5) Stroke thickness scaling
    final baseStroke = (faceW * 0.010).clamp(1.4, 4.2);
    final strokeW = baseStroke * thickness.clamp(0.75, 1.60);

    // 6) Safety opacity (fade when missing/unstable)
    final safetyOpacity = validated.opacityFactor;

    // 7) Lighting
    final l = sceneLuminance.clamp(0.0, 1.0);
    final darkT = ((0.35 - l) / 0.35).clamp(0.0, 1.0);

    // 8) Opacity math
    final eased = pow(k0, 1.6).toDouble();
    final maxBrowOpacity = 0.22; // slightly higher so it won't vanish
    final lightingFactor = ui.lerpDouble(1.0, 0.88, darkT)!;

    var opacity = (eased * maxBrowOpacity * lightingFactor * safetyOpacity)
        .clamp(0.0, 1.0);

    // ✅ FORCE VISIBILITY when user slider is high (tuning safety)
    // This prevents the "eyebrows disappear at 100%" problem.
    if (intensity >= 0.90) {
      opacity = max(opacity, 0.10);
    }

    final color = _softenColor(browColor, darkT: darkT);

    _drawBrow(
      canvas: canvas,
      centerPts: centerSmoothed,
      topPts: topSmoothed,
      bottomPts: botSmoothed,
      box: box,
      faceW: faceW,
      faceH: faceH,
      strokeW: strokeW,
      color: color,
      opacity: opacity,
      isLeft: isLeft,
      darkT: darkT,
      safetyOpacity: safetyOpacity,
    );
  }

  // ---------------------------------------------------------------------------
  // ✅ UPDATED _drawBrow() METHOD
  // - Centerline drives everything (corridor rebuilt from center)
  // - Powder base (gradient + blur) (lighting-aware)
  // - Top edge soft fade, bottom edge grounded
  // - Hair strokes (controlled, curved, direction varies)
  // - Clip safety (mandatory)
  // ---------------------------------------------------------------------------

  void _drawBrow({
    required Canvas canvas,
    required List<ui.Offset> centerPts,
    required List<ui.Offset> topPts,
    required List<ui.Offset> bottomPts,
    required Rect box,
    required double faceW,
    required double faceH,
    required double strokeW,
    required Color color,
    required double opacity,
    required bool isLeft,
    required double darkT,
    required double safetyOpacity,
  }) {
    // Need corridor data
    if (centerPts.length < 4 || topPts.length < 4 || bottomPts.length < 4) {
      return;
    }

    // ✅ STEP 1 - REBUILD CORRIDOR FROM CENTERLINE
    const int n = 24;
    final c = _resampleAny(centerPts, n);
    final tRaw = _resampleAny(topPts, n);
    final bRaw = _resampleAny(bottomPts, n);

    final rebuilt = _rebuildCorridorFromCenter(c, tRaw, bRaw);
    final t = rebuilt.$1;
    final b = rebuilt.$2;

    // Bounds for layer (tight, fast)
    final bounds = _boundsOf3(c, t, b).inflate(max(14.0, strokeW * 10));

    // -------------------------
    // DEBUG MODE: show corridor + center
    // -------------------------
    if (debugMode) {
      final debugMaster =
          (pow(intensity.clamp(0.0, 1.0), 1.2).toDouble() * debugBrowOpacity)
              .clamp(0.0, debugBrowOpacity);

      final corridorPaintTop = Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3
        ..color = debugBrowColor.withOpacity(
          debugMaster * 0.85 * safetyOpacity,
        );

      final corridorPaintBottom = Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3
        ..color = debugBrowColor.withOpacity(
          debugMaster * 0.65 * safetyOpacity,
        );

      final centerPaint = Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.7
        ..color = debugBrowColor.withOpacity(debugMaster * 1.0 * safetyOpacity);

      canvas.drawPath(_buildSmoothOpenPath(t), corridorPaintTop);
      canvas.drawPath(_buildSmoothOpenPath(b), corridorPaintBottom);
      canvas.drawPath(_buildSmoothOpenPath(c), centerPaint);

      if (debugShowPoints) {
        final dot = Paint()
          ..color = Colors.white.withOpacity(0.85 * safetyOpacity);
        for (final pt in c) {
          canvas.drawCircle(pt, 2.0, dot);
        }
      }
      return;
    }

    // -------------------------
    // PRODUCTION
    // -------------------------
    final master = opacity.clamp(0.0, 0.35);
    final visibleMaster = intensity >= 0.90 ? max(master, 0.085) : master;
    if (visibleMaster < 0.004) return;

    final corridorPath = _buildCorridorClosedPath(top: t, bottom: b);

    // Stable RNG per brow
    final seed =
        (face.trackingId ?? 7) * 10007 +
        (isLeft ? 31 : 97) +
        (isLeft ? 13 : 29);
    final rng = Random(seed);

    // Hair count (120–280 max per brow)
    final targetHairCount =
        ((150 + faceW * 1.15) *
                ui.lerpDouble(0.85, 1.15, intensity.clamp(0.0, 1.0))!)
            .round()
            .clamp(120, 280);

    // Corridor thickness reference (for blur + lengths)
    double avgThick = 0.0;
    for (int i = 0; i < n; i++) {
      avgThick += (t[i] - b[i]).distance;
    }
    avgThick = (avgThick / n).clamp(3.0, 26.0);

    // Prevent “one-line stacking” at starts
    final starts = <ui.Offset>[];
    final minStartDist = (avgThick * 0.18).clamp(1.2, 3.2);

    bool tooClose(ui.Offset p) {
      for (final s in starts) {
        if ((s - p).distance < minStartDist) return true;
      }
      return false;
    }

    // Choose blend mode for base depending on exposure
    final baseBlend = (sceneLuminance >= 0.52)
        ? BlendMode.softLight
        : BlendMode.multiply;

    // ---- Layer for brow (clip everything to corridor) ----
    canvas.saveLayer(bounds, Paint());
    canvas.save();
    canvas.clipPath(corridorPath);

    // =====================================================
    // 1) POWDER BASE (soft blurred fill + lighting-aware blend)
    // =====================================================
    final corridorCenter = _corridorCenter(t, b);
    final head = corridorCenter.first;
    final tail = corridorCenter.last;

    final grad = ui.Gradient.linear(
      head,
      tail,
      [
        color.withOpacity(visibleMaster * 0.18 * safetyOpacity), // inner
        color.withOpacity(visibleMaster * 0.24 * safetyOpacity), // mid
        color.withOpacity(visibleMaster * 0.30 * safetyOpacity), // tail
      ],
      [0.0, 0.55, 1.0],
    );

    final powderPaint = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.fill
      ..shader = grad
      ..blendMode = baseBlend
      ..maskFilter = ui.MaskFilter.blur(
        ui.BlurStyle.normal,
        (avgThick * 0.30).clamp(0.9, 3.2),
      );

    canvas.drawPath(corridorPath, powderPaint);

    // Tail deepen (subtle)
    final tailDeepen = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.fill
      ..blendMode = BlendMode.multiply
      ..color = Colors.black.withOpacity(
        (visibleMaster * 0.035).clamp(0.0, 0.07) * safetyOpacity,
      )
      ..maskFilter = ui.MaskFilter.blur(
        ui.BlurStyle.normal,
        (avgThick * 0.18).clamp(0.7, 2.4),
      );

    final tailZone = _tailZonePath(corridorCenter, t, b, startU: 0.68);
    canvas.drawPath(tailZone, tailDeepen);

    // Head soften (micro blur pass)
    if (corridorCenter.length > 5) {
      final headStartIndex = (0.22 * (corridorCenter.length - 1)).floor().clamp(
        0,
        corridorCenter.length - 1,
      );

      if (headStartIndex > 0) {
        final headTop = t.sublist(0, headStartIndex + 1);
        final headBottom = b.sublist(0, headStartIndex + 1).reversed.toList();

        final headPath = Path();
        if (headTop.isNotEmpty && headBottom.isNotEmpty) {
          headPath.moveTo(headTop.first.dx, headTop.first.dy);
          for (int i = 1; i < headTop.length; i++) {
            headPath.lineTo(headTop[i].dx, headTop[i].dy);
          }
          for (int i = 0; i < headBottom.length; i++) {
            headPath.lineTo(headBottom[i].dx, headBottom[i].dy);
          }
          headPath.close();

          canvas.drawPath(
            headPath,
            Paint()
              ..blendMode = BlendMode.softLight
              ..maskFilter = ui.MaskFilter.blur(
                ui.BlurStyle.normal,
                (avgThick * 0.35).clamp(0.9, 3.6),
              )
              ..color = color.withOpacity(visibleMaster * 0.06 * safetyOpacity),
          );
        }
      }
    }

    // =====================================================
    // EDGE BEHAVIOR (required)
    // - TOP edge: soft fade into skin
    // - BOTTOM edge: defined anchor
    // =====================================================
    _drawEdgeBehavior(
      canvas: canvas,
      top: t,
      bottom: b,
      avgThick: avgThick,
      color: color,
      visibleMaster: visibleMaster,
      safetyOpacity: safetyOpacity,
      isBrightScene: sceneLuminance >= 0.52,
    );

    // =====================================================
    // 2) HAIR STROKES (curved, clipped, stable)
    // =====================================================
    final hairPaint = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..blendMode = BlendMode.multiply;

    final hairHaze = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..blendMode = BlendMode.softLight
      ..maskFilter = ui.MaskFilter.blur(
        ui.BlurStyle.normal,
        (avgThick * 0.14).clamp(0.6, 1.8),
      );

    final minW = (strokeW * 0.10).clamp(0.40, 0.70);
    final maxW = (strokeW * 0.18).clamp(0.55, 1.10);

    double densityAt(double u) {
      if (u < 0.18) return ui.lerpDouble(0.35, 0.75, u / 0.18)!;
      if (u < 0.70) {
        return ui.lerpDouble(0.85, 1.00, (u - 0.18) / (0.70 - 0.18))!;
      }
      return ui.lerpDouble(0.95, 0.90, (u - 0.70) / (1.0 - 0.70))!;
    }

    double shadeAt(double u) {
      return ui.lerpDouble(0.62, 1.25, pow(u, 1.35).toDouble())!;
    }

    for (int k = 0; k < targetHairCount; k++) {
      final baseU = (k + 0.5) / targetHairCount;
      final u = (baseU + (rng.nextDouble() - 0.5) * 0.02).clamp(0.0, 1.0);

      final headFade = u < 0.20 ? ui.lerpDouble(0.25, 1.0, u / 0.20)! : 1.0;

      final rv = rng.nextDouble();
      final v = (0.18 + rv * 0.64); // [0.18..0.82]

      if (rng.nextDouble() > densityAt(u)) continue;

      final p = _sampleCorridorPoint(t, b, u, v);
      final dir = _hairDirectionAtU(c, u, isLeft: isLeft);

      final baseLen = ui.lerpDouble(1.8, 5.2, sin(pi * u))!;
      final tailBonus = ui.lerpDouble(0.0, 1.4, pow(u, 1.6).toDouble())!;
      final len =
          (baseLen + tailBonus + rng.nextDouble() * 1.9) *
          (0.85 + 0.25 * shadeAt(u));

      final jitter = (rng.nextDouble() - 0.5);
      final curveAmt = (avgThick * 0.10).clamp(0.4, 1.4);

      final start = ui.Offset(
        p.dx + jitter * curveAmt,
        p.dy + jitter * curveAmt * 0.45,
      );

      if (tooClose(start)) continue;
      starts.add(start);

      final end = ui.Offset(start.dx + dir.dx * len, start.dy + dir.dy * len);

      final ctrl = ui.Offset(
        (start.dx + end.dx) * 0.5 + (-dir.dy) * (jitter * curveAmt * 0.8),
        (start.dy + end.dy) * 0.5 + (dir.dx) * (jitter * curveAmt * 0.35),
      );

      final a =
          (visibleMaster *
                  ui.lerpDouble(0.08, 0.26, pow(u, 1.15).toDouble())! *
                  safetyOpacity *
                  headFade)
              .clamp(0.03, 0.36);

      final w = ui.lerpDouble(minW, maxW, pow(u, 0.9).toDouble())!;
      hairPaint
        ..strokeWidth = w
        ..color = color.withOpacity(a);

      hairHaze
        ..strokeWidth = w * 1.35
        ..color = color.withOpacity(a * 0.28);

      final hairPath = Path()
        ..moveTo(start.dx, start.dy)
        ..quadraticBezierTo(ctrl.dx, ctrl.dy, end.dx, end.dy);

      canvas.drawPath(hairPath, hairPaint);
      canvas.drawPath(hairPath, hairHaze);
    }

    // Optional: a tiny post-pass bottom anchor to “ground” hairs into skin
    _drawBottomAnchorPostPass(
      canvas: canvas,
      bottom: b,
      avgThick: avgThick,
      color: color,
      visibleMaster: visibleMaster,
      safetyOpacity: safetyOpacity,
    );

    // =====================================================
    // 3) MICRO TEXTURE (optional, ultra subtle)
    // =====================================================
    final enableGrain = true;
    if (enableGrain && visibleMaster > 0.02) {
      final grainSeed = seed * 31 + 11;
      final grng = Random(grainSeed);

      final grainCount = (80 + avgThick * 10).round().clamp(90, 180);

      final grainPaint = Paint()
        ..isAntiAlias = true
        ..blendMode = BlendMode.softLight
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 1.0
        ..color = Colors.white.withOpacity(
          (visibleMaster * 0.018).clamp(0.0, 0.03) * safetyOpacity,
        );

      for (int i = 0; i < grainCount; i++) {
        final u = grng.nextDouble();
        final v = 0.22 + grng.nextDouble() * 0.56;
        final p = _sampleCorridorPoint(t, b, u, v);

        final jx = (grng.nextDouble() - 0.5) * 1.2;
        final jy = (grng.nextDouble() - 0.5) * 1.0;

        canvas.drawPoints(ui.PointMode.points, [
          ui.Offset(p.dx + jx, p.dy + jy),
        ], grainPaint);
      }
    }

    // ---- restore clip + layer ----
    canvas.restore();
    canvas.restore();
  }

  // ---------------------------------------------------------------------------
  // ✅ EDGE BEHAVIOR HELPERS
  // ---------------------------------------------------------------------------

  void _drawEdgeBehavior({
    required Canvas canvas,
    required List<ui.Offset> top,
    required List<ui.Offset> bottom,
    required double avgThick,
    required Color color,
    required double visibleMaster,
    required double safetyOpacity,
    required bool isBrightScene,
  }) {
    // TOP: feather into skin (blur + softLight)
    final topFeather = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..blendMode = BlendMode.softLight
      ..strokeWidth = (avgThick * 0.95).clamp(3.0, 12.0)
      ..maskFilter = ui.MaskFilter.blur(
        ui.BlurStyle.normal,
        (avgThick * 0.55).clamp(1.2, 4.6),
      )
      ..color = color.withOpacity(
        (visibleMaster * (isBrightScene ? 0.10 : 0.08)).clamp(0.02, 0.14) *
            safetyOpacity,
      );

    canvas.drawPath(_buildSmoothOpenPath(top), topFeather);

    // BOTTOM: grounded anchor (sharper + multiply)
    final bottomAnchor = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..blendMode = BlendMode.multiply
      ..strokeWidth = (avgThick * 0.30).clamp(1.2, 4.0)
      ..maskFilter = ui.MaskFilter.blur(
        ui.BlurStyle.normal,
        (avgThick * 0.10).clamp(0.5, 1.2),
      )
      ..color = Colors.black.withOpacity(
        (visibleMaster * 0.14).clamp(0.03, 0.16) * safetyOpacity,
      );

    canvas.drawPath(_buildSmoothOpenPath(bottom), bottomAnchor);
  }

  void _drawBottomAnchorPostPass({
    required Canvas canvas,
    required List<ui.Offset> bottom,
    required double avgThick,
    required Color color,
    required double visibleMaster,
    required double safetyOpacity,
  }) {
    // A very subtle, thin pass after hairs to prevent “floating”
    final post = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..blendMode = BlendMode.multiply
      ..strokeWidth = (avgThick * 0.18).clamp(0.9, 2.4)
      ..color = color.withOpacity(
        (visibleMaster * 0.06).clamp(0.01, 0.08) * safetyOpacity,
      );

    canvas.drawPath(_buildSmoothOpenPath(bottom), post);
  }

  // ---------------------------------------------------------------------------
  // ✅ CORRIDOR REBUILD HELPER (Added for drift fix)
  // ---------------------------------------------------------------------------

  (List<ui.Offset>, List<ui.Offset>) _rebuildCorridorFromCenter(
    List<ui.Offset> c,
    List<ui.Offset> tRaw,
    List<ui.Offset> bRaw,
  ) {
    final n = min(c.length, min(tRaw.length, bRaw.length));
    if (n < 4) return (tRaw, bRaw);

    double dot(ui.Offset a, ui.Offset b) => a.dx * b.dx + a.dy * b.dy;

    final up = List<double>.filled(n, 0.0);
    final dn = List<double>.filled(n, 0.0);

    double fallbackHalf = 0.0;
    for (int i = 0; i < n; i++) {
      fallbackHalf += (tRaw[i] - bRaw[i]).distance * 0.5;
    }
    fallbackHalf = (fallbackHalf / n).clamp(2.0, 14.0);

    for (int i = 0; i < n; i++) {
      final prev = c[max(0, i - 1)];
      final next = c[min(n - 1, i + 1)];
      final tan = next - prev;
      final tanLen = tan.distance + 1e-6;

      final normal = ui.Offset(-tan.dy / tanLen, tan.dx / tanLen);

      final vTop = tRaw[i] - c[i];
      final vBot = bRaw[i] - c[i];

      double dTop = dot(vTop, normal);
      double dBot = dot(vBot, normal);

      dTop = dTop.abs();
      dBot = dBot.abs();

      final fullRaw = (tRaw[i] - bRaw[i]).distance;
      final maxHalf = (fullRaw * 0.60).clamp(3.0, 16.0);
      final minHalf = 1.8;

      final dTopSafe = dTop.isFinite
          ? dTop.clamp(minHalf, maxHalf)
          : fallbackHalf;
      final dBotSafe = dBot.isFinite
          ? dBot.clamp(minHalf, maxHalf)
          : fallbackHalf;

      up[i] = dTopSafe;
      dn[i] = dBotSafe;
    }

    List<double> smooth1D(List<double> arr, {int passes = 2}) {
      var cur = List<double>.from(arr);
      for (int p = 0; p < passes; p++) {
        final out = List<double>.from(cur);
        for (int i = 1; i < cur.length - 1; i++) {
          out[i] = (cur[i - 1] + 2 * cur[i] + cur[i + 1]) / 4.0;
        }
        cur = out;
      }
      return cur;
    }

    final upS = smooth1D(up, passes: 2);
    final dnS = smooth1D(dn, passes: 2);

    // Asymmetric thickness: more below, less above
    const topBias = 0.42;
    const bottomBias = 0.58;

    final outTop = <ui.Offset>[];
    final outBot = <ui.Offset>[];

    for (int i = 0; i < n; i++) {
      final prev = c[max(0, i - 1)];
      final next = c[min(n - 1, i + 1)];
      final tan = next - prev;
      final tanLen = tan.distance + 1e-6;
      final normal = ui.Offset(-tan.dy / tanLen, tan.dx / tanLen);

      final half = ((upS[i] + dnS[i]) * 0.5).clamp(2.0, 14.0);

      final upHalf = (half * topBias).clamp(1.4, 9.0);
      final dnHalf = (half * bottomBias).clamp(1.6, 11.0);

      final topP = c[i] + ui.Offset(normal.dx * upHalf, normal.dy * upHalf);
      final botP = c[i] - ui.Offset(normal.dx * dnHalf, normal.dy * dnHalf);

      outTop.add(topP);
      outBot.add(botP);
    }

    return (outTop, outBot);
  }

  // ---------------------------------------------------------------------------
  // ✅ HELPER FUNCTIONS
  // ---------------------------------------------------------------------------

  Path _buildCorridorClosedPath({
    required List<ui.Offset> top,
    required List<ui.Offset> bottom,
  }) {
    // Keep your existing smooth edges; close as a corridor.
    // Note: addPath contains moveTo; we still close, and clip remains correct.
    final tPath = _buildSmoothOpenPath(top);
    final bRev = bottom.reversed.toList();
    final bPath = _buildSmoothOpenPath(bRev);

    final m = Path()..addPath(tPath, ui.Offset.zero);
    if (bRev.isNotEmpty) {
      m.lineTo(bRev.first.dx, bRev.first.dy);
    }
    m.addPath(bPath, ui.Offset.zero);
    m.close();
    return m;
  }

  List<ui.Offset> _corridorCenter(List<ui.Offset> top, List<ui.Offset> bottom) {
    final n = min(top.length, bottom.length);
    return List<ui.Offset>.generate(n, (i) {
      return ui.Offset(
        ui.lerpDouble(bottom[i].dx, top[i].dx, 0.5)!,
        ui.lerpDouble(bottom[i].dy, top[i].dy, 0.5)!,
      );
    });
  }

  Path _tailZonePath(
    List<ui.Offset> center,
    List<ui.Offset> top,
    List<ui.Offset> bottom, {
    required double startU,
  }) {
    final n = min(min(center.length, top.length), bottom.length);
    final startI = (startU.clamp(0.0, 1.0) * (n - 1)).floor().clamp(0, n - 2);

    final topSeg = top.sublist(startI);
    final botSeg = bottom.sublist(startI).reversed.toList();

    final p = Path();
    if (topSeg.isEmpty || botSeg.isEmpty) return p;

    p.moveTo(topSeg.first.dx, topSeg.first.dy);
    for (int i = 1; i < topSeg.length; i++) {
      p.lineTo(topSeg[i].dx, topSeg[i].dy);
    }
    for (int i = 0; i < botSeg.length; i++) {
      p.lineTo(botSeg[i].dx, botSeg[i].dy);
    }
    p.close();
    return p;
  }

  ui.Offset _sampleCorridorPoint(
    List<ui.Offset> top,
    List<ui.Offset> bottom,
    double u,
    double v,
  ) {
    final n = min(top.length, bottom.length);
    if (n <= 1) return top.isNotEmpty ? top.first : const ui.Offset(0, 0);

    final fu = (u.clamp(0.0, 1.0)) * (n - 1);
    final i0 = fu.floor().clamp(0, n - 1);
    final i1 = min(n - 1, i0 + 1);
    final tt = fu - i0;

    final topP = ui.Offset(
      ui.lerpDouble(top[i0].dx, top[i1].dx, tt)!,
      ui.lerpDouble(top[i0].dy, top[i1].dy, tt)!,
    );
    final botP = ui.Offset(
      ui.lerpDouble(bottom[i0].dx, bottom[i1].dx, tt)!,
      ui.lerpDouble(bottom[i0].dy, bottom[i1].dy, tt)!,
    );

    final vv = v.clamp(0.0, 1.0);
    return ui.Offset(
      ui.lerpDouble(botP.dx, topP.dx, vv)!,
      ui.lerpDouble(botP.dy, topP.dy, vv)!,
    );
  }

  ui.Offset _hairDirectionAtU(
    List<ui.Offset> center,
    double u, {
    required bool isLeft,
  }) {
    final n = center.length;
    if (n < 3) return ui.Offset(isLeft ? -0.6 : 0.6, -0.8);

    final fu = u.clamp(0.0, 1.0) * (n - 1);
    final i = fu.floor().clamp(1, n - 2);

    final prev = center[i - 1];
    final next = center[i + 1];
    final tan = next - prev;
    final tanLen = tan.distance + 1e-6;
    final tx = tan.dx / tanLen;
    final ty = tan.dy / tanLen;

    final nx = -ty;
    final ny = tx;

    final outward = isLeft ? -1.0 : 1.0;

    final headT = (1.0 - (u / 0.25).clamp(0.0, 1.0));
    final tailT = ((u - 0.65) / 0.35).clamp(0.0, 1.0);

    double dx = nx * (0.85 * outward) + tx * 0.18;
    double dy = ny * 0.55 + ty * 0.10 - 0.40;

    dx = ui.lerpDouble(dx, 0.10 * outward, headT)!;
    dy = ui.lerpDouble(dy, -0.95, headT)!;

    dx = ui.lerpDouble(dx, tx, tailT)!;
    dy = ui.lerpDouble(dy, ty * 0.15 - 0.20, tailT)!;

    final len = sqrt(dx * dx + dy * dy) + 1e-6;
    return ui.Offset(dx / len, dy / len);
  }

  // ---------------------------------------------------------------------------
  // SMOOTH PATH BUILDER
  // ---------------------------------------------------------------------------

  Path _buildSmoothOpenPath(List<ui.Offset> pts) {
    final path = Path();
    if (pts.isEmpty) return path;
    if (pts.length < 3) {
      path.moveTo(pts.first.dx, pts.first.dy);
      for (int i = 1; i < pts.length; i++) {
        path.lineTo(pts[i].dx, pts[i].dy);
      }
      return path;
    }

    path.moveTo(pts[0].dx, pts[0].dy);

    for (int i = 0; i < pts.length - 1; i++) {
      final p0 = (i == 0) ? pts[i] : pts[i - 1];
      final p1 = pts[i];
      final p2 = pts[i + 1];
      final p3 = (i + 2 < pts.length) ? pts[i + 2] : pts[i + 1];

      final c1 = ui.Offset(
        p1.dx + (p2.dx - p0.dx) / 6.0,
        p1.dy + (p2.dy - p0.dy) / 6.0,
      );
      final c2 = ui.Offset(
        p2.dx - (p3.dx - p1.dx) / 6.0,
        p2.dy - (p3.dy - p1.dy) / 6.0,
      );

      path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
    }

    return path;
  }

  // ---------------------------------------------------------------------------
  // VALIDATION + FLICKER SAFETY
  // ---------------------------------------------------------------------------

  _Validated _validateOrFallback({
    required String key,
    required List<ui.Offset> raw,
    required int minPoints,
  }) {
    final now = DateTime.now();

    bool good = raw.length >= minPoints;

    if (good) {
      final spanX = _spanX(raw);
      final spanY = _spanY(raw);
      if (spanX < 6.0 || spanY < 2.0) good = false;
    }

    if (good) {
      _lastGood[key] = raw;
      _lastGoodTouched[key] = now;
      _missingFrames[key] = 0;
      return _Validated(points: raw, opacityFactor: 1.0);
    }

    final last = _lastGood[key];
    final lastT = _lastGoodTouched[key];

    if (last == null || lastT == null) {
      return const _Validated(points: <ui.Offset>[], opacityFactor: 0.0);
    }

    final age = now.difference(lastT);
    if (age > holdLastGood) {
      return const _Validated(points: <ui.Offset>[], opacityFactor: 0.0);
    }

    final miss = (_missingFrames[key] ?? 0) + 1;
    _missingFrames[key] = miss;

    final fade = (1.0 - (miss / 6.0)).clamp(0.15, 0.85);

    return _Validated(points: last, opacityFactor: fade);
  }

  // ---------------------------------------------------------------------------
  // ORDERING: inner -> arch -> tail
  // ---------------------------------------------------------------------------

  List<ui.Offset> _orderBrowPoints(
    List<ui.Offset> pts, {
    required bool isLeft,
    required bool mirrorOrdering,
  }) {
    if (pts.length <= 2) return pts;

    final p = List<ui.Offset>.from(pts);

    int aIdx = 0;
    int bIdx = 0;
    double bestD = -1;

    for (int i = 0; i < p.length; i++) {
      for (int j = i + 1; j < p.length; j++) {
        final d = (p[i] - p[j]).distanceSquared;
        if (d > bestD) {
          bestD = d;
          aIdx = i;
          bIdx = j;
        }
      }
    }

    final A = p[aIdx];
    final B = p[bIdx];
    final axis = B - A;
    final axisLen = axis.distance + 1e-6;
    final ux = axis.dx / axisLen;
    final uy = axis.dy / axisLen;

    final scored = p.map((pt) {
      final vx = pt.dx - A.dx;
      final vy = pt.dy - A.dy;
      final s = vx * ux + vy * uy;
      return (pt: pt, s: s);
    }).toList()..sort((m, n) => m.s.compareTo(n.s));

    var ordered = scored.map((e) => e.pt).toList();

    final start = ordered.first;
    final end = ordered.last;

    bool startLooksInner;
    if (!mirrorOrdering) {
      startLooksInner = isLeft ? (start.dx > end.dx) : (start.dx < end.dx);
    } else {
      startLooksInner = isLeft ? (start.dx < end.dx) : (start.dx > end.dx);
    }

    if (!startLooksInner) {
      ordered = ordered.reversed.toList();
    }

    return _spatialSmooth(ordered, passes: 1);
  }

  // ---------------------------------------------------------------------------
  // EMA SMOOTHING (temporal)
  // ---------------------------------------------------------------------------

  List<ui.Offset> _emaSmoothPoints({
    required String key,
    required List<ui.Offset> raw,
  }) {
    if (raw.isEmpty) return raw;

    final a = emaAlpha.clamp(0.0, 0.98);

    if (a <= 0.0) {
      _emaCache[key] = List<ui.Offset>.from(raw);
      _emaTouched[key] = DateTime.now();
      return raw;
    }

    final prev = _emaCache[key];
    if (prev == null || prev.isEmpty || prev.length != raw.length) {
      _emaCache[key] = List<ui.Offset>.from(raw);
      _emaTouched[key] = DateTime.now();
      return raw;
    }

    final out = <ui.Offset>[];
    for (int i = 0; i < raw.length; i++) {
      final p = raw[i];
      final q = prev[i];
      out.add(
        ui.Offset(q.dx * a + p.dx * (1.0 - a), q.dy * a + p.dy * (1.0 - a)),
      );
    }

    _emaCache[key] = out;
    _emaTouched[key] = DateTime.now();
    return out;
  }

  // ---------------------------------------------------------------------------
  // ✅ NEW HELPER FUNCTIONS (Corridor management)
  // ---------------------------------------------------------------------------

  _CorridorConstrained _constrainBrowCorridorAboveEye({
    required List<ui.Offset> center,
    required List<ui.Offset> top,
    required List<ui.Offset> bottom,
    required List<ui.Offset> eye,
    required Rect faceBox,
    required double faceH,
  }) {
    if (center.isEmpty) {
      return _CorridorConstrained(center: center, top: top, bottom: bottom);
    }

    final fallbackEyeTop = faceBox.top + faceH * 0.35;
    final eyeTopY = eye.isEmpty
        ? fallbackEyeTop
        : eye.map((p) => p.dy).reduce(min);

    final browMinY = center.map((p) => p.dy).reduce(min);

    final margin = (faceH * 0.035).clamp(6.0, 16.0);
    final maxAllowedY = eyeTopY - margin;

    final minAllowedY = faceBox.top + faceH * 0.06;

    double shiftY = 0.0;
    if (browMinY > maxAllowedY) {
      shiftY = maxAllowedY - browMinY;
    }

    final slack = (faceH * 0.015).clamp(2.0, 6.0);
    final topClamp = minAllowedY;
    final bottomClamp = maxAllowedY + slack;

    List<ui.Offset> apply(List<ui.Offset> pts) {
      return pts
          .map(
            (p) =>
                ui.Offset(p.dx, (p.dy + shiftY).clamp(topClamp, bottomClamp)),
          )
          .toList();
    }

    return _CorridorConstrained(
      center: apply(center),
      top: apply(top),
      bottom: apply(bottom),
    );
  }

  List<ui.Offset> _resampleAny(List<ui.Offset> pts, int n) {
    if (pts.isEmpty) return pts;
    if (n <= 2) return [pts.first, pts.last];

    final out = <ui.Offset>[];
    final step = (pts.length - 1) / (n - 1);

    for (int i = 0; i < n; i++) {
      final idx = i * step;
      final a = idx.floor();
      final b = min(pts.length - 1, a + 1);
      final t = idx - a;

      final pa = pts[a];
      final pb = pts[b];

      out.add(
        ui.Offset(
          ui.lerpDouble(pa.dx, pb.dx, t)!,
          ui.lerpDouble(pa.dy, pb.dy, t)!,
        ),
      );
    }
    return out;
  }

  Rect _boundsOf3(List<ui.Offset> a, List<ui.Offset> b, List<ui.Offset> c) {
    double minX = double.infinity, minY = double.infinity;
    double maxX = -double.infinity, maxY = -double.infinity;

    void eat(ui.Offset p) {
      minX = min(minX, p.dx);
      minY = min(minY, p.dy);
      maxX = max(maxX, p.dx);
      maxY = max(maxY, p.dy);
    }

    for (final p in a) {
      eat(p);
    }
    for (final p in b) {
      eat(p);
    }
    for (final p in c) {
      eat(p);
    }

    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  // ---------------------------------------------------------------------------
  // HELPERS
  // ---------------------------------------------------------------------------

  List<ui.Offset> _contourOffsets(List<Point<int>>? pts) {
    if (pts == null || pts.isEmpty) return const [];
    return pts.map((p) => ui.Offset(p.x.toDouble(), p.y.toDouble())).toList();
  }

  double _avgX(List<ui.Offset> pts) {
    if (pts.isEmpty) return 0;
    double s = 0;
    for (final p in pts) {
      s += p.dx;
    }
    return s / pts.length;
  }

  double _spanX(List<ui.Offset> pts) {
    double mn = double.infinity, mx = -double.infinity;
    for (final p in pts) {
      mn = min(mn, p.dx);
      mx = max(mx, p.dx);
    }
    return mx - mn;
  }

  double _spanY(List<ui.Offset> pts) {
    double mn = double.infinity, mx = -double.infinity;
    for (final p in pts) {
      mn = min(mn, p.dy);
      mx = max(mx, p.dy);
    }
    return mx - mn;
  }

  List<ui.Offset> _spatialSmooth(List<ui.Offset> pts, {int passes = 1}) {
    if (pts.length < 3) return pts;

    var cur = List<ui.Offset>.from(pts);

    for (int p = 0; p < passes; p++) {
      final out = <ui.Offset>[];
      out.add(cur.first);
      for (int i = 1; i < cur.length - 1; i++) {
        final a = cur[i - 1];
        final b = cur[i];
        final c = cur[i + 1];
        out.add(
          ui.Offset(
            (a.dx + 2 * b.dx + c.dx) / 4.0,
            (a.dy + 2 * b.dy + c.dy) / 4.0,
          ),
        );
      }
      out.add(cur.last);
      cur = out;
    }

    return cur;
  }

  // ✅ Keep both resample methods for compatibility
  Color _softenColor(Color c, {required double darkT}) {
    final hsl = HSLColor.fromColor(c);
    final s = (hsl.saturation * ui.lerpDouble(0.95, 0.85, darkT)!).clamp(
      0.0,
      1.0,
    );
    final l = (hsl.lightness * ui.lerpDouble(1.00, 0.92, darkT)!).clamp(
      0.0,
      1.0,
    );
    return hsl.withSaturation(s).withLightness(l).toColor();
  }
}

// -----------------------------------------------------------------------------
// CORRIDOR HELPER (Added at bottom of file)
// -----------------------------------------------------------------------------

