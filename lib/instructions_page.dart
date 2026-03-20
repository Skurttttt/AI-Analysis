import 'package:flutter/material.dart';
import 'look_engine.dart';
import 'openai_service.dart';
import 'skin_analyzer.dart';

class InstructionsPage extends StatefulWidget {
  final LookResult look;
  final FaceProfile? faceProfile;

  const InstructionsPage({
    super.key,
    required this.look,
    this.faceProfile,
  });

  @override
  State<InstructionsPage> createState() => _InstructionsPageState();
}

class _InstructionsPageState extends State<InstructionsPage> {
  bool _loadingAI = false;
  List<Map<String, dynamic>> _aiSteps = [];
  String? _aiError;

  final _openAI = OpenAIService();

  Future<void> _generateAIInstructions() async {
    setState(() {
      _loadingAI = true;
      _aiSteps = [];
      _aiError = null;
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

  Widget _buildAIStepsSection() {
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
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Text(
          'Tap “Generate AI Tips (GPT)” to create a personalized 7-step tutorial.',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[700],
            height: 1.5,
          ),
        ),
      );
    }

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
        ..._aiSteps.map((step) {
          final stepNumber = step['stepNumber']?.toString() ?? '';
          final title = step['title']?.toString() ?? '';
          final instruction = step['instruction']?.toString() ?? '';
          final targetArea = step['targetArea']?.toString() ?? '';

          return Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFF4D97).withOpacity(0.05),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0xFFFF4D97).withOpacity(0.15),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Step $stepNumber • $title',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFFF4D97),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  instruction,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[800],
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Target Area: $targetArea',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  List<Map<String, dynamic>> _getDetailedSteps(String lookName) {
    final lookLower = lookName.toLowerCase();

    if (lookLower.contains('emo')) {
      return [
        {
          'title': '1. Prime Your Face',
          'details':
              'Apply primer to create a smooth base. Focus on the eyelids and cheekbones.',
          'icon': Icons.face,
        },
        {
          'title': '2. Foundation & Concealer',
          'details':
              'Apply foundation that matches your skin tone. Use concealer under eyes and blend.',
          'icon': Icons.brush,
        },
        {
          'title': '3. Sculpt & Contour',
          'details':
              'Apply contour to define cheekbones. Use a slightly deeper shade on temples.',
          'icon': Icons.architecture,
        },
        {
          'title': '4. Minimal Blush',
          'details':
              'Apply a tiny amount of dark blush to the apples of cheeks for definition.',
          'icon': Icons.favorite,
        },
        {
          'title': '5. Eyeshadow Base',
          'details': 'Apply eyeshadow primer to eyelids for longevity.',
          'icon': Icons.star,
        },
        {
          'title': '6. Charcoal Eyeshadow',
          'details':
              'Apply dark charcoal eyeshadow across the entire lid. Blend well.',
          'icon': Icons.remove_red_eye,
        },
        {
          'title': '7. Dramatic Eyeliner',
          'details':
              'Draw a sharp wing eyeliner. Start from inner corner and extend outward.',
          'icon': Icons.brush,
        },
        {
          'title': '8. Black Mascara',
          'details': 'Apply 2-3 coats of black mascara for dramatic lashes.',
          'icon': Icons.star,
        },
        {
          'title': '9. Dark Lip Color',
          'details':
              'Line lips and fill with deep burgundy or dark shade. Define the lip shape.',
          'icon': Icons.color_lens,
        },
        {
          'title': '10. Set Everything',
          'details': 'Use a setting spray to make the look last all day.',
          'icon': Icons.check_circle,
        },
      ];
    } else if (lookLower.contains('glam') || lookLower.contains('soft')) {
      return [
        {
          'title': '1. Hydrate & Prime',
          'details':
              'Moisturize skin and apply a hydrating primer for a dewy finish.',
          'icon': Icons.opacity,
        },
        {
          'title': '2. Luminous Foundation',
          'details':
              'Apply foundation with luminous finish that matches your skin undertone.',
          'icon': Icons.brush,
        },
        {
          'title': '3. Soft Contour',
          'details':
              'Gently contour cheekbones with a warm shade. Blend seamlessly.',
          'icon': Icons.architecture,
        },
        {
          'title': '4. Peachy Blush',
          'details':
              'Apply warm peachy blush to cheek apples for a natural flush.',
          'icon': Icons.favorite,
        },
        {
          'title': '5. Eyeshadow Primer',
          'details':
              'Apply eyeshadow primer to prevent creasing throughout the day.',
          'icon': Icons.star,
        },
        {
          'title': '6. Warm Eyeshadow',
          'details':
              'Apply warm golden/bronze eyeshadow across the lid. Blend into crease.',
          'icon': Icons.remove_red_eye,
        },
        {
          'title': '7. Subtle Eyeliner',
          'details':
              'Apply thin eyeliner close to the lash line. Extend slightly at outer corner.',
          'icon': Icons.brush,
        },
        {
          'title': '8. Volumizing Mascara',
          'details':
              'Apply mascara for defined, lifted lashes without heaviness.',
          'icon': Icons.star,
        },
        {
          'title': '9. Neutral Lip',
          'details':
              'Line lips and fill with warm mauve or nude shade. Add gloss for shine.',
          'icon': Icons.color_lens,
        },
        {
          'title': '10. Highlight & Set',
          'details':
              'Add subtle highlighter on cheekbones. Set with light translucent powder.',
          'icon': Icons.check_circle,
        },
      ];
    } else if (lookLower.contains('natural')) {
      return [
        {
          'title': '1. Skincare Routine',
          'details': 'Cleanse, tone, and moisturize for a healthy base.',
          'icon': Icons.opacity,
        },
        {
          'title': '2. Tinted Moisturizer',
          'details':
              'Use a light tinted moisturizer or BB cream for coverage.',
          'icon': Icons.brush,
        },
        {
          'title': '3. Soft Contouring',
          'details':
              'Use a cream contour stick to subtly define features.',
          'icon': Icons.architecture,
        },
        {
          'title': '4. Cream Blush',
          'details':
              'Apply cream blush to cheeks and blend with fingertips.',
          'icon': Icons.favorite,
        },
        {
          'title': '5. Light Eyeshadow',
          'details':
              'Apply neutral shimmer or matte shadow across lid for subtle definition.',
          'icon': Icons.star,
        },
        {
          'title': '6. Brown Eyeliner',
          'details':
              'Use brown eyeliner for a softer look. Tightline the upper lash line.',
          'icon': Icons.brush,
        },
        {
          'title': '7. Brown Mascara',
          'details':
              'Apply brown mascara for a natural, defined look.',
          'icon': Icons.star,
        },
        {
          'title': '8. Neutral Lip',
          'details':
              'Use a natural nude or MLBB (my lips but better) shade.',
          'icon': Icons.color_lens,
        },
        {
          'title': '9. Brow Definition',
          'details':
              'Fill in brows with a pencil that matches your natural color.',
          'icon': Icons.edit,
        },
        {
          'title': '10. Luminous Finish',
          'details':
              'Add highlighter subtly and use a hydrating setting spray.',
          'icon': Icons.check_circle,
        },
      ];
    } else if (lookLower.contains('bold') || lookLower.contains('vibrant')) {
      return [
        {
          'title': '1. Mattifying Primer',
          'details':
              'Use a mattifying primer to keep bold colors in place.',
          'icon': Icons.face,
        },
        {
          'title': '2. Full Coverage Foundation',
          'details':
              'Apply buildable foundation for an even, polished base.',
          'icon': Icons.brush,
        },
        {
          'title': '3. Defined Contour',
          'details':
              'Create sharp contour lines on cheekbones and temples.',
          'icon': Icons.architecture,
        },
        {
          'title': '4. Vibrant Blush',
          'details':
              'Apply bright blush for a bold, statement look.',
          'icon': Icons.favorite,
        },
        {
          'title': '5. Bold Eyeshadow Base',
          'details':
              'Use a quality primer to prevent bold shadows from fading.',
          'icon': Icons.star,
        },
        {
          'title': '6. Bright Eyeshadow',
          'details':
              'Layer bold, saturated eyeshadow colors on the lid.',
          'icon': Icons.remove_red_eye,
        },
        {
          'title': '7. Bold Eyeliner',
          'details':
              'Create a bold graphic eyeliner look with defined wings.',
          'icon': Icons.brush,
        },
        {
          'title': '8. Dramatic Mascara',
          'details':
              'Apply multiple coats of black mascara or use lash extensions.',
          'icon': Icons.star,
        },
        {
          'title': '9. Bold Lip Color',
          'details':
              'Apply vibrant lip color with precision. Use a liner for clean edges.',
          'icon': Icons.color_lens,
        },
        {
          'title': '10. Long-Wear Finish',
          'details':
              'Use long-wear setting spray to keep bold makeup all day.',
          'icon': Icons.check_circle,
        },
      ];
    }

    return [
      {
        'title': '1. Prep',
        'details': 'Apply primer and foundation.',
        'icon': Icons.face,
      },
      {
        'title': '2. Eyes',
        'details': 'Apply eyeshadow and eyeliner.',
        'icon': Icons.remove_red_eye,
      },
      {
        'title': '3. Cheeks',
        'details': 'Apply blush and contour.',
        'icon': Icons.favorite,
      },
      {
        'title': '4. Lips',
        'details': 'Apply lip color that complements your look.',
        'icon': Icons.color_lens,
      },
      {
        'title': '5. Set',
        'details': 'Apply setting spray for longevity.',
        'icon': Icons.check_circle,
      },
    ];
  }

