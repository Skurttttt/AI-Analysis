import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class OpenAIService {
  OpenAIService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  final String apiKey = dotenv.env['OPENAI_API_KEY'] ?? '';

  static const String _model = 'gpt-4o-mini';
  static const Duration _timeout = Duration(seconds: 30);

  static const List<String> _expectedTitles = [
    'Base Prep',
    'Eyebrows',
    'Eyeshadow',
    'Eyeliner',
    'Blush / Contour',
    'Lips',
    'Final Look',
  ];

  static const List<String> _expectedTargetAreas = [
    'full_face',
    'brows',
    'eyeshadow',
    'eyeliner',
    'blush_contour',
    'lips',
    'full_makeup',
  ];

  Future<List<Map<String, dynamic>>> generateMakeupInstructions({
    required String lookName,
    String? skinTone,
    String? undertone,
    String? faceShape,
  }) async {
    _logRequestStart();

    final fallback = _fallbackSteps(
      lookName: lookName,
      skinTone: skinTone,
      undertone: undertone,
      faceShape: faceShape,
    );

    if (apiKey.isEmpty) {
      debugPrint('OPENAI_API_KEY is missing. Using fallback steps.');
      return fallback;
    }

    try {
      final response = await _sendRequest(
        lookName: lookName,
        skinTone: skinTone,
        undertone: undertone,
        faceShape: faceShape,
      );

      debugPrint("===== OPENAI STATUS ===== ${response.statusCode}");
      debugPrint("===== FULL RESPONSE BODY =====");
      debugPrint(response.body);

      if (!_isSuccessfulStatus(response.statusCode)) {
        debugPrint('OpenAI request failed. Using fallback steps.');
        return fallback;
      }

      final steps = _parseAndNormalizeSteps(
        responseBody: response.body,
        fallback: fallback,
      );

      if (!_hasMeaningfulInstructions(steps)) {
        debugPrint('No meaningful instructions found. Using fallback steps.');
        return fallback;
      }

      debugPrint("===== FINAL STEPS =====");
      debugPrint(jsonEncode({"steps": steps}));

      return steps;
    } catch (e, stackTrace) {
      debugPrint('OpenAI error: $e');
      debugPrint(stackTrace.toString());
      return fallback;
    }
  }

  Future<http.Response> _sendRequest({
    required String lookName,
    String? skinTone,
    String? undertone,
    String? faceShape,
  }) {
    final prompt = _buildPrompt(
      lookName: lookName,
      skinTone: skinTone,
      undertone: undertone,
      faceShape: faceShape,
    );

    final body = {
      "model": _model,
      "messages": [
        {
          "role": "system",
          "content":
              "You are a makeup tutorial generator that returns only valid JSON."
        },
        {"role": "user", "content": prompt}
      ],
      "temperature": 0.2,
      "max_tokens": 1200,
      "response_format": {"type": "json_object"},
    };

    return _client
        .post(
          Uri.parse('https://api.openai.com/v1/chat/completions'),
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(body),
        )
        .timeout(_timeout);
  }

  String _buildPrompt({
    required String lookName,
    String? skinTone,
    String? undertone,
    String? faceShape,
  }) {
    final lookRules = _lookRulesForPrompt(lookName);

    return '''
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
      "whyThisColorSuitsYou": "...",
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

VERY IMPORTANT PRIORITY:
1. FOLLOW THE SELECTED LOOK FIRST
2. Then refine shades using undertone
3. Then refine placement using face shape
4. Never let undertone override the look style

STRICT LOOK RULES:
$lookRules

NON-NEGOTIABLE:
- If lookName is Emo, DO NOT suggest peach blush, coral blush, bright cheerful blush, or soft glam cheeks
- If lookName is Emo, blush must stay minimal, muted, neutral, or contour-like
- If lookName is Soft Glam, peachy diffused blush is allowed
- If lookName is Doll / K-Beauty, soft rosy youthful blush is allowed
- If lookName is Bronzed Goddess, warm bronzed cheek color / contour is allowed
- If lookName is Bold Editorial, blush can be structured, angular, and high-contrast

CRITICAL:
- Every step MUST include:
  - stepNumber
  - title
  - instruction
  - whyThisColorSuitsYou
  - targetArea

- DO NOT skip "whyThisColorSuitsYou"
- DO NOT leave any field empty
- If any field is missing, the response is INVALID

PERSONALIZATION:
- Tailor each instruction based on:
  - lookName
  - skinTone
  - undertone
  - faceShape
- Undertone should refine the shade family only within the chosen look
- Face shape should affect placement only
- Keep beginner-friendly wording

WHY THIS SUITS YOU:
- Steps 1–6:
  Explain why the chosen color, tone, or placement works for the user
- Step 7 (Final Look):
  Explain why the ENTIRE LOOK suits the user overall
  - Mention harmony of features
  - Balance with skin tone and undertone
  - Suitability to face shape
  - Overall vibe
- Use the same field name: "whyThisColorSuitsYou"
- Each explanation must be 1 sentence only
- Avoid generic phrases like "because it looks nice"

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
  }

  String _lookRulesForPrompt(String lookName) {
    final look = lookName.toLowerCase();

    if (look.contains('emo')) {
      return '''
- Overall vibe: edgy, moody, high-contrast, expressive
- Eyeshadow: smoky charcoal, plum, blackened brown, taupe-smoke, muted cool depth
- Eyeliner: stronger, sharper, more dramatic
- Blush / Contour: minimal, muted, neutral, subtle contour only
- Lips: deeper berry, plum, muted wine, dark rose, grunge-friendly tones
- Avoid cheerful, sunny, peachy-soft-glam wording
''';
    }

    if (look.contains('soft') || look.contains('glam')) {
      return '''
- Overall vibe: polished, flattering, soft definition
- Eyeshadow: soft brown, champagne, taupe, bronze-beige
- Eyeliner: subtle and lifted
- Blush / Contour: diffused peach, rose-peach, soft sculpting
- Lips: nude rose, peachy nude, balanced glam lip
''';
    }

    if (look.contains('doll') || look.contains('k-beauty')) {
      return '''
- Overall vibe: youthful, fresh, airy, soft
- Eyeshadow: light wash, soft pink-beige, muted shimmer, gentle depth
- Eyeliner: thin and delicate
- Blush / Contour: rosy, soft, lifted, youthful placement
- Lips: soft pink, gradient lip, rosy nude, glossy or fresh-looking tones
''';
    }

    if (look.contains('bronzed') || look.contains('goddess')) {
      return '''
- Overall vibe: warm, sun-kissed, sculpted, glowing
- Eyeshadow: gold, bronze, copper, caramel, warm shimmer
- Eyeliner: subtle, clean definition
- Blush / Contour: bronzed cheeks, warm contour, sun-kissed sculpting
- Lips: terracotta nude, warm rose, bronzed nude
''';
    }

    if (look.contains('bold') || look.contains('editorial')) {
      return '''
- Overall vibe: artistic, structured, intentional, high-impact
- Eyeshadow: unconventional, stronger color, intentional shape
- Eyeliner: graphic or dramatic
- Blush / Contour: angular, stronger contrast, editorial placement
- Lips: statement lip, deeper or more fashion-forward tone
''';
    }

    return '''
- Follow the selected look name closely
- Keep shades consistent with the look before undertone refinement
- Do not default to peach blush unless the chosen look supports it
''';
  }

  List<Map<String, dynamic>> _parseAndNormalizeSteps({
    required String responseBody,
    required List<Map<String, dynamic>> fallback,
  }) {
    final decoded = jsonDecode(responseBody);
    final content = decoded["choices"]?[0]?["message"]?["content"];

    debugPrint("===== RAW AI CONTENT =====");
    debugPrint(content?.toString() ?? 'null');

    if (content == null || content is! String || content.trim().isEmpty) {
      debugPrint('AI content is empty. Using fallback steps.');
      return fallback;
    }

    final cleaned = _cleanJsonString(content);

    debugPrint("===== CLEANED JSON =====");
    debugPrint(cleaned);

    if (cleaned.isEmpty) {
      debugPrint('Cleaned JSON is empty. Using fallback steps.');
      return fallback;
    }

    final parsed = jsonDecode(cleaned);

    if (parsed is! Map<String, dynamic>) {
      debugPrint('Parsed JSON is not a map. Using fallback steps.');
      return fallback;
    }

    final rawSteps = parsed['steps'];
    if (rawSteps is! List) {
      debugPrint('"steps" is missing or not a list. Using fallback steps.');
      return fallback;
    }

    // ✅ FIX 1 — REQUIRE FULL VALID STEPS
    final steps = _normalizeSteps(
      rawSteps: rawSteps,
      fallback: fallback,
    );

    // 🚨 NEW VALIDATION
    final isValid = steps.every((step) =>
        (step['instruction']?.toString().trim().isNotEmpty ?? false) &&
        (step['whyThisColorSuitsYou']?.toString().trim().isNotEmpty ?? false));

    if (!isValid) {
      debugPrint('AI response incomplete → using FULL fallback');
      return fallback;
    }

    return steps;
  }

  List<Map<String, dynamic>> _normalizeSteps({
    required List rawSteps,
    required List<Map<String, dynamic>> fallback,
  }) {
    final steps = <Map<String, dynamic>>[];

    for (int i = 0; i < _expectedTitles.length; i++) {
      final item = i < rawSteps.length ? rawSteps[i] : null;

      final instruction = _readString(item, 'instruction').isNotEmpty
          ? _readString(item, 'instruction')
          : fallback[i]['instruction']!.toString();

      final whyThisColorSuitsYou =
          _readString(item, 'whyThisColorSuitsYou').isNotEmpty
              ? _readString(item, 'whyThisColorSuitsYou')
              : fallback[i]['whyThisColorSuitsYou']!.toString();

      steps.add({
        'stepNumber': i + 1,
        'title': _expectedTitles[i],
        'instruction': instruction,
        'whyThisColorSuitsYou': whyThisColorSuitsYou,
        'targetArea': _expectedTargetAreas[i],
      });
    }

    return steps;
  }

  String _readString(dynamic item, String key) {
    if (item is Map) {
      return item[key]?.toString().trim() ?? '';
    }
    return '';
  }

  bool _hasMeaningfulInstructions(List<Map<String, dynamic>> steps) {
    return steps.any(
      (step) => (step['instruction']?.toString().trim().isNotEmpty ?? false),
    );
  }

  bool _isSuccessfulStatus(int statusCode) {
    return statusCode >= 200 && statusCode < 300;
  }

  void _logRequestStart() {
    debugPrint('API KEY EMPTY: ${apiKey.isEmpty}');
    debugPrint(
      'API KEY PREFIX: ${apiKey.isNotEmpty ? apiKey.substring(0, 5) : "empty"}',
    );
    debugPrint('Calling OpenAI now...');
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

    final browTone = _browToneForSkinTone(tone);
    final blushPlacement = _blushPlacementForFaceShape(shape);
    final eyeshadowPlacement = _eyeshadowPlacementForFaceShape(shape);

    final lookSpec = _lookSpec(
      look: look,
      undertone: under,
      faceShape: shape,
    );

    final baseWhy = _baseWhyForUndertone(under, look);
    final browWhy = _browWhyForSkinTone(tone);
    final eyeshadowWhy = lookSpec.eyeshadowWhy;
    final eyelinerWhy = lookSpec.eyelinerWhy;
    final blushWhy = lookSpec.blushWhy;
    final lipsWhy = lookSpec.lipsWhy;
    final finalWhy = lookSpec.finalWhy;

    return [
      {
        'stepNumber': 1,
        'title': 'Base Prep',
        'instruction':
            'Prep your full face with moisturizer and a light base for a ${lookSpec.baseFinish} finish. Keep the layers thin and even so the skin looks smooth instead of heavy.',
        'whyThisColorSuitsYou': baseWhy,
        'targetArea': 'full_face',
      },
      {
        'stepNumber': 2,
        'title': 'Eyebrows',
        'instruction':
            'Fill your brows with a $browTone shade using small hair-like strokes. Brush through the front lightly so the brows stay soft and controlled.',
        'whyThisColorSuitsYou': browWhy,
        'targetArea': 'brows',
      },
      {
        'stepNumber': 3,
        'title': 'Eyeshadow',
        'instruction':
            'Apply ${lookSpec.eyeshadowInstruction} $eyeshadowPlacement',
        'whyThisColorSuitsYou': eyeshadowWhy,
        'targetArea': 'eyeshadow',
      },
      {
        'stepNumber': 4,
        'title': 'Eyeliner',
        'instruction': lookSpec.eyelinerInstruction,
        'whyThisColorSuitsYou': eyelinerWhy,
        'targetArea': 'eyeliner',
      },
      {
        'stepNumber': 5,
        'title': 'Blush / Contour',
        'instruction':
            '${lookSpec.blushInstruction} $blushPlacement',
        'whyThisColorSuitsYou': blushWhy,
        'targetArea': 'blush_contour',
      },
      {
        'stepNumber': 6,
        'title': 'Lips',
        'instruction':
            'Apply ${lookSpec.lipInstruction}, starting at the center and blending outward for better control.',
        'whyThisColorSuitsYou': lipsWhy,
        'targetArea': 'lips',
      },
      {
        'stepNumber': 7,
        'title': 'Final Look',
        'instruction':
            'Check the full makeup in good lighting and soften any harsh edges with a clean brush or sponge. Finish with powder or setting spray so the whole look stays neat and blended.',
        'whyThisColorSuitsYou': finalWhy,
        'targetArea': 'full_makeup',
      },
    ];
  }

  _LookSpec _lookSpec({
    required String look,
    required String undertone,
    required String faceShape,
  }) {
    if (look.contains('emo')) {
      final eyeTone = _emoEyeshadowTone(undertone);
      final lipTone = _emoLipTone(undertone);
      return _LookSpec(
        baseFinish: 'defined but wearable',
        eyeshadowInstruction:
            'a $eyeTone eyeshadow across the lids, keeping the deepest color near the lash line and outer corner for a smoky effect.',
        eyelinerInstruction:
            'Trace a more defined eyeliner close to the lash line and extend the outer edge slightly for an edgier shape. Build slowly so the line stays controlled.',
        blushInstruction:
            'Keep blush very minimal and use a muted neutral blush or soft contour tone only if needed to add structure.',
        lipInstruction: 'a $lipTone lip color',
        eyeshadowWhy:
            'These deeper tones support the moody emo style while still staying flattering against your undertone.',
        eyelinerWhy:
            'A stronger liner suits this look because emo makeup is meant to feel more expressive, defined, and eye-focused.',
        blushWhy:
            'A minimal neutral cheek keeps the emo look balanced and prevents the face from looking too soft or overly cheerful.',
        lipsWhy:
            'This deeper lip tone matches the emo color story better while still working with your undertone.',
        finalWhy:
            'This overall look suits you because the stronger eyes, controlled cheek color, and deeper lip create an edgy finish that still works with your undertone and face shape.',
      );
    }

    if (look.contains('soft') || look.contains('glam')) {
      final eyeTone = _softGlamEyeshadowTone(undertone);
      final lipTone = _softGlamLipTone(undertone);
      final blushTone = _softGlamBlushTone(undertone);
      return _LookSpec(
        baseFinish: 'soft-glam',
        eyeshadowInstruction:
            'a $eyeTone eyeshadow across the lids, then add a slightly deeper shade to the crease for soft dimension.',
        eyelinerInstruction:
            'Trace a soft lifted eyeliner close to the lash line to define the eyes without making them look too heavy.',
        blushInstruction:
            'Use a $blushTone blush and blend it softly upward for a diffused glam finish.',
        lipInstruction: 'a $lipTone lip color',
        eyeshadowWhy:
            'These soft glam tones add definition while staying smooth and flattering on your undertone.',
        eyelinerWhy:
            'A softer lifted liner suits this look because it enhances the eyes without overpowering the rest of the makeup.',
        blushWhy:
            'This diffused blush style adds healthy color and supports the polished softness of a soft glam look.',
        lipsWhy:
            'This lip tone keeps the whole makeup look polished and balanced with your complexion.',
        finalWhy:
            'This overall look suits you because the soft definition, balanced tones, and blended placement enhance your features in a polished but wearable way.',
      );
    }

    if (look.contains('doll') || look.contains('k-beauty')) {
      final eyeTone = _kBeautyEyeshadowTone(undertone);
      final lipTone = _kBeautyLipTone(undertone);
      final blushTone = _kBeautyBlushTone(undertone);
      return _LookSpec(
        baseFinish: 'fresh and airy',
        eyeshadowInstruction:
            'a $eyeTone eyeshadow lightly across the lids, keeping the color soft and clean for a youthful finish.',
        eyelinerInstruction:
            'Trace a thin eyeliner close to the lash line to keep the eyes delicate and softly defined.',
        blushInstruction:
            'Use a $blushTone blush with a soft hand so the cheeks look youthful and fresh.',
        lipInstruction: 'a $lipTone lip color',
        eyeshadowWhy:
            'These lighter tones suit the airy K-beauty style while still matching your undertone.',
        eyelinerWhy:
            'A thin liner works well here because it keeps the eyes defined without losing the soft doll-like effect.',
        blushWhy:
            'This soft rosy cheek color gives a fresh youthful effect that matches the look beautifully.',
        lipsWhy:
            'This lip shade supports the soft youthful mood of the look without overpowering your features.',
        finalWhy:
            'This overall look suits you because the soft tones, delicate eye definition, and youthful cheek color create a fresh finish that works well with your features.',
      );
    }

    if (look.contains('bronzed') || look.contains('goddess')) {
      final eyeTone = _bronzedEyeshadowTone(undertone);
      final lipTone = _bronzedLipTone(undertone);
      final blushTone = _bronzedBlushTone(undertone);
      return _LookSpec(
        baseFinish: 'warm sculpted',
        eyeshadowInstruction:
            'a $eyeTone eyeshadow across the lids, then deepen the outer corner slightly for a bronzed glow.',
        eyelinerInstruction:
            'Trace a subtle eyeliner close to the lash line so the bronzed tones stay clean and lifted.',
        blushInstruction:
            'Use a $blushTone blush or bronzer tone to warm up the cheeks and add soft sculpting.',
        lipInstruction: 'a $lipTone lip color',
        eyeshadowWhy:
            'These warm bronzed tones echo the sun-kissed direction of the look while still fitting your undertone.',
        eyelinerWhy:
            'A subtle liner suits this look because it supports the bronzed eye without stealing attention from the glow.',
        blushWhy:
            'This warmer cheek color strengthens the bronzed effect and adds healthy definition to the face.',
        lipsWhy:
            'This lip tone blends well with the bronzed palette and keeps the whole face looking cohesive.',
        finalWhy:
            'This overall look suits you because the warm sculpted tones enhance your features and create a glowing finish that still feels balanced on your face.',
      );
    }

    if (look.contains('bold') || look.contains('editorial')) {
      final eyeTone = _editorialEyeshadowTone(undertone);
      final lipTone = _editorialLipTone(undertone);
      final blushTone = _editorialBlushTone(undertone);
      return _LookSpec(
        baseFinish: 'high-impact',
        eyeshadowInstruction:
            'a $eyeTone eyeshadow with more intentional placement, keeping the shape clean and expressive.',
        eyelinerInstruction:
            'Create a more dramatic liner shape with stronger definition so the eyes feel intentional and fashion-forward.',
        blushInstruction:
            'Use a $blushTone blush or contour tone with a more structured placement for an editorial effect.',
        lipInstruction: 'a $lipTone lip color',
        eyeshadowWhy:
            'These stronger tones suit the editorial mood and help the eyes stand out in a more intentional way.',
        eyelinerWhy:
            'A more graphic liner works here because editorial looks need stronger shape and visual impact.',
        blushWhy:
            'This structured cheek color supports the artistic shape of the look instead of making it feel too soft.',
        lipsWhy:
            'This lip tone keeps the look bold and cohesive while still staying connected to your undertone.',
        finalWhy:
            'This overall look suits you because the stronger shapes, structured color, and intentional contrast create a bold finish that still works with your natural coloring.',
      );
    }

    final baseTone = _neutralEyeshadowTone(undertone);
    final lipTone = _neutralLipTone(undertone);

    return _LookSpec(
      baseFinish: 'balanced',
      eyeshadowInstruction:
          'a $baseTone eyeshadow across the lids, then add a slightly deeper shade to the crease for dimension.',
      eyelinerInstruction:
          'Trace a thin eyeliner close to the lash line to softly define the eyes.',
      blushInstruction:
          'Use a soft neutral blush tone with a light hand so the cheeks stay balanced.',
      lipInstruction: 'a $lipTone lip color',
      eyeshadowWhy:
          'These tones give your eyes dimension while staying flattering on your complexion.',
      eyelinerWhy:
          'A soft liner gives your eyes definition without overwhelming your natural features.',
      blushWhy:
          'This cheek color adds healthy balance without pulling the look too warm or too cool.',
      lipsWhy:
          'This lip tone adds enough color to complete the face while staying wearable.',
      finalWhy:
          'This overall look suits you because the tones and placement work together to enhance your natural features in a balanced way.',
    );
  }

  String _emoEyeshadowTone(String undertone) {
    switch (undertone) {
      case 'warm':
        return 'charcoal brown or muted smoky plum';
      case 'cool':
        return 'charcoal, taupe-smoke, or muted plum';
      case 'neutral':
        return 'charcoal or soft smoky taupe';
      default:
        return 'smoky charcoal';
    }
  }

  String _emoLipTone(String undertone) {
    switch (undertone) {
      case 'warm':
        return 'deep berry, muted brick-berry, or warm plum';
      case 'cool':
        return 'plum, wine, or deep berry';
      case 'neutral':
        return 'deep rose-plum or muted berry';
      default:
        return 'deep berry';
    }
  }

  String _softGlamEyeshadowTone(String undertone) {
    switch (undertone) {
      case 'warm':
        return 'soft brown, peach-beige, or champagne bronze';
      case 'cool':
        return 'taupe, rosy beige, or cool champagne';
      case 'neutral':
        return 'neutral beige, soft taupe, or muted champagne';
      default:
        return 'soft brown and champagne';
    }
  }

  String _softGlamBlushTone(String undertone) {
    switch (undertone) {
      case 'warm':
        return 'peach or warm rose';
      case 'cool':
        return 'soft rose or rosy-mauve';
      case 'neutral':
        return 'rose-peach or muted pink';
      default:
        return 'soft peach-rose';
    }
  }

  String _softGlamLipTone(String undertone) {
    switch (undertone) {
      case 'warm':
        return 'peachy nude or warm rose';
      case 'cool':
        return 'rosy nude or mauve nude';
      case 'neutral':
        return 'neutral rose or muted nude';
      default:
        return 'soft rosy nude';
    }
  }

  String _kBeautyEyeshadowTone(String undertone) {
    switch (undertone) {
      case 'warm':
        return 'light peach-beige or warm soft brown';
      case 'cool':
        return 'soft pink-beige or cool taupe';
      case 'neutral':
        return 'soft beige-pink or light neutral taupe';
      default:
        return 'light soft beige';
    }
  }

  String _kBeautyBlushTone(String undertone) {
    switch (undertone) {
      case 'warm':
        return 'soft coral-rose or warm pink';
      case 'cool':
        return 'cool pink or rosy blush';
      case 'neutral':
        return 'soft rose or muted pink';
      default:
        return 'soft rosy pink';
    }
  }

  String _kBeautyLipTone(String undertone) {
    switch (undertone) {
      case 'warm':
        return 'warm pink, coral-rose, or peachy pink';
      case 'cool':
        return 'cool pink, rosy tint, or berry-pink';
      case 'neutral':
        return 'rosy pink or soft neutral pink';
      default:
        return 'soft pink';
    }
  }

  String _bronzedEyeshadowTone(String undertone) {
    switch (undertone) {
      case 'warm':
        return 'gold, bronze, or copper';
      case 'cool':
        return 'taupe-bronze or muted bronze rose';
      case 'neutral':
        return 'bronze, caramel, or neutral gold';
      default:
        return 'soft bronze';
    }
  }

  String _bronzedBlushTone(String undertone) {
    switch (undertone) {
      case 'warm':
        return 'warm terracotta or bronzed peach';
      case 'cool':
        return 'muted bronze-rose';
      case 'neutral':
        return 'soft terracotta-nude';
      default:
        return 'warm bronzed nude';
    }
  }

  String _bronzedLipTone(String undertone) {
    switch (undertone) {
      case 'warm':
        return 'terracotta nude or warm caramel rose';
      case 'cool':
        return 'bronzed rose or muted cocoa-rose';
      case 'neutral':
        return 'warm nude rose or soft terracotta';
      default:
        return 'bronzed nude';
    }
  }

  String _editorialEyeshadowTone(String undertone) {
    switch (undertone) {
      case 'warm':
        return 'deep rust, warm plum, or burnt bronze';
      case 'cool':
        return 'cool plum, slate, or smoky navy-toned depth';
      case 'neutral':
        return 'deep mauve, plum-brown, or smoky taupe';
      default:
        return 'deep fashion-forward tones';
    }
  }

  String _editorialBlushTone(String undertone) {
    switch (undertone) {
      case 'warm':
        return 'burnt rose, terracotta, or warm sculpting tone';
      case 'cool':
        return 'berry-rose, mauve contour, or cool sculpting tone';
      case 'neutral':
        return 'muted rose-plum or neutral sculpting tone';
      default:
        return 'structured cheek color';
    }
  }

  String _editorialLipTone(String undertone) {
    switch (undertone) {
      case 'warm':
        return 'deep brick-rose or rich terracotta';
      case 'cool':
        return 'berry-plum or deep mauve';
      case 'neutral':
        return 'deep rose, plum-rose, or muted statement nude';
      default:
        return 'statement lip color';
    }
  }

  String _neutralEyeshadowTone(String undertone) {
    switch (undertone) {
      case 'warm':
        return 'warm beige or soft brown';
      case 'cool':
        return 'taupe or cool beige';
      case 'neutral':
        return 'neutral beige or soft taupe';
      default:
        return 'soft neutral';
    }
  }

  String _neutralLipTone(String undertone) {
    switch (undertone) {
      case 'warm':
        return 'warm nude';
      case 'cool':
        return 'rosy nude';
      case 'neutral':
        return 'neutral nude';
      default:
        return 'soft nude';
    }
  }

  String _browToneForSkinTone(String tone) {
    switch (tone) {
      case 'light':
        return 'light brown';
      case 'medium':
        return 'medium brown';
      case 'tan':
        return 'deep brown';
      case 'deep':
        return 'rich deep brown';
      default:
        return 'natural brown';
    }
  }

  String _blushPlacementForFaceShape(String shape) {
    switch (shape) {
      case 'round':
        return 'Place it slightly higher and blend upward toward the temples to create a lifted effect.';
      case 'square':
        return 'Blend it softly on the outer cheeks and sweep it upward to soften strong angles.';
      case 'heart':
        return 'Keep it slightly lower on the cheeks and blend outward for balance.';
      case 'oval':
        return 'Place it on the apples of the cheeks and blend slightly upward for a naturally balanced finish.';
      default:
        return 'Place it on the cheeks and blend outward and upward for a soft finish.';
    }
  }

  String _eyeshadowPlacementForFaceShape(String shape) {
    switch (shape) {
      case 'round':
        return 'Blend the outer corner slightly upward to elongate the eyes.';
      case 'square':
        return 'Keep the blending soft and rounded to balance sharper features.';
      case 'heart':
        return 'Focus a bit more color on the outer lid to add balance.';
      case 'oval':
        return 'Blend evenly across the lid and slightly into the crease for a balanced look.';
      default:
        return 'Blend softly across the lid and crease.';
    }
  }

  String _baseWhyForUndertone(String under, String look) {
    if (look.contains('emo')) {
      switch (under) {
        case 'warm':
          return 'These balanced base tones keep the skin even without making the emo look turn too warm or peachy.';
        case 'cool':
          return 'These cleaner base tones support the moodier emo style without clashing with your cooler undertone.';
        case 'neutral':
          return 'These neutral base tones help the emo look stay balanced while keeping your complexion natural.';
        default:
          return 'This balanced base helps the stronger emo eye and lip colors stand out without making the skin look heavy.';
      }
    }

    switch (under) {
      case 'warm':
        return 'These warmer base tones blend more naturally into your complexion and keep your skin looking fresh instead of flat.';
      case 'cool':
        return 'These softer cool-beige tones suit your undertone and help the base look clean, balanced, and not too yellow.';
      case 'neutral':
        return 'These neutral base tones match your coloring well, so the skin looks even without feeling too warm or too pink.';
      default:
        return 'This balanced base tone helps your complexion look even and natural for the selected look.';
    }
  }

  String _browWhyForSkinTone(String tone) {
    switch (tone) {
      case 'light':
        return 'A lighter brown keeps your brows defined without overpowering your softer natural contrast.';
      case 'medium':
        return 'A medium brown gives enough definition while still blending naturally with your overall coloring.';
      case 'tan':
        return 'A deeper brown suits your skin depth better, so the brows stay visible and balanced on your face.';
      case 'deep':
        return 'A rich deep brown works better with your skin depth and keeps the brows strong without looking ashy.';
      default:
        return 'This brow tone keeps your features framed in a way that still looks natural on you.';
    }
  }
}

class _LookSpec {
  final String baseFinish;
  final String eyeshadowInstruction;
  final String eyelinerInstruction;
  final String blushInstruction;
  final String lipInstruction;

  final String eyeshadowWhy;
  final String eyelinerWhy;
  final String blushWhy;
  final String lipsWhy;
  final String finalWhy;

  const _LookSpec({
    required this.baseFinish,
    required this.eyeshadowInstruction,
    required this.eyelinerInstruction,
    required this.blushInstruction,
    required this.lipInstruction,
    required this.eyeshadowWhy,
    required this.eyelinerWhy,
    required this.blushWhy,
    required this.lipsWhy,
    required this.finalWhy,
  });
}