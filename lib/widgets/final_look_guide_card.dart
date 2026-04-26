import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../painters/final_look_guide_painter.dart';

class FinalLookGuideCard extends StatelessWidget {
  final Face face;
  final ui.Image image;

  const FinalLookGuideCard({
    super.key,
    required this.face,
    required this.image,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0F4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.pink.shade100),
      ),
      child: Column(
        children: [
          const Text(
            'FINAL LOOK',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Set your makeup using X and T motion',
            style: TextStyle(fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),

          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              width: double.infinity,
              height: 360,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  RawImage(
                    image: image,
                    fit: BoxFit.cover,
                  ),
                  CustomPaint(
                    painter: FinalLookGuidePainter(
                      face: face,
                      imageSize: Size(
                        image.width.toDouble(),
                        image.height.toDouble(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),
          const Text(
            'HOW TO APPLY',
            style: TextStyle(
              color: Color(0xFFFF4D97),
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 12),

          Row(
            children: const [
              Expanded(
                child: _StepCard(
                  number: '1',
                  title: 'Setting Spray',
                  description:
                      'Hold 8–10 inches away. Spray in X then T motion.',
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _StepCard(
                  number: '2',
                  title: 'Let it Set',
                  description: 'Close your eyes and let it air dry naturally.',
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _StepCard(
                  number: '3',
                  title: 'Final Check',
                  description: 'Blend any harsh lines for a flawless finish.',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  final String number;
  final String title;
  final String description;

  const _StepCard({
    required this.number,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: const Color(0xFFFF4D97),
            child: Text(
              number,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey.shade600,
              height: 1.3,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}