  Widget _buildWhyThisLookSection() {
    final profile = widget.faceProfile;
    if (profile == null) return const SizedBox.shrink();

    String toneLabel(SkinTone tone) => switch (tone) {
          SkinTone.light => 'light',
          SkinTone.medium => 'medium',
          SkinTone.tan => 'tan',
          SkinTone.deep => 'deep',
        };

    String undertoneLabel(Undertone undertone) => switch (undertone) {
          Undertone.warm => 'warm',
          Undertone.cool => 'cool',
          Undertone.neutral => 'neutral',
        };

    String faceShapeLabel(FaceShape shape) => switch (shape) {
          FaceShape.oval => 'oval',
          FaceShape.round => 'round',
          FaceShape.square => 'square',
          FaceShape.heart => 'heart',
          FaceShape.unknown => 'balanced',
        };

    final bullets = <String>[
      'Matched to your ${undertoneLabel(profile.undertone)} undertone based on skin analysis.',
      'Balanced for your ${toneLabel(profile.skinTone)} skin tone.',
      'Placement optimized for your ${faceShapeLabel(profile.faceShape)} face shape.',
      if (profile.skinConfidence < 0.6)
        'Lighting or angle reduced accuracy. Try brighter, even lighting for better results.',
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFFF4D97).withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Why this look suits you',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 12),
          ...bullets.map(
            (text) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.check_circle,
                    size: 16,
                    color: Color(0xFFFF4D97),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      text,
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final look = widget.look;
    final detailedSteps = _getDetailedSteps(look.lookName);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${look.lookName} Tutorial',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            look.lookName,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Color(0xFFFF4D97),
            ),
          ),
          const SizedBox(height: 8),

          _buildWhyThisLookSection(),

          const SizedBox(height: 24),

          const Text(
            'Step-by-Step Instructions',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),

          ...List.generate(detailedSteps.length, (index) {
            final step = detailedSteps[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF4D97).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Icon(
                            step['icon'] as IconData,
                            color: const Color(0xFFFF4D97),
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              step['title'] as String,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              step['details'] as String,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),

          const Text(
            'AI Beauty Tips',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),

          FilledButton.icon(
            onPressed: _loadingAI ? null : _generateAIInstructions,
            icon: _loadingAI
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.auto_awesome),
            label: const Text('Generate AI Tips (GPT)'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFF4D97),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 48),
            ),
          ),

          const SizedBox(height: 16),
          _buildAIStepsSection(),

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