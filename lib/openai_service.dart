import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class OpenAIService {
  final String apiKey = dotenv.env['OPENAI_API_KEY'] ?? '';

  Future<List<Map<String, dynamic>>> generateMakeupInstructions({
    required String lookName,
    String? skinTone,
    String? undertone,
    String? faceShape,
  }) async {
    // 🔍 DEBUG: Add debug prints at the very top
    debugPrint('API KEY EMPTY: ${apiKey.isEmpty}');
    debugPrint('API KEY PREFIX: ${apiKey.isNotEmpty ? apiKey.substring(0, 5) : "empty"}');
    debugPrint('Calling OpenAI now...');

    if (apiKey.isEmpty) {
      debugPrint('OPENAI_API_KEY is missing. Using fallback steps.');
      return _fallbackSteps(
        lookName: lookName,
        skinTone: skinTone,
        undertone: undertone,
        faceShape: faceShape,
      );
    }

    final prompt = '''
You are a professional makeup artist AI assistant.

Your task is to generate a personalized, beginner-friendly, step-by-step makeup tutorial.

Return ONLY valid JSON.
Do NOT include markdown.
Do NOT include explanations outside JSON.

FORMAT:
{
  "steps": [
    {
      "stepNumber": 1,
      "title": "...",
      "instruction": "...",
      "targetArea": "..."
    }
  ]
}

RULES:
- EXACTLY 7 steps ONLY
- Follow EXACT order:
  1. Base Prep → full_face
  2. Eyebrows → brows
  3. Eyeshadow → eyeshadow
  4. Eyeliner → eyeliner
  5. Blush / Contour → blush_contour
  6. Lips → lips
  7. Final Look → full_makeup

PERSONALIZATION:
- Tailor each instruction based on:
  - lookName
  - skinTone
  - undertone
  - faceShape
- Adjust color suggestions based on undertone
- Adjust placement based on face shape
- Adjust intensity based on look style
- Vary wording naturally

STYLE:
- Each instruction must be 1–2 sentences only
- Use simple, beginner-friendly language
- Be specific
- Avoid brand names

CONTEXT:
lookName: $lookName
skinTone: ${skinTone ?? "unknown"}
undertone: ${undertone ?? "unknown"}
faceShape: ${faceShape ?? "unknown"}

FINAL RULE:
Return ONLY JSON. No extra text.
''';

    final url = Uri.parse('https://api.openai.com/v1/chat/completions');

    final body = {
      "model": "gpt-4o-mini",
      "messages": [
        {
          "role": "system",
          "content":
              "You are a makeup tutorial generator that returns only valid JSON."
        },
        {"role": "user", "content": prompt}
      ],
      "temperature": 0.3,
      "max_tokens": 700,
      "response_format": {"type": "json_object"},
    };

    try {
      final res = await http
          .post(
            url,
            headers: {
              'Authorization': 'Bearer $apiKey',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 30));

      debugPrint("===== OPENAI STATUS ===== ${res.statusCode}");
      debugPrint("===== FULL RESPONSE BODY =====");
      debugPrint(res.body);

      if (res.statusCode < 200 || res.statusCode >= 300) {
        debugPrint('OpenAI request failed. Using fallback steps.');
        return _fallbackSteps(
          lookName: lookName,
          skinTone: skinTone,
          undertone: undertone,
          faceShape: faceShape,
        );
      }

      final decoded = jsonDecode(res.body);
      final content = decoded["choices"]?[0]?["message"]?["content"];

      debugPrint("===== RAW AI CONTENT =====");
      debugPrint(content?.toString() ?? 'null');

      if (content == null || content is! String || content.trim().isEmpty) {
        debugPrint('AI content is empty. Using fallback steps.');
        return _fallbackSteps(
          lookName: lookName,
          skinTone: skinTone,
          undertone: undertone,
          faceShape: faceShape,
        );
      }

      final cleaned = _cleanJsonString(content);

      debugPrint("===== CLEANED JSON =====");
      debugPrint(cleaned);

      if (cleaned.isEmpty) {
        debugPrint('Cleaned JSON is empty. Using fallback steps.');
        return _fallbackSteps(
          lookName: lookName,
          skinTone: skinTone,
          undertone: undertone,
          faceShape: faceShape,
        );
      }

      final parsed = jsonDecode(cleaned);

      if (parsed is! Map<String, dynamic>) {
        debugPrint('Parsed JSON is not a map. Using fallback steps.');
        return _fallbackSteps(
          lookName: lookName,
          skinTone: skinTone,
          undertone: undertone,
          faceShape: faceShape,
        );
      }

      final rawSteps = parsed['steps'];
      if (rawSteps is! List) {
        debugPrint('"steps" is missing or not a list. Using fallback steps.');
        return _fallbackSteps(
          lookName: lookName,
          skinTone: skinTone,
          undertone: undertone,
          faceShape: faceShape,
        );
      }

      final steps = _normalizeSteps(
        rawSteps: rawSteps,
        lookName: lookName,
        skinTone: skinTone,
        undertone: undertone,
        faceShape: faceShape,
      );

      final hasAnyMeaningfulInstruction =
          steps.any((step) => (step['instruction']?.toString().trim().isNotEmpty ?? false));

      if (!hasAnyMeaningfulInstruction) {
        debugPrint('No meaningful instructions found. Using fallback steps.');
        return _fallbackSteps(
          lookName: lookName,
          skinTone: skinTone,
          undertone: undertone,
          faceShape: faceShape,
        );
      }

      debugPrint("===== FINAL STEPS =====");
      debugPrint(jsonEncode({"steps": steps}));

      return steps;
    } catch (e, stackTrace) {
      debugPrint('OpenAI error: $e');
      debugPrint(stackTrace.toString());

      return _fallbackSteps(
        lookName: lookName,
        skinTone: skinTone,
        undertone: undertone,
        faceShape: faceShape,
      );
    }
  }

  List<Map<String, dynamic>> _normalizeSteps({
    required List rawSteps,
    required String lookName,
    String? skinTone,
    String? undertone,
    String? faceShape,
  }) {
    const expectedTitles = [
      'Base Prep',
      'Eyebrows',
      'Eyeshadow',
      'Eyeliner',
      'Blush / Contour',
      'Lips',
      'Final Look',
    ];

    const expectedTargetAreas = [
      'full_face',
      'brows',
      'eyeshadow',
      'eyeliner',
      'blush_contour',
      'lips',
      'full_makeup',
    ];

    final fallback = _fallbackSteps(
      lookName: lookName,
      skinTone: skinTone,
      undertone: undertone,
      faceShape: faceShape,
    );

    final steps = <Map<String, dynamic>>[];

    for (int i = 0; i < 7; i++) {
      final dynamic item = i < rawSteps.length ? rawSteps[i] : null;

      String instruction = '';
      if (item is Map) {
        instruction = item['instruction']?.toString().trim() ?? '';
      }

      if (instruction.isEmpty) {
        instruction = fallback[i]['instruction']!.toString();
      }

      steps.add({
        'stepNumber': i + 1,
        'title': expectedTitles[i],
        'instruction': instruction,
        'targetArea': expectedTargetAreas[i],
      });
    }

    return steps;
  }

  String _cleanJsonString(String input) {
    var cleaned = input.trim();

    cleaned = cleaned.replaceAll(RegExp(r'^```json\s*', multiLine: true), '');
    cleaned = cleaned.replaceAll(RegExp(r'^```\s*', multiLine: true), '');
    cleaned = cleaned.replaceAll(RegExp(r'\s*```$', multiLine: true), '');
    cleaned = cleaned.trim();

    final firstBrace = cleaned.indexOf('{');
    final lastBrace = cleaned.lastIndexOf('}');

    if (firstBrace == -1 || lastBrace == -1 || lastBrace <= firstBrace) {
      return '';
    }

    return cleaned.substring(firstBrace, lastBrace + 1).trim();
  }

  List<Map<String, dynamic>> _fallbackSteps({
    required String lookName,
    String? skinTone,
    String? undertone,
    String? faceShape,
  }) {
    final look = lookName.toLowerCase();
    final tone = (skinTone ?? 'unknown').toLowerCase();
    final under = (undertone ?? 'neutral').toLowerCase();
    final shape = (faceShape ?? 'balanced').toLowerCase();

    final isSoft = look.contains('soft') || look.contains('glam');
    final isBold = look.contains('bold') ||
        look.contains('editorial') ||
        look.contains('emo');
    final isNatural = look.contains('natural') || look.contains('everyday');

    final intensityWord = isBold
        ? 'a more defined'
        : isNatural
            ? 'a very soft'
            : isSoft
                ? 'a soft-glam'
                : 'a balanced';

    final baseTone = switch (under) {
      'warm' => 'golden or peach-toned',
      'cool' => 'rose, taupe, or cool-toned',
      'neutral' => 'soft neutral beige or mauve',
      _ => 'soft neutral',
    };

    final lipTone = switch (under) {
      'warm' => 'peachy nude or warm rose',
      'cool' => 'pink nude or rosy mauve',
      'neutral' => 'neutral nude or muted pink',
      _ => 'soft nude',
    };

    final browTone = switch (tone) {
      'light' => 'light brown',
      'medium' => 'medium brown',
      'tan' => 'deep brown',
      'deep' => 'rich deep brown',
      _ => 'natural brown',
    };

    final blushPlacement = switch (shape) {
      'round' => 'Place blush slightly higher and blend upward toward the temples to create a lifted effect.',
      'square' => 'Blend blush softly on the outer cheeks and sweep it upward to soften strong angles.',
      'heart' => 'Keep blush slightly lower on the cheeks and blend outward for balance.',
      'oval' => 'Place blush on the apples of the cheeks and blend slightly upward for a naturally balanced finish.',
      _ => 'Place blush on the cheeks and blend outward and upward for a soft finish.',
    };

    final eyeshadowPlacement = switch (shape) {
      'round' => 'Blend the outer corner slightly upward to elongate the eyes.',
      'square' => 'Keep the blending soft and rounded to balance sharper features.',
      'heart' => 'Focus a bit more color on the outer lid to add balance.',
      'oval' => 'Blend evenly across the lid and slightly into the crease for a balanced look.',
      _ => 'Blend softly across the lid and crease.',
    };

    return [
      {
        'stepNumber': 1,
        'title': 'Base Prep',
        'instruction':
            'Prep your full face with moisturizer and a light base for $intensityWord finish. Keep the layers thin and even so the skin looks smooth instead of heavy.',
        'targetArea': 'full_face',
      },
      {
        'stepNumber': 2,
        'title': 'Eyebrows',
        'instruction':
            'Fill your brows with a $browTone shade using small hair-like strokes. Brush through the front lightly so the brows stay soft and natural-looking.',
        'targetArea': 'brows',
      },
      {
        'stepNumber': 3,
        'title': 'Eyeshadow',
        'instruction':
            'Apply a $baseTone eyeshadow across the lids, then add a slightly deeper shade to the crease for dimension. $eyeshadowPlacement',
        'targetArea': 'eyeshadow',
      },
      {
        'stepNumber': 4,
        'title': 'Eyeliner',
        'instruction':
            isBold
                ? 'Trace a more defined eyeliner close to the lash line and extend the outer edge slightly for extra shape. Keep both sides thin first, then build slowly.'
                : 'Trace a thin eyeliner close to the lash line to softly define the eyes. Keep the outer edge small and lifted for a clean beginner-friendly finish.',
        'targetArea': 'eyeliner',
      },
      {
        'stepNumber': 5,
        'title': 'Blush / Contour',
        'instruction':
            'Use a $baseTone blush or contour tone very lightly so it complements your undertone. $blushPlacement',
        'targetArea': 'blush_contour',
      },
      {
        'stepNumber': 6,
        'title': 'Lips',
        'instruction':
            'Apply a $lipTone lip color, starting at the center and blending outward for better control. Add one more light layer if you want a more polished look.',
        'targetArea': 'lips',
      },
      {
        'stepNumber': 7,
        'title': 'Final Look',
        'instruction':
            'Check the full makeup in good lighting and soften any harsh edges with a clean brush or sponge. Finish with powder or setting spray so the whole look stays neat and blended.',
        'targetArea': 'full_makeup',
      },
    ];
  }
}