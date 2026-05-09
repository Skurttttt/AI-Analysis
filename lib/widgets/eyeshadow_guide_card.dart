import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../painters/eyeshadow_guide_painter.dart';  // ✅ IMPORT PALETTE FROM HERE
import '../config/makeup_look_config.dart';
import '../look_engine.dart';  // For LookResult if needed

// ✅ FIXED: EyeshadowGuideCard with correct parameters
class EyeshadowGuideCard extends StatelessWidget {
  final Face face;
  final MakeupLookConfig config;
  final ui.Image image;

  const EyeshadowGuideCard({
    super.key,
    required this.face,
    required this.config,
    required this.image,
  });

  @override
  Widget build(BuildContext context) {
    const guidePink = Color(0xFFFF4D97);
    const softBg = Color(0xFFFFF7FA);
    
    // ✅ FIX 3: Generate colors manually (not from config)
    // Using Soft Glam colors as default since this is a guide card
    const baseColor = Color(0xFFBFA6A0); // Soft Glam eyeshadow color
    
    final palette = EyeshadowGuidePalette(
      lidColor: baseColor.withOpacity(0.7),
      creaseColor: baseColor.withOpacity(0.5),
      outerColor: baseColor.withOpacity(0.9),
      guideColor: guidePink,
    );

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
            'EYESHADOW GUIDE',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Personalized eye shadow placement',
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
                    painter: EyeshadowGuidePainter(
                      face: face,
                      config: config,
                      palette: palette,
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
                  title: 'Lid',
                  desc: 'Apply the main shade across your eyelid.',
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _StepCard(
                  number: '2',
                  title: 'Crease',
                  desc: 'Blend softly above the lid for dimension.',
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _StepCard(
                  number: '3',
                  title: 'Depth',
                  desc: 'Add deeper shade on the outer corner.',
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
              '💡 TIP: Start with less pigment, then build intensity slowly so the blend stays smooth.',
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