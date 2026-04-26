import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../painters/blush_contour_guide_painter.dart';
import '../look_engine.dart';

class BlushContourGuideCard extends StatelessWidget {
  final Face face;
  final MakeupLookPreset preset;
  final ui.Image image;

  const BlushContourGuideCard({
    super.key,
    required this.face,
    required this.preset,
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
            'BLUSH & CONTOUR GUIDE',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'Personalized cheek color and face-shaping map',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade700,
            ),
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
                    painter: BlushContourGuidePainter(
                      face: face,
                      preset: preset,
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
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
              color: Color(0xFFFF4D97),
            ),
          ),

          const SizedBox(height: 12),

          Row(
            children: const [
              Expanded(
                child: _StepCard(
                  number: '1',
                  title: 'Blush',
                  description: 'Apply softly on the cheeks.',
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _StepCard(
                  number: '2',
                  title: 'Contour',
                  description: 'Sweep under cheekbones.',
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _StepCard(
                  number: '3',
                  title: 'Blend',
                  description: 'Blend upward for lift.',
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