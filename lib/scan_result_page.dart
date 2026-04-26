import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import 'instructions_page.dart';
import 'look_engine.dart';
import 'painters/makeup_overlay_painter.dart';
import 'skin_analyzer.dart';

class ScanResultPage extends StatefulWidget {
  final String? scannedImagePath;
  final String? scannedItem;
  final Face? detectedFace;
  final FaceProfile? faceProfile;
  final LookResult? look;
  final MakeupLookPreset selectedPreset;

  const ScanResultPage({
    super.key,
    this.scannedImagePath,
    this.scannedItem,
    this.detectedFace,
    this.faceProfile,
    this.look,
    this.selectedPreset = MakeupLookPreset.softGlam,
  });

  @override
  State<ScanResultPage> createState() => _ScanResultPageState();
}

class _ScanResultPageState extends State<ScanResultPage> {
  ui.Image? _uiImage;
  Face? _previewFace;

  final ValueNotifier<double> _sliderValue = ValueNotifier<double>(0.75);
  final ValueNotifier<double> _appliedIntensity = ValueNotifier<double>(0.75);

  late final MakeupLookPreset _currentPreset;

  String selectedFilter = 'Natural';
  final List<String> filters = ['Natural', 'Everyday', 'Glam'];

  @override
  void initState() {
    super.initState();
    _currentPreset = widget.selectedPreset;
    _loadPreviewAndDetect();
  }

  @override
  void dispose() {
    _sliderValue.dispose();
    _appliedIntensity.dispose();
    super.dispose();
  }

  Future<void> _loadPreviewAndDetect() async {
    final path = widget.scannedImagePath;
    if (path == null) return;

    final bytes = await File(path).readAsBytes();

    final codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: 720,
    );

    final frame = await codec.getNextFrame();
    final previewImage = frame.image;

    if (!mounted) return;

    setState(() {
      _uiImage = previewImage;
      _previewFace = null;
    });

