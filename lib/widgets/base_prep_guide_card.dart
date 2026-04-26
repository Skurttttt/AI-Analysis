import 'dart:io';
import 'package:flutter/material.dart';

class BasePrepGuideCard extends StatelessWidget {
  final String imagePath;

  const BasePrepGuideCard({
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
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'BASE PREP GUIDE',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Personalized face prep map',
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Image.file(
              File(imagePath),
              width: double.infinity,
              height: 260,
              fit: BoxFit.cover,
              alignment: Alignment.center,
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
                  title: 'Prime',
                  desc: 'Apply primer on the T-zone first.',
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _StepCard(
                  number: '2',
                  title: 'Hydrate',
                  desc: 'Blend outward on the cheeks.',
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _StepCard(
                  number: '3',
                  title: 'Brighten',
                  desc: 'Tap gently under the eyes.',
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
              '💡 TIP: Keep your base thin first. Add more only where you need coverage.',
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