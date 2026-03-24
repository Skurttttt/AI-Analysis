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
  final PageController _pageController = PageController();

  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
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
              'Tap “Generate AI Tips (GPT)” to create your 7-step personalized makeup tutorial.',
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