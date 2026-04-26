import 'dart:io';
import 'package:flutter/material.dart';

class LipGuideCard extends StatelessWidget {
  final String imagePath;

  const LipGuideCard({
    super.key,
    required this.imagePath,
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'LIP GUIDE',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Personalized application map',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              _PaletteDot(color: const Color(0xFFE88AA4)),
              const SizedBox(width: 8),
              _PaletteDot(color: const Color(0xFFFF9BB4)),
              const SizedBox(width: 8),
              _PaletteDot(color: const Color(0xFFB85C7A)),
              const SizedBox(width: 10),
              Text(
                'Outline • Fill • Blend',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Container(
              color: Colors.white,
              child: Image.file(
                File(imagePath),
                width: double.infinity,
                fit: BoxFit.cover,
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
                  title: 'Outline',
                  desc: 'Trace the shape first, especially the cupid’s bow.',
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _StepCard(
                  number: '2',
                  title: 'Fill',
                  desc: 'Apply color in the center and spread evenly outward.',
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _StepCard(
                  number: '3',
                  title: 'Blend',
                  desc: 'Soften corners and smooth the edges for balance.',
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
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '💡',
                  style: TextStyle(fontSize: 15),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'For fuller-looking lips, keep the strongest color in the center and avoid making the corners too dark.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[800],
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PaletteDot extends StatelessWidget {
  final Color color;

  const _PaletteDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 4,
            offset: const Offset(0, 1),
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
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 12,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            desc,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10.5,
              color: Colors.grey[700],
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}