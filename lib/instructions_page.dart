import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import 'look_engine.dart';
import 'openai_service.dart';
import 'skin_analyzer.dart';
import 'painters/lip_guide_painter.dart';
import 'painters/eyebrow_guide_painter.dart';
import 'painters/base_prep_guide_painter.dart';
import 'painters/eyeshadow_guide_painter.dart';
import 'painters/eyeliner_guide_painter.dart';
import 'widgets/lip_guide_card.dart';
import 'widgets/eyebrow_guide_card.dart';
import 'widgets/base_prep_guide_card.dart';
import 'widgets/eyeshadow_guide_card.dart';
import 'widgets/eyeliner_guide_card.dart';
import 'widgets/blush_contour_guide_card.dart';
import 'widgets/final_look_guide_card.dart';

class InstructionsPage extends StatefulWidget {
  final LookResult look;
  final FaceProfile? faceProfile;
  final String? scannedImagePath;
  final Face? detectedFace;
  final MakeupLookPreset selectedPreset;

  const InstructionsPage({
    super.key,
    required this.look,
    this.faceProfile,
    this.scannedImagePath,
    this.detectedFace,
    this.selectedPreset = MakeupLookPreset.softGlam,
  });

  @override
  State<InstructionsPage> createState() => _InstructionsPageState();
}

class _InstructionsPageState extends State<InstructionsPage> {
  bool _loadingAI = false;
  List<Map<String, dynamic>> _aiSteps = [];
  String? _aiError;
  String? _lipGuideImagePath;
  bool _generatingLipGuide = false;
  String? _eyebrowGuideImagePath;
  bool _generatingEyebrowGuide = false;
  String? _basePrepGuideImagePath;
  bool _generatingBasePrepGuide = false;
  String? _eyeshadowGuideImagePath;
  bool _generatingEyeshadowGuide = false;
  String? _eyelinerGuideImagePath;
  bool _generatingEyelinerGuide = false;

  final _openAI = OpenAIService();
  final PageController _pageController = PageController();

  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<ui.Image> _loadUiImageFromFile(String path) async {
    final bytes = await File(path).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes, targetWidth: 720);
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  Rect? _computeLipCropRect(Face face, ui.Image image) {
    final upperTop = face.contours[FaceContourType.upperLipTop]?.points;
    final upperBottom = face.contours[FaceContourType.upperLipBottom]?.points;
    final lowerTop = face.contours[FaceContourType.lowerLipTop]?.points;
    final lowerBottom = face.contours[FaceContourType.lowerLipBottom]?.points;

    final all = <Point<int>>[
      ...?upperTop,
      ...?upperBottom,
      ...?lowerTop,
      ...?lowerBottom,
    ];

    if (all.length < 8) return null;

    double minX = all.first.x.toDouble();
    double maxX = all.first.x.toDouble();
    double minY = all.first.y.toDouble();
    double maxY = all.first.y.toDouble();

    for (final p in all.skip(1)) {
      final x = p.x.toDouble();
      final y = p.y.toDouble();
      if (x < minX) minX = x;
      if (x > maxX) maxX = x;
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;
    }

    final lipW = maxX - minX;
    final lipH = maxY - minY;

    final rect = Rect.fromLTRB(
      minX - lipW * 1.15,
      minY - lipH * 2.2,
      maxX + lipW * 1.15,
      maxY + lipH * 2.0,
    );

    return rect.intersect(
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
    );
  }

  Rect? _computeEyebrowCropRect(Face face, ui.Image image) {
    final leftTop = face.contours[FaceContourType.leftEyebrowTop]?.points;
    final leftBottom = face.contours[FaceContourType.leftEyebrowBottom]?.points;
    final rightTop = face.contours[FaceContourType.rightEyebrowTop]?.points;
    final rightBottom = face.contours[FaceContourType.rightEyebrowBottom]?.points;

    final all = <Point<int>>[
      ...?leftTop,
      ...?leftBottom,
      ...?rightTop,
      ...?rightBottom,
    ];

    if (all.length < 8) return null;

    double minX = all.first.x.toDouble();
    double maxX = all.first.x.toDouble();
    double minY = all.first.y.toDouble();
    double maxY = all.first.y.toDouble();

    for (final p in all.skip(1)) {
      final x = p.x.toDouble();
      final y = p.y.toDouble();
      minX = min(minX, x);
      maxX = max(maxX, x);
      minY = min(minY, y);
      maxY = max(maxY, y);
    }

    final browW = maxX - minX;
    final browH = maxY - minY;

    final rect = Rect.fromLTRB(
      minX - browW * 0.42,
      minY - browH * 4.2,
      maxX + browW * 0.42,
      maxY + browH * 6.0,
    );

    return rect.intersect(
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
    );
  }

