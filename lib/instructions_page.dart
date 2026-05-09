import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import 'look_engine.dart';
import 'config/makeup_look_config.dart' as guide_config;
import 'config/makeup_look_configs.dart';
import 'openai_service.dart';
import 'painters/base_prep_guide_painter.dart';
import 'painters/eyebrow_guide_painter.dart';
import 'painters/lip_guide_painter.dart';
import 'painters/eyeshadow_guide_painter.dart';
import 'painters/eyeliner_guide_painter.dart';

// Widgets
import 'widgets/eyeshadow_guide_card.dart';
import 'widgets/eyeliner_guide_card.dart';
import 'widgets/blush_contour_guide_card.dart';
import 'widgets/final_look_guide_card.dart';
import 'widgets/base_prep_guide_card.dart';
import 'widgets/eyebrow_guide_card.dart';
import 'widgets/lip_guide_card.dart';

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
    required this.selectedPreset,
  });

  @override
  State<InstructionsPage> createState() => _InstructionsPageState();
}

class _InstructionsPageState extends State<InstructionsPage> {
  late final guide_config.MakeupLookConfig _config;

  // AI-related state
  bool _loadingAI = false;
  String? _aiError;
  List<Map<String, dynamic>> _aiSteps = [];
  int _currentPage = 0;
  final PageController _pageController = PageController();

  // Guide generation state
  bool _generatingBasePrepGuide = false;
  bool _generatingEyebrowGuide = false;
  bool _generatingEyeshadowGuide = false;
  bool _generatingEyelinerGuide = false;
  bool _generatingLipGuide = false;
  
  String? _basePrepGuideImagePath;
  String? _eyebrowGuideImagePath;
  String? _eyeshadowGuideImagePath;
  String? _eyelinerGuideImagePath;
  String? _lipGuideImagePath;