    try {
      final tmpFile = await _writeUiImageToTempPng(previewImage);
      final face = await _detectFaceOnFile(tmpFile.path);

      if (!mounted) return;

      setState(() {
        _previewFace = face;
      });

      tmpFile.delete().catchError((_) => tmpFile);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _previewFace = null;
      });
    }
  }

  Future<File> _writeUiImageToTempPng(ui.Image image) async {
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      throw Exception('Failed to encode preview image.');
    }

    final Uint8List pngBytes = byteData.buffer.asUint8List();

    final dir = await Directory.systemTemp.createTemp('ft_preview_');
    final file = File('${dir.path}/preview.png');
    await file.writeAsBytes(pngBytes, flush: true);
    return file;
  }

  Future<Face?> _detectFaceOnFile(String filePath) async {
    final detector = FaceDetector(
      options: FaceDetectorOptions(
        performanceMode: FaceDetectorMode.accurate,
        enableLandmarks: true,
        enableContours: true,
        enableClassification: true,
        enableTracking: true,
      ),
    );

    try {
      final input = InputImage.fromFilePath(filePath);
      final faces = await detector.processImage(input);
      if (faces.isEmpty) return null;
      return faces.first;
    } finally {
      await detector.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    final faceForOverlay = _previewFace ?? widget.detectedFace;
    final canOverlay =
        _uiImage != null && faceForOverlay != null && widget.look != null;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Style Preview',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 320,
                    child: _buildPhotoContainer(
                      canOverlay: canOverlay,
                      faceForOverlay: faceForOverlay,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_uiImage != null && widget.look != null)
                    Row(
                      children: [
                        const Text('Opacity', style: TextStyle(fontSize: 12)),
                        Expanded(
                          child: ValueListenableBuilder<double>(
                            valueListenable: _sliderValue,
                            builder: (context, v, _) {
                              return Slider(
                                value: v,
                                min: 0.0,
                                max: 1.0,
                                divisions: 20,
                                label: '${(v * 100).round()}%',
                                onChanged: (newV) {
                                  _sliderValue.value = newV;
                                },
                                onChangeEnd: (endV) {
                                  _appliedIntensity.value = endV;
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  if (widget.scannedItem != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Recommended Products for ${widget.scannedItem}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildRecommendedProducts(),
                  ],
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
          _buildBottomButtons(),
        ],
      ),
    );
  }

  Widget _buildPhotoContainer({
    required bool canOverlay,
    required Face? faceForOverlay,
  }) {
    final double? aspect = _uiImage != null
        ? (_uiImage!.width.toDouble() / _uiImage!.height.toDouble())
        : null;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFFF4D97).withOpacity(0.3),
          width: 2,
        ),
      ),
      child: AspectRatio(
        aspectRatio: aspect ?? (3 / 4),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: _uiImage != null && canOverlay
              ? Center(
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: SizedBox(
                      width: _uiImage!.width.toDouble(),
                      height: _uiImage!.height.toDouble(),
                      child: RepaintBoundary(
                        child: ValueListenableBuilder<double>(
                          valueListenable: _appliedIntensity,
                          builder: (context, intensityValue, _) {
                            return CustomPaint(
                              painter: MakeupOverlayPainter(
                                image: _uiImage!,
                                face: faceForOverlay!,
                                lipstickColor: widget.look!.lipstickColor,
                                blushColor: widget.look!.blushColor,
                                eyeshadowColor: widget.look!.eyeshadowColor,
                                intensity: intensityValue,
                                faceShape:
                                    widget.faceProfile?.faceShape ??
                                        FaceShape.oval,
                                preset: _currentPreset,
                                debugMode: false,
                                isLiveMode: false,
                                eyelinerStyle: LookEngine.configFromPreset(
                                  _currentPreset,
                                  profile: widget.faceProfile,
                                ).eyelinerStyle,
                                skinColor: widget.faceProfile != null
                                    ? Color.fromARGB(
                                        255,
                                        widget.faceProfile!.avgR,
                                        widget.faceProfile!.avgG,
                                        widget.faceProfile!.avgB,
                                      )
                                    : Colors.transparent,
                                sceneLuminance: 0.5,
                                leftCheekLuminance: 0.5,
                                rightCheekLuminance: 0.5,
                                profile: widget.faceProfile,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                )
              : widget.scannedImagePath != null
                  ? Center(
                      child: FittedBox(
                        fit: BoxFit.contain,
                        child: Image.file(
                          File(widget.scannedImagePath!),
                          errorBuilder: (context, error, stackTrace) {
                            return _buildPlaceholder();
                          },
                        ),
                      ),
                    )
                  : _buildPlaceholder(),
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.face_retouching_natural,
            size: 80,
            color: const Color(0xFFFF4D97).withOpacity(0.5),
          ),
          const SizedBox(height: 12),
          Text(
            'Your Photo Preview',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButtons() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: const BorderSide(
                      color: Color(0xFFFF4D97),
                      width: 2,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.arrow_back,
                        size: 18,
                        color: Color(0xFFFF4D97),
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Back',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFFF4D97),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: widget.look != null
                      ? () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => InstructionsPage(
                                look: widget.look!,
                                faceProfile: widget.faceProfile,
                                scannedImagePath: widget.scannedImagePath,
                                detectedFace: _previewFace ?? widget.detectedFace,
                                selectedPreset: _currentPreset,
                              ),
                            ),
                          );
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: const Color(0xFFFF4D97),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.school, size: 18, color: Colors.white),
                      SizedBox(width: 6),
                      Text(
                        'Tutorial',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _showBuyProductDialog,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: const Color(0xFFFF4D97),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Buy Products',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendedProducts() {
    final products = _getProductsByItem(widget.scannedItem ?? '');

    return Column(
      children: List.generate(products.length, (index) {
        final product = products[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Container(
            padding: const EdgeInsets.all(12),
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
            child: Row(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: (product['color'] as Color).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    product['icon'] as IconData,
                    size: 40,
                    color: product['color'] as Color,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product['name'] as String,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        product['brand'] as String,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.star, size: 14, color: Colors.amber),
                          const SizedBox(width: 4),
                          Text(
                            product['rating'] as String,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[700],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            product['price'] as String,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFFF4D97),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${product['name']} added to cart'),
                        backgroundColor: const Color(0xFFFF4D97),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF4D97),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  child: const Text(
                    'Add',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  List<Map<String, dynamic>> _getProductsByItem(String item) {
    final productMap = {
      'Lips': [
        {
          'name': 'Ruby Red Lipstick',
          'brand': 'Glamour Beauty',
          'price': '\$24.99',
          'rating': '4.8',
          'icon': Icons.color_lens,
          'color': Colors.red,
        },
        {
          'name': 'Rosy Pink Matte',
          'brand': 'Elegant Cosmetics',
          'price': '\$19.99',
          'rating': '4.7',
          'icon': Icons.color_lens,
          'color': Colors.pink,
        },
        {
          'name': 'Nude Bliss',
          'brand': 'Natural Beauty',
          'price': '\$22.99',
          'rating': '4.6',
          'icon': Icons.color_lens,
          'color': Colors.brown,
        },
      ],
      'Eyes': [
        {
          'name': 'Shimmer Eyeshadow Palette',
          'brand': 'Eye Couture',
          'price': '\$34.99',
          'rating': '4.9',
          'icon': Icons.remove_red_eye,
          'color': Colors.purple,
        },
        {
          'name': 'Golden Hour Palette',
          'brand': 'Sun Glow',
          'price': '\$29.99',
          'rating': '4.8',
          'icon': Icons.remove_red_eye,
          'color': Colors.amber,
        },
        {
          'name': 'Smokey Noir Set',
          'brand': 'Dark Matter',
          'price': '\$27.99',
          'rating': '4.7',
          'icon': Icons.remove_red_eye,
          'color': Colors.grey,
        },
      ],
      'Foundation': [
        {
          'name': 'Perfect Coverage Foundation',
          'brand': 'Pro Base',
          'price': '\$39.99',
          'rating': '4.8',
          'icon': Icons.face,
          'color': Colors.amber,
        },
        {
          'name': 'Flawless Finish',
          'brand': 'Skin Perfect',
          'price': '\$35.99',
          'rating': '4.7',
          'icon': Icons.face,
          'color': Colors.orange,
        },
        {
          'name': 'Natural Glow Base',
          'brand': 'Pure Beauty',
          'price': '\$32.99',
          'rating': '4.6',
          'icon': Icons.face,
          'color': Colors.brown,
        },
      ],
      'Blush': [
        {
          'name': 'Rose Blush',
          'brand': 'Cheek Perfection',
          'price': '\$22.99',
          'rating': '4.8',
          'icon': Icons.favorite,
          'color': Colors.pink,
        },
        {
          'name': 'Coral Peach Blush',
          'brand': 'Warm Tones',
          'price': '\$21.99',
          'rating': '4.7',
          'icon': Icons.favorite,
          'color': Colors.deepOrange,
        },
        {
          'name': 'Sunset Bronze',
          'brand': 'Bronzer Blend',
          'price': '\$24.99',
          'rating': '4.9',
          'icon': Icons.favorite,
          'color': Colors.brown,
        },
      ],
      'Eyebrow': [
        {
          'name': 'Brow Defining Pencil',
          'brand': 'Brow Expert',
          'price': '\$18.99',
          'rating': '4.7',
          'icon': Icons.edit,
          'color': Colors.brown,
        },
        {
          'name': 'Micro Brow Pen',
          'brand': 'Precision Beauty',
          'price': '\$21.99',
          'rating': '4.8',
          'icon': Icons.edit,
          'color': Colors.grey,
        },
        {
          'name': 'Brow Filler Gel',
          'brand': 'Hold Strong',
          'price': '\$17.99',
          'rating': '4.6',
          'icon': Icons.edit,
          'color': Colors.blueGrey,
        },
      ],
      'Eyeliner': [
        {
          'name': 'Waterproof Liquid Eyeliner',
          'brand': 'Line Perfect',
          'price': '\$16.99',
          'rating': '4.8',
          'icon': Icons.brush,
          'color': Colors.black,
        },
        {
          'name': 'Gel Eyeliner',
          'brand': 'Smooth Lines',
          'price': '\$19.99',
          'rating': '4.7',
          'icon': Icons.brush,
          'color': Colors.indigo,
        },
        {
          'name': 'Felt Tip Eyeliner',
          'brand': 'Precision Ink',
          'price': '\$18.99',
          'rating': '4.9',
          'icon': Icons.brush,
          'color': Colors.black87,
        },
      ],
    };

    return productMap[item] ?? [];
  }

  void _showBuyProductDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Buy Products',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        content: const Text(
          'This will take you to our recommended products for your selected look.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF4D97),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }
}