  Rect? _computeBasePrepCropRect(Face face, ui.Image image) {
    final box = face.boundingBox;

    if (box.width <= 0 || box.height <= 0) return null;

    final rect = Rect.fromLTRB(
      box.left - box.width * 0.20,
      box.top - box.height * 0.18,
      box.right + box.width * 0.20,
      box.bottom + box.height * 0.10,
    );

    return rect.intersect(
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
    );
  }

  Rect? _computeEyeCropRect(Face face, ui.Image image) {
    final leftEye = face.contours[FaceContourType.leftEye]?.points;
    final rightEye = face.contours[FaceContourType.rightEye]?.points;
    final leftBrow = face.contours[FaceContourType.leftEyebrowTop]?.points;
    final rightBrow = face.contours[FaceContourType.rightEyebrowTop]?.points;

    final all = <Point<int>>[
      ...?leftEye,
      ...?rightEye,
      ...?leftBrow,
      ...?rightBrow,
    ];

    if (all.length < 8) return null;

    double minX = all.first.x.toDouble();
    double maxX = all.first.x.toDouble();
    double minY = all.first.y.toDouble();
    double maxY = all.first.y.toDouble();

    for (final p in all.skip(1)) {
      final x = p.x.toDouble();
      final y = p.y.toDouble();

      minX = min(minX, x);
      maxX = max(maxX, x);
      minY = min(minY, y);
      maxY = max(maxY, y);
    }

    final w = maxX - minX;
    final h = maxY - minY;

    final rect = Rect.fromLTRB(
      minX - w * 0.35,
      minY - h * 0.65,
      maxX + w * 0.35,
      maxY + h * 1.40,
    );

    return rect.intersect(
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
    );
  }

  Future<String> _saveCroppedImage({
    required ui.Image source,
    required Rect cropRect,
    required String prefix,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final dstW = cropRect.width.round();
    final dstH = cropRect.height.round();

    canvas.drawImageRect(
      source,
      cropRect,
      Rect.fromLTWH(0, 0, dstW.toDouble(), dstH.toDouble()),
      Paint(),
    );

    final picture = recorder.endRecording();
    final cropped = await picture.toImage(dstW, dstH);

    final byteData = await cropped.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      throw Exception('Failed to encode guide image.');
    }

    final dir = await Directory.systemTemp.createTemp(prefix);
    final file = File('${dir.path}/guide.png');

    await file.writeAsBytes(byteData.buffer.asUint8List(), flush: true);
    return file.path;
  }

  Color _darken(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    final darkened = hsl.withLightness(
      (hsl.lightness - amount).clamp(0.0, 1.0),
    );
    return darkened.toColor();
  }

  Future<void> _ensureLipGuideGenerated() async {
    if (_lipGuideImagePath != null || _generatingLipGuide) return;
    if (widget.scannedImagePath == null || widget.detectedFace == null) return;

    setState(() {
      _generatingLipGuide = true;
    });

    try {
      final image = await _loadUiImageFromFile(widget.scannedImagePath!);

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      final size = Size(
        image.width.toDouble(),
        image.height.toDouble(),
      );

      canvas.drawImage(image, Offset.zero, Paint());

      LipGuidePainter(
        face: widget.detectedFace!,
        preset: widget.selectedPreset,
        lipColor: widget.look.lipstickColor,
      ).paint(canvas, size);

      final picture = recorder.endRecording();
      final fullGuide = await picture.toImage(image.width, image.height);

      final cropRect = _computeLipCropRect(widget.detectedFace!, fullGuide);

      if (cropRect == null) return;

      final path = await _saveCroppedImage(
        source: fullGuide,
        cropRect: cropRect,
        prefix: 'lip_guide_',
      );

      if (!mounted) return;

      setState(() {
        _lipGuideImagePath = path;
      });
    } finally {
      if (!mounted) return;

      setState(() {
        _generatingLipGuide = false;
      });
    }
  }