  @override
  void initState() {
    super.initState();
    _config = MakeupLookConfigs.get(widget.selectedPreset);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _generateAIInstructions();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // ✅ FIXED: Actual OpenAI API call instead of mock data
  Future<void> _generateAIInstructions() async {
    debugPrint('🔥 AI TRIGGERED');

    setState(() {
      _loadingAI = true;
      _aiError = null;
    });

    try {
      final steps = await OpenAIService().generateMakeupInstructions(
        lookName: widget.look.lookName,
        skinTone: widget.faceProfile?.skinTone.name,
        undertone: widget.faceProfile?.undertone.name,
        faceShape: widget.faceProfile?.faceShape.name,
      );

      debugPrint('🔥 AI STEPS RECEIVED: ${steps.length}');

      setState(() {
        _aiSteps = steps;
      });
      
      // ✅ Trigger Step 1 guide after AI loads
      _ensureGuideForTargetArea('full_face');
    } catch (e) {
      debugPrint('❌ AI ERROR: $e');

      setState(() {
        _aiError = e.toString();
      });
    } finally {
      setState(() {
        _loadingAI = false;
      });
    }
  }

  void _goToNextPage() {
    if (_currentPage < 6) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  // ✅ Helper function to create guide images
  Future<String> _createGuideImage({
    required String prefix,
    required CustomPainter painter,
  }) async {
    if (widget.scannedImagePath == null) {
      throw Exception('No scanned image path found.');
    }

    final image = await _loadUiImageFromFile(widget.scannedImagePath!);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final size = Size(
      image.width.toDouble(),
      image.height.toDouble(),
    );

    canvas.drawImage(image, Offset.zero, Paint());
    painter.paint(canvas, size);

    final picture = recorder.endRecording();
    final guideImage = await picture.toImage(image.width, image.height);

    final byteData = await guideImage.toByteData(
      format: ui.ImageByteFormat.png,
    );

    if (byteData == null) {
      throw Exception('Failed to encode guide image.');
    }

    final Uint8List pngBytes = byteData.buffer.asUint8List();

    final dir = await Directory.systemTemp.createTemp(prefix);
    final file = File('${dir.path}/guide.png');

    await file.writeAsBytes(pngBytes, flush: true);

    return file.path;
  }

  // ✅ Updated guide generation functions
  Future<void> _ensureBasePrepGuideGenerated() async {
    if (_basePrepGuideImagePath != null || _generatingBasePrepGuide) return;
    if (widget.detectedFace == null || widget.scannedImagePath == null) return;

    setState(() => _generatingBasePrepGuide = true);

    try {
      final path = await _createGuideImage(
        prefix: 'base_prep_guide_',
        painter: BasePrepGuidePainter(
          face: widget.detectedFace!,
          guideColor: const Color(0xFFFF4D97),
        ),
      );

      if (!mounted) return;

      setState(() {
        _basePrepGuideImagePath = path;
      });
    } finally {
      if (mounted) {
        setState(() => _generatingBasePrepGuide = false);
      }
    }
  }

  Future<void> _ensureEyebrowGuideGenerated() async {
    if (_eyebrowGuideImagePath != null || _generatingEyebrowGuide) return;
    if (widget.detectedFace == null || widget.scannedImagePath == null) return;

    setState(() => _generatingEyebrowGuide = true);

    try {
      final path = await _createGuideImage(
        prefix: 'eyebrow_guide_',
        painter: EyebrowGuidePainter(
          face: widget.detectedFace!,
          preset: widget.selectedPreset,
          guideColor: const Color(0xFFFF4D97),
        ),
      );

      if (!mounted) return;

      setState(() {
        _eyebrowGuideImagePath = path;
      });
    } finally {
      if (mounted) {
        setState(() => _generatingEyebrowGuide = false);
      }
    }
  }

  Future<void> _ensureLipGuideGenerated() async {
    if (_lipGuideImagePath != null || _generatingLipGuide) return;
    if (widget.detectedFace == null || widget.scannedImagePath == null) return;

    setState(() => _generatingLipGuide = true);

    try {
      final path = await _createGuideImage(
        prefix: 'lip_guide_',
        painter: LipGuidePainter(
          face: widget.detectedFace!,
          preset: widget.selectedPreset,
          lipColor: widget.look.lipstickColor,
        ),
      );

      if (!mounted) return;

      setState(() {
        _lipGuideImagePath = path;
      });
    } finally {
      if (mounted) {
        setState(() => _generatingLipGuide = false);
      }
    }
  }

  // ✅ FIXED: Real painter generation for eyeshadow guide
  Future<void> _ensureEyeshadowGuideGenerated() async {
    if (_eyeshadowGuideImagePath != null || _generatingEyeshadowGuide) return;
    if (widget.detectedFace == null || widget.scannedImagePath == null) return;

    setState(() => _generatingEyeshadowGuide = true);

    try {
      final path = await _createGuideImage(
        prefix: 'eyeshadow_guide_',
        painter: EyeshadowGuidePainter(
          face: widget.detectedFace!,
          config: _config,
          palette: EyeshadowGuidePalette(
            lidColor: widget.look.eyeshadowColor.withOpacity(0.95),
            creaseColor: widget.look.eyeshadowColor.withOpacity(0.75),
            outerColor: widget.look.eyeshadowColor.withOpacity(1.0),
            guideColor: const Color(0xFFFF4D97),
          ),
        ),
      );

      if (!mounted) return;

      setState(() => _eyeshadowGuideImagePath = path);
    } finally {
      if (mounted) {
        setState(() => _generatingEyeshadowGuide = false);
      }
    }
  }

  // ✅ FIXED: Real painter generation for eyeliner guide
  Future<void> _ensureEyelinerGuideGenerated() async {
    if (_eyelinerGuideImagePath != null || _generatingEyelinerGuide) return;
    if (widget.detectedFace == null || widget.scannedImagePath == null) return;

    setState(() => _generatingEyelinerGuide = true);

    try {
      final path = await _createGuideImage(
        prefix: 'eyeliner_guide_',
        painter: EyelinerGuidePainter(
          face: widget.detectedFace!,
          config: _config,
          guideColor: const Color(0xFFFF4D97),
        ),
      );

      if (!mounted) return;

      setState(() => _eyelinerGuideImagePath = path);
    } finally {
      if (mounted) {
        setState(() => _generatingEyelinerGuide = false);
      }
    }
  }

  // ✅ Helper: Get AI step for fixed step
  Map<String, dynamic> _getAiStepForFixedStep(int stepNumber, String targetArea) {
    try {
      return _aiSteps.firstWhere(
        (s) =>
            s['stepNumber'] == stepNumber ||
            s['stepNumber']?.toString() == stepNumber.toString() ||
            s['targetArea'] == targetArea,
      );
    } catch (_) {
      return {};
    }
  }

  // ✅ Helper: Clean why text
  String _cleanWhyText(String raw, String targetArea) {
    final text = raw.trim();

    if (text.isEmpty || text.contains('Color(') || text.contains('colorSpace')) {
      if (targetArea == 'blush_contour') {
        return 'This blush and contour placement helps add warmth, shape, and soft dimension to your face.';
      }

      if (targetArea == 'eyeshadow') {
        return 'This eyeshadow placement helps add soft depth while keeping the look balanced and wearable.';
      }

      if (targetArea == 'eyeliner') {
        return 'This eyeliner shape helps define your eyes while matching the overall style of the look.';
      }

      if (targetArea == 'lips') {
        return 'This lip color helps balance the look and complements your natural skin tone.';
      }

      if (targetArea == 'full_makeup') {
        return 'This final look brings all the colors and placements together for a balanced finish.';
      }

      return '';
    }

    return text;
  }

  // ✅ Helper: Ensure guide for target area
  void _ensureGuideForTargetArea(String targetArea) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (targetArea == 'full_face') _ensureBasePrepGuideGenerated();
      if (targetArea == 'brows') _ensureEyebrowGuideGenerated();
      if (targetArea == 'eyeshadow') _ensureEyeshadowGuideGenerated();
      if (targetArea == 'eyeliner') _ensureEyelinerGuideGenerated();
      if (targetArea == 'lips') _ensureLipGuideGenerated();
    });
  }

  Future<ui.Image> _loadUiImageFromFile(String path) async {
    final bytes = await File(path).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  Widget _buildWhyThisColorSection({
    required String title,
    required String description,
  }) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFF4D97).withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.color_lens, size: 16, color: const Color(0xFFFF4D97)),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFFF4D97),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[700],
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAIStepsPager() {
    const fixedStepOrder = [
      {
        'stepNumber': 1,
        'title': 'Base Prep',
        'targetArea': 'full_face',
        'fallbackInstruction':
            'Prep your skin by priming the T-zone, hydrating the cheeks, and brightening the under-eye area.',
      },
      {
        'stepNumber': 2,
        'title': 'Eyebrows',
        'targetArea': 'brows',
        'fallbackInstruction':
            'Define your brows softly by following your natural brow shape.',
      },
      {
        'stepNumber': 3,
        'title': 'Eyeshadow',
        'targetArea': 'eyeshadow',
        'fallbackInstruction':
            'Apply the main shade on the lid, blend the crease, then add depth to the outer corner.',
      },
      {
        'stepNumber': 4,
        'title': 'Eyeliner',
        'targetArea': 'eyeliner',
        'fallbackInstruction':
            'Draw close to the upper lash line, connect the outer edge, then flick outward for the wing.',
      },
      {
        'stepNumber': 5,
        'title': 'Blush / Contour',
        'targetArea': 'blush_contour',
        'fallbackInstruction':
            'Apply blush on the upper cheek area, then contour lightly below the cheekbone for shape.',
      },
      {
        'stepNumber': 6,
        'title': 'Lips',
        'targetArea': 'lips',
        'fallbackInstruction':
            'Apply your lip color from the center outward and blend evenly for a polished finish.',
      },
      {
        'stepNumber': 7,
        'title': 'Final Look',
        'targetArea': 'full_makeup',
        'fallbackInstruction':
            'Set your makeup with a light spray using X and T motion, then check the final blend.',
      },
    ];

    // Replace with loading text when generating AI steps
    if (_loadingAI && _aiSteps.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Generating your personalized tutorial...',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (_aiError != null) {
      return Text(
        _aiError!,
        style: const TextStyle(color: Colors.red),
      );
    }

    if (_aiSteps.isEmpty) {
      return const SizedBox.shrink();
    }

    final isLastPage = _currentPage == 6;

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
            itemCount: 7,
            onPageChanged: (index) {
              setState(() => _currentPage = index);
              
              // ✅ Trigger guide generation when page changes
              final fixedStep = fixedStepOrder[index];
              final targetArea = fixedStep['targetArea'].toString();
              _ensureGuideForTargetArea(targetArea);
            },
            itemBuilder: (context, index) {
              final fixedStep = fixedStepOrder[index];

              final stepNumber = fixedStep['stepNumber'].toString();
              final title = fixedStep['title'].toString();
              final targetArea = fixedStep['targetArea'].toString();

              // ✅ Replace AI step matching with helper
              final aiStep = _getAiStepForFixedStep(index + 1, targetArea);

              final instruction =
                  aiStep['instruction']?.toString() ??
                  fixedStep['fallbackInstruction'].toString();

              // ✅ Replace why text with cleaned version
              final whyThisColorSuitsYou = _cleanWhyText(
                aiStep['whyThisColorSuitsYou']?.toString() ?? '',
                targetArea,
              );

              final isFinalLookStep = targetArea == 'full_makeup';

              // ✅ Replace guide trigger block
              _ensureGuideForTargetArea(targetArea);

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

                      if (targetArea == 'full_face') ...[
                        if (_generatingBasePrepGuide)
                          const Center(child: CircularProgressIndicator())
                        else if (_basePrepGuideImagePath != null)
                          BasePrepGuideCard(imagePath: _basePrepGuideImagePath!),
                      ],

                      if (targetArea == 'brows') ...[
                        if (_generatingEyebrowGuide)
                          const Center(child: CircularProgressIndicator())
                        else if (_eyebrowGuideImagePath != null)
                          EyebrowGuideCard(imagePath: _eyebrowGuideImagePath!),
                      ],

                      if (targetArea == 'eyeshadow') ...[
                        if (_generatingEyeshadowGuide)
                          const Center(child: CircularProgressIndicator())
                        else if (_eyeshadowGuideImagePath != null)
                          FutureBuilder<ui.Image>(
                            future: _loadUiImageFromFile(_eyeshadowGuideImagePath!),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData) {
                                return const Center(child: CircularProgressIndicator());
                              }

                              return EyeshadowGuideCard(
                                face: widget.detectedFace!,
                                config: _config,
                                image: snapshot.data!,
                              );
                            },
                          ),
                      ],

                      if (targetArea == 'eyeliner') ...[
                        if (_generatingEyelinerGuide)
                          const Center(child: CircularProgressIndicator())
                        else if (_eyelinerGuideImagePath != null)
                          FutureBuilder<ui.Image>(
                            future: _loadUiImageFromFile(_eyelinerGuideImagePath!),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData) {
                                return const Center(child: CircularProgressIndicator());
                              }

                              return EyelinerGuideCard(
                                face: widget.detectedFace!,
                                config: _config,
                                image: snapshot.data!,
                              );
                            },
                          ),
                      ],

                      if (targetArea == 'blush_contour') ...[
                        if (widget.detectedFace != null &&
                            widget.scannedImagePath != null)
                          FutureBuilder<ui.Image>(
                            future: _loadUiImageFromFile(widget.scannedImagePath!),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData) {
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              }

                              return BlushContourGuideCard(
                                face: widget.detectedFace!,
                                config: _config,
                                image: snapshot.data!,
                              );
                            },
                          ),
                      ],

                      if (targetArea == 'lips') ...[
                        if (_generatingLipGuide)
                          const Center(child: CircularProgressIndicator())
                        else if (_lipGuideImagePath != null)
                          LipGuideCard(imagePath: _lipGuideImagePath!),
                      ],

                      if (targetArea == 'full_makeup') ...[
                        if (widget.detectedFace != null &&
                            widget.scannedImagePath != null)
                          FutureBuilder<ui.Image>(
                            future: _loadUiImageFromFile(widget.scannedImagePath!),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData) {
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              }

                              return FinalLookGuideCard(
                                face: widget.detectedFace!,
                                image: snapshot.data!,
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
            'Step ${_currentPage + 1} of 7',
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
          children: List.generate(7, (index) {
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
            ),
            child: const Text('Next'),
          ),

        if (isLastPage) ...[
          FilledButton(
            onPressed: () => Navigator.pop(context),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFF4D97),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 52),
            ),
            child: const Text('Scan Face'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFFF4D97),
              side: const BorderSide(color: Color(0xFFFF4D97)),
              minimumSize: const Size(double.infinity, 52),
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
        title: Text(widget.look.lookName),
        backgroundColor: const Color(0xFFFF4D97),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAIStepsPager(),
          ],
        ),
      ),
    );
  }
}