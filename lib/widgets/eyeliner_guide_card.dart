import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../painters/eyeliner_guide_painter.dart';
import '../config/makeup_look_config.dart';  // ✅ CORRECT IMPORT

// ✅ FIXED: EyelinerGuideCard with correct parameters
class EyelinerGuideCard extends StatelessWidget {
  final Face face;
  final MakeupLookConfig config;  // ✅ FIXED: Changed from MakeupConfig to MakeupLookConfig
  final ui.Image image;

  const EyelinerGuideCard({
    super.key,
    required this.face,
    required this.config,
    required this.image,
  });

  @override
  Widget build(BuildContext context) {
    const guidePink = Color(0xFFFF4D97);
    const softBg = Color(0xFFFFF7FA);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: softBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: guidePink.withOpacity(0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'EYELINER GUIDE',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Personalized lash line and wing map',
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: SizedBox(
              width: double.infinity,
              height: 230,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  RawImage(
                    image: image,
                    fit: BoxFit.cover,
                  ),
                  CustomPaint(
                    painter: EyelinerGuidePainter(
                      face: face,
                      config: config,
                      guideColor: guidePink,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Center(
            child: Text(
              'HOW TO APPLY',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
                color: guidePink,
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Row(
            children: [
              Expanded(
                child: _StepCard(
                  number: '1',
                  title: 'Lash Line',
                  desc: 'Draw close to the upper lashes.',
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _StepCard(
                  number: '2',
                  title: 'Outer Edge',
                  desc: 'Connect the line to the outer corner.',
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _StepCard(
                  number: '3',
                  title: 'Wing',
                  desc: 'Flick outward following the guide.',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.85),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: guidePink.withOpacity(0.10)),
            ),
            child: Text(
              '💡 TIP: Keep the inner line thin, then build thickness toward the outer corner.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[800],
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  final String number;
  final String title;
  final String desc;

  const _StepCard({
    required this.number,
    required this.title,
    required this.desc,
  });

  @override
  Widget build(BuildContext context) {
    const guidePink = Color(0xFFFF4D97);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: guidePink.withOpacity(0.10)),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: guidePink,
            child: Text(
              number,
              style: const TextStyle(color: Colors.white, fontSize: 11),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          ),
          const SizedBox(height: 5),
          Text(
            desc,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10.5, color: Colors.grey[700]),
          ),
        ],
      ),
    );
  }
}