  Future<void> _ensureEyebrowGuideGenerated() async {
    if (_eyebrowGuideImagePath != null || _generatingEyebrowGuide) return;
    if (widget.scannedImagePath == null || widget.detectedFace == null) return;

    setState(() {
      _generatingEyebrowGuide = true;
    });

    try {
      final image = await _loadUiImageFromFile(widget.scannedImagePath!);

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      final size = Size(image.width.toDouble(), image.height.toDouble());

      canvas.drawImage(image, Offset.zero, Paint());

      EyebrowGuidePainter(
        face: widget.detectedFace!,
        preset: widget.selectedPreset,
        guideColor: const Color(0xFFFF4D97),
      ).paint(canvas, size);

      final picture = recorder.endRecording();
      final fullGuide = await picture.toImage(image.width, image.height);

      final cropRect = _computeEyebrowCropRect(widget.detectedFace!, fullGuide);
      if (cropRect == null) return;

      final path = await _saveCroppedImage(
        source: fullGuide,
        cropRect: cropRect,
        prefix: 'eyebrow_guide_',
      );

      if (!mounted) return;

      setState(() {
        _eyebrowGuideImagePath = path;
      });
    } finally {
      if (!mounted) return;

      setState(() {
        _generatingEyebrowGuide = false;
      });
    }
  }

  Future<void> _ensureBasePrepGuideGenerated() async {
    if (_basePrepGuideImagePath != null || _generatingBasePrepGuide) return;
    if (widget.scannedImagePath == null || widget.detectedFace == null) return;

    setState(() {
      _generatingBasePrepGuide = true;
    });

    try {
      final image = await _loadUiImageFromFile(widget.scannedImagePath!);

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      final size = Size(image.width.toDouble(), image.height.toDouble());

      canvas.drawImage(image, Offset.zero, Paint());

      BasePrepGuidePainter(
        face: widget.detectedFace!,
        guideColor: const Color(0xFFFF4D97),
      ).paint(canvas, size);

      final picture = recorder.endRecording();
      final fullGuide = await picture.toImage(image.width, image.height);

      final cropRect = _computeBasePrepCropRect(widget.detectedFace!, fullGuide);
      if (cropRect == null) return;

      final path = await _saveCroppedImage(
        source: fullGuide,
        cropRect: cropRect,
        prefix: 'base_prep_guide_',
      );

      if (!mounted) return;

      setState(() {
        _basePrepGuideImagePath = path;
      });
    } finally {
      if (!mounted) return;

      setState(() {
        _generatingBasePrepGuide = false;
      });
    }
  }

  Future<void> _ensureEyeshadowGuideGenerated() async {
    if (_eyeshadowGuideImagePath != null || _generatingEyeshadowGuide) return;
    if (widget.scannedImagePath == null || widget.detectedFace == null) return;

    setState(() {
      _generatingEyeshadowGuide = true;
    });

    try {
      final image = await _loadUiImageFromFile(widget.scannedImagePath!);

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      final size = Size(image.width.toDouble(), image.height.toDouble());

      canvas.drawImage(image, Offset.zero, Paint());

      final baseColor = widget.look.eyeshadowColor;

      EyeshadowGuidePainter(
        face: widget.detectedFace!,
        preset: widget.selectedPreset,
        palette: EyeshadowGuidePalette(
          lidColor: baseColor.withOpacity(0.95),
          creaseColor: baseColor.withOpacity(0.85),
          outerColor: _darken(baseColor, 0.28),
          guideColor: const Color(0xFFFF4D97),
        ),
      ).paint(canvas, size);

      final picture = recorder.endRecording();
      final fullGuide = await picture.toImage(image.width, image.height);

      final cropRect = _computeEyeCropRect(widget.detectedFace!, fullGuide);
      if (cropRect == null) return;

      final path = await _saveCroppedImage(
        source: fullGuide,
        cropRect: cropRect,
        prefix: 'eyeshadow_guide_',
      );

      if (!mounted) return;

      setState(() {
        _eyeshadowGuideImagePath = path;
      });
    } finally {
      if (!mounted) return;

      setState(() {
        _generatingEyeshadowGuide = false;
      });
    }
  }

  Future<void> _ensureEyelinerGuideGenerated() async {
    if (_eyelinerGuideImagePath != null || _generatingEyelinerGuide) return;
    if (widget.scannedImagePath == null || widget.detectedFace == null) return;

    setState(() {
      _generatingEyelinerGuide = true;
    });

    try {
      final image = await _loadUiImageFromFile(widget.scannedImagePath!);

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      final size = Size(image.width.toDouble(), image.height.toDouble());

      canvas.drawImage(image, Offset.zero, Paint());

      EyelinerGuidePainter(
        face: widget.detectedFace!,
        preset: widget.selectedPreset,
        guideColor: const Color(0xFFFF4D97),
      ).paint(canvas, size);

      final picture = recorder.endRecording();
      final fullGuide = await picture.toImage(image.width, image.height);

      final cropRect = _computeEyeCropRect(widget.detectedFace!, fullGuide);
      if (cropRect == null) return;

      final path = await _saveCroppedImage(
        source: fullGuide,
        cropRect: cropRect,
        prefix: 'eyeliner_guide_',
      );

      if (!mounted) return;

      setState(() {
        _eyelinerGuideImagePath = path;
      });
    } finally {
      if (!mounted) return;

      setState(() {
        _generatingEyelinerGuide = false;
      });
    }
  }

  Future<void> _generateAIInstructions() async {
    setState(() {
      _loadingAI = true;
      _aiSteps = [];
      _aiError = null;
      _currentPage = 0;
    });

    try {
      final steps = await _openAI.generateMakeupInstructions(
        lookName: widget.look.lookName,
        skinTone: widget.faceProfile?.skinTone.name,
        undertone: widget.faceProfile?.undertone.name,
        faceShape: widget.faceProfile?.faceShape.name,
      );

      if (!mounted) return;

      setState(() {
        _aiSteps = steps;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _pageController.jumpToPage(0);
        }
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _aiError = 'Failed to load AI instructions: $e';
        _aiSteps = [];
      });
    } finally {
      if (!mounted) return;

      setState(() {
        _loadingAI = false;
      });
    }
  }

  void _goToNextPage() {
    if (_currentPage < _aiSteps.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
    }
  }

  Widget _buildIntroSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.look.lookName,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: Color(0xFFFF4D97),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Here are your personalized AI makeup instructions for this look.',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[700],
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildWhyThisColorSection({
    required String title,
    required String description,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFFF4D97).withOpacity(0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.auto_awesome,
                size: 18,
                color: Color(0xFFFF4D97),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFFF4D97),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[800],
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAIStepsPager() {
    if (_loadingAI) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFF4D97).withOpacity(0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: const Color(0xFFFF4D97).withOpacity(0.15),
          ),
        ),
        child: Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Generating personalized AI instructions...',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[700],
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_aiError != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.red.withOpacity(0.15),
          ),
        ),
        child: Text(
          _aiError!,
          style: TextStyle(
            fontSize: 13,
            color: Colors.red[700],
            height: 1.5,
          ),
        ),
      );
    }

    if (_aiSteps.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FilledButton.icon(
            onPressed: _generateAIInstructions,
            icon: const Icon(Icons.auto_awesome),
            label: const Text('Generate AI Tips (GPT)'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFF4D97),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Text(
              'Tap "Generate AI Tips (GPT)" to create your 7-step personalized makeup tutorial.',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[700],
                height: 1.5,
              ),
            ),
          ),
        ],
      );
    }

    final currentStep = _aiSteps[_currentPage];
    final isLastPage = _currentPage == _aiSteps.length - 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'AI-Personalized Tutorial',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Color(0xFFFF4D97),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 470,
          child: PageView.builder(
            controller: _pageController,
            itemCount: _aiSteps.length,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            itemBuilder: (context, index) {
              final step = _aiSteps[index];
              final stepNumber = step['stepNumber']?.toString() ?? '';
              final title = step['title']?.toString() ?? '';
              final instruction = step['instruction']?.toString() ?? '';
              final whyThisColorSuitsYou =
                  step['whyThisColorSuitsYou']?.toString() ?? '';
              final targetArea = step['targetArea']?.toString() ?? '';
              final isFinalLookStep = step['stepNumber'] == 7;

              // Trigger guide generation based on target area
              if (targetArea == 'lips') {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _ensureLipGuideGenerated();
                });
              }
              
              if (targetArea == 'brows') {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _ensureEyebrowGuideGenerated();
                });
              }

              if (targetArea == 'full_face') {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _ensureBasePrepGuideGenerated();
                });
              }

              if (targetArea == 'eyeshadow') {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _ensureEyeshadowGuideGenerated();
                });
              }

              if (targetArea == 'eyeliner') {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _ensureEyelinerGuideGenerated();
                });
              }

              return Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF4D97).withOpacity(0.05),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFFFF4D97).withOpacity(0.15),
                  ),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Step $stepNumber • $title',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFFF4D97),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        instruction,
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.grey[800],
                          height: 1.7,
                        ),
                      ),
                      if (whyThisColorSuitsYou.trim().isNotEmpty)
                        _buildWhyThisColorSection(
                          title: isFinalLookStep
                              ? 'Why this look suits you'
                              : 'Why this color suits you',
                          description: whyThisColorSuitsYou,
                        ),
                      const SizedBox(height: 18),
                      Text(
                        'Target Area: $targetArea',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      // Add lip guide card if target area is lips
                      if (targetArea == 'lips') ...[
                        const SizedBox(height: 18),
                        if (_generatingLipGuide)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          )
                        else if (_lipGuideImagePath != null)
                          LipGuideCard(imagePath: _lipGuideImagePath!),
                      ],
                      // Add eyebrow guide card if target area is brows
                      if (targetArea == 'brows') ...[
                        const SizedBox(height: 18),
                        if (_generatingEyebrowGuide)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          )
                        else if (_eyebrowGuideImagePath != null)
                          EyebrowGuideCard(imagePath: _eyebrowGuideImagePath!),
                      ],
                      // Add base prep guide card if target area is full_face
                      if (targetArea == 'full_face') ...[
                        const SizedBox(height: 18),
                        if (_generatingBasePrepGuide)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          )
                        else if (_basePrepGuideImagePath != null)
                          BasePrepGuideCard(imagePath: _basePrepGuideImagePath!),
                      ],
                      // Add eyeshadow guide card if target area is eyeshadow
                      if (targetArea == 'eyeshadow') ...[
                        const SizedBox(height: 18),
                        if (_generatingEyeshadowGuide)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          )
                        else if (_eyeshadowGuideImagePath != null)
                          EyeshadowGuideCard(imagePath: _eyeshadowGuideImagePath!),
                      ],
                      // Add eyeliner guide card if target area is eyeliner
                      if (targetArea == 'eyeliner') ...[
                        const SizedBox(height: 18),
                        if (_generatingEyelinerGuide)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          )
                        else if (_eyelinerGuideImagePath != null)
                          EyelinerGuideCard(imagePath: _eyelinerGuideImagePath!),
                      ],
                      // Add blush/contour guide card if target area is blush_contour
                      if (targetArea == 'blush_contour') ...[
                        const SizedBox(height: 18),
                        if (widget.detectedFace != null && widget.scannedImagePath != null)
                          FutureBuilder<ui.Image>(
                            future: _loadUiImageFromFile(widget.scannedImagePath!),
                            builder: (context, snapshot) {
                              if (snapshot.hasData) {
                                return BlushContourGuideCard(
                                  face: widget.detectedFace!,
                                  preset: widget.selectedPreset,
                                  image: snapshot.data!,
                                );
                              } else if (snapshot.hasError) {
                                return Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Text(
                                    'Error loading image: ${snapshot.error}',
                                    style: const TextStyle(color: Colors.red),
                                  ),
                                );
                              }
                              return Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Center(
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            },
                          ),
                      ],
                      // Add final look guide card if target area is full_makeup
                      if (targetArea == 'full_makeup') ...[
                        const SizedBox(height: 18),
                        if (widget.detectedFace != null && widget.scannedImagePath != null)
                          FutureBuilder<ui.Image>(
                            future: _loadUiImageFromFile(widget.scannedImagePath!),
                            builder: (context, snapshot) {
                              if (snapshot.hasData) {
                                return FinalLookGuideCard(
                                  face: widget.detectedFace!,
                                  image: snapshot.data!,
                                );
                              } else if (snapshot.hasError) {
                                return Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Text(
                                    'Error loading image: ${snapshot.error}',
                                    style: const TextStyle(color: Colors.red),
                                  ),
                                );
                              }
                              return Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Center(
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            },
                          ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            'Step ${currentStep['stepNumber']} of ${_aiSteps.length}',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[700],
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_aiSteps.length, (index) {
            final isActive = index == _currentPage;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: isActive ? 22 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: isActive
                    ? const Color(0xFFFF4D97)
                    : const Color(0xFFFF4D97).withOpacity(0.25),
                borderRadius: BorderRadius.circular(20),
              ),
            );
          }),
        ),
        const SizedBox(height: 20),
        if (!isLastPage)
          FilledButton(
            onPressed: _goToNextPage,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFF4D97),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text('Next'),
          ),
        if (isLastPage) ...[
          FilledButton(
            onPressed: () {},
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFF4D97),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text('Scan Face'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () {
              Navigator.pop(context);
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFFF4D97),
              side: const BorderSide(color: Color(0xFFFF4D97)),
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text('Back'),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${widget.look.lookName} Tutorial',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildIntroSection(),
          const SizedBox(height: 24),
          _buildAIStepsPager(),
          const SizedBox(height: 16),
          Text(
            'Note: AI tips use your look name and skin analysis. No face image data is sent.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[500],
                ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}