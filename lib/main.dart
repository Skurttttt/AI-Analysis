import 'dart:io';
import 'dart:ui' as ui;
import 'dart:math' show cos, sin;

import 'skin_analyzer.dart';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'instructions_page.dart';
import 'look_engine.dart';
import 'look_picker.dart';
import 'painters/makeup_overlay_painter.dart';
import 'scan_result_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: "assets/.env");

  try {
    final envUrl = (dotenv.env['SUPABASE_URL'] ?? '').trim();
    final envAnonKey = (dotenv.env['SUPABASE_ANON_KEY'] ?? '').trim();

    const fallbackUrl = 'https://iqaiebnoodjnoyaiyoez.supabase.co';
    const fallbackAnonKey =
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlxYWllYm5vb2Rqbm95YWl5b2V6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzAwMzAzNDEsImV4cCI6MjA4NTYwNjM0MX0.2Jvt3WMFpaTYIAE_wff-wlmZfrJNJdXku76cF1x4MFY';

    await Supabase.initialize(
      url: envUrl.isNotEmpty ? envUrl : fallbackUrl,
      anonKey: envAnonKey.isNotEmpty ? envAnonKey : fallbackAnonKey,
    );
  } catch (e) {
    debugPrint('❌ Supabase initialization error: $e');
  }

  CameraDescription? frontCamera;
  try {
    final cameras = await availableCameras();
    frontCamera = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );
  } catch (e) {
    debugPrint('Camera access error: $e');
  }

  runApp(App(frontCamera: frontCamera));
}

class App extends StatelessWidget {
  final CameraDescription? frontCamera;
  const App({super.key, required this.frontCamera});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FaceTune - Beauty & Style',
      theme: ThemeData(
        useMaterial3: true,
        primaryColor: const Color(0xFFFF4D97),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF4D97),
          primary: const Color(0xFFFF4D97),
        ),
      ),
      debugShowCheckedModeBanner: false,
      home: frontCamera == null
          ? const NoCameraScreen()
          : CameraScreen(camera: frontCamera!),
    );
  }
}

class NoCameraScreen extends StatelessWidget {
  const NoCameraScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No camera available on this device.\nPlease run the app on a physical device with a front camera.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

class CameraScreen extends StatefulWidget {
  final CameraDescription camera;
  final String? scannedItem;

  const CameraScreen({super.key, required this.camera, this.scannedItem});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  @override
  Widget build(BuildContext context) {
    return FaceScanPage(camera: widget.camera, scannedItem: widget.scannedItem);
  }
}

class FaceScanPage extends StatefulWidget {
  final CameraDescription camera;
  final String? scannedItem;

  const FaceScanPage({super.key, required this.camera, this.scannedItem});

  @override
  State<FaceScanPage> createState() => _FaceScanPageState();
}

class _FaceScanPageState extends State<FaceScanPage> {
  CameraController? _controller;
  bool _busy = false;

  XFile? _capturedFile;
  ui.Image? _capturedUiImage;
  Face? _detectedFace;

  FaceProfile? _faceProfile;
  LookResult? _look;

  double _intensity = 0.75;

  double _sceneLuminance = 0.50;
  double _leftCheekLum = 0.50;
  double _rightCheekLum = 0.50;

  bool _liveRunning = false;
  DateTime _lastLiveTick = DateTime.fromMillisecondsSinceEpoch(0);
  static const Duration _liveInterval = Duration(milliseconds: 450);

  String _liveQualityLabel = 'Point camera at your face…';
  List<String> _liveWarnings = [];

  final InputImageRotation _liveRotation = InputImageRotation.rotation270deg;

  int _noFaceStreak = 0;
  Face? _lastDetectedFace;

  MakeupLookPreset _selectedLook = MakeupLookPreset.softGlam;

  late final FaceDetector _liveFaceDetector = FaceDetector(
    options: FaceDetectorOptions(
      performanceMode: FaceDetectorMode.fast,
      minFaceSize: 0.05,
      enableContours: false,
      enableLandmarks: false,
      enableClassification: false,
    ),
  );

  String _status = 'Tap the preview to capture & scan.';

  late final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      performanceMode: FaceDetectorMode.accurate,
      enableLandmarks: true,
      enableContours: true,
      enableClassification: true,
      minFaceSize: 0.15,
    ),
  );

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    final controller = CameraController(
      widget.camera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.bgra8888,
    );

    try {
      await controller.initialize();
      await controller.setFlashMode(FlashMode.off);
      await controller.setFocusMode(FocusMode.auto);

      if (!mounted) return;

      setState(() {
        _controller = controller;
      });

      await _startLiveQuality(controller);
    } catch (e) {
      setState(() => _status = 'Camera init error: $e');
    }
  }

  @override
  void dispose() {
    _stopLiveQuality();
    _controller?.dispose();
    _faceDetector.close();
    _liveFaceDetector.close();
    super.dispose();
  }

  Future<ui.Image> _loadUiImageFromFile(String path) async {
    final bytes = await File(path).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  Future<double> _estimateSceneLuminance(ui.Image image) async {
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null) return 0.5;

    final bytes = byteData.buffer.asUint8List();
    final w = image.width;
    final h = image.height;

    final stepX = (w / 25).clamp(8, 40).toInt();
    final stepY = (h / 25).clamp(8, 40).toInt();

    double sum = 0.0;
    int count = 0;

    for (int y = 0; y < h; y += stepY) {
      for (int x = 0; x < w; x += stepX) {
        final i = (y * w + x) * 4;
        if (i + 2 >= bytes.length) continue;

        final r = bytes[i] / 255.0;
        final g = bytes[i + 1] / 255.0;
        final b = bytes[i + 2] / 255.0;

        sum += (0.2126 * r + 0.7152 * g + 0.0722 * b);
        count++;
      }
    }

    return count == 0 ? 0.5 : (sum / count).clamp(0.0, 1.0);
  }

  Future<double> _avgLuminanceInRect(ui.Image image, Rect rect) async {
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null) return 0.5;

    final bytes = byteData.buffer.asUint8List();
    final w = image.width;
    final h = image.height;

    final safe = rect.intersect(Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()));
    if (safe.isEmpty) return 0.5;

    final stepX = (safe.width / 18).clamp(6, 26).toInt();
    final stepY = (safe.height / 18).clamp(6, 26).toInt();

    double sum = 0.0;
    int count = 0;

    for (int y = safe.top.toInt(); y < safe.bottom.toInt(); y += stepY) {
      for (int x = safe.left.toInt(); x < safe.right.toInt(); x += stepX) {
        final i = (y * w + x) * 4;
        if (i + 2 >= bytes.length) continue;

        final r = bytes[i] / 255.0;
        final g = bytes[i + 1] / 255.0;
        final b = bytes[i + 2] / 255.0;

        sum += (0.2126 * r + 0.7152 * g + 0.0722 * b);
        count++;
      }
    }

    return count == 0 ? 0.5 : (sum / count).clamp(0.0, 1.0);
  }

  Uint8List _yuv420ToNv21(CameraImage image) {
    final width = image.width;
    final height = image.height;

    final yPlane = image.planes[0].bytes;
    final uPlane = image.planes[1].bytes;
    final vPlane = image.planes[2].bytes;

    final yRowStride = image.planes[0].bytesPerRow;
    final uvRowStride = image.planes[1].bytesPerRow;
    final uvPixelStride = image.planes[1].bytesPerPixel ?? 1;

    final nv21 = Uint8List(width * height + (width * height ~/ 2));
    int index = 0;

    for (int row = 0; row < height; row++) {
      final yRowStart = row * yRowStride;
      for (int col = 0; col < width; col++) {
        nv21[index++] = yPlane[yRowStart + col];
      }
    }

    for (int row = 0; row < height ~/ 2; row++) {
      final uvRowStart = row * uvRowStride;
      for (int col = 0; col < width ~/ 2; col++) {
        final uvIndex = uvRowStart + col * uvPixelStride;
        nv21[index++] = vPlane[uvIndex];
        nv21[index++] = uPlane[uvIndex];
      }
    }

    return nv21;
  }

  InputImage _inputImageFromCameraImageNv21(CameraImage image) {
    final bytes = _yuv420ToNv21(image);

    final metadata = InputImageMetadata(
      size: Size(image.width.toDouble(), image.height.toDouble()),
      rotation: _liveRotation,
      format: InputImageFormat.nv21,
      bytesPerRow: image.width,
    );

    return InputImage.fromBytes(bytes: bytes, metadata: metadata);
  }

  double _estimateBrightness(CameraImage image) {
    final yPlane = image.planes[0].bytes;
    if (yPlane.isEmpty) return 0;

    const step = 50;
    int sum = 0;
    int count = 0;

    for (int i = 0; i < yPlane.length; i += step) {
      sum += yPlane[i];
      count++;
    }

    return count == 0 ? 0 : sum / count;
  }

  List<String> _buildLiveWarnings({
    required Face? face,
    required int imgW,
    required int imgH,
    required double brightness,
  }) {
    final warnings = <String>[];

    if (brightness < 60) {
      warnings.add('Too dark. Move to a brighter area or face a light source.');
    } else if (brightness < 90) {
      warnings.add('Lighting is dim. Try brighter and even lighting.');
    }

    if (face == null) {
      warnings.add('No face detected. Face the camera and remove obstructions.');
      return warnings;
    }

    final faceArea = face.boundingBox.width * face.boundingBox.height;
    final imgArea = imgW * imgH;
    final ratio = faceArea / imgArea;

    if (ratio < 0.04) {
      warnings.add('Move closer. Your face is too small in the frame.');
    }

    return warnings;
  }

  String _liveQualityFromWarnings(List<String> w) {
    if (w.isEmpty) return 'Good ✅';
    if (w.length == 1) return 'Moderate ⚠️';
    return 'Low ⚠️';
  }

  String _brightnessLabel(double b) {
    if (b < 60) return 'Too dark';
    if (b < 90) return 'Dim';
    if (b < 170) return 'Good';
    return 'Very bright';
  }

  Future<void> _startLiveQuality(CameraController controller) async {
    if (_liveRunning) return;

    _liveRunning = true;

    await controller.startImageStream((CameraImage image) async {
      if (!_liveRunning) return;

      final now = DateTime.now();
      if (now.difference(_lastLiveTick) < _liveInterval) return;
      _lastLiveTick = now;

      try {
        final brightness = _estimateBrightness(image);
        final input = _inputImageFromCameraImageNv21(image);
        final faces = await _liveFaceDetector.processImage(input);

        Face? face;

        if (faces.isNotEmpty) {
          faces.sort((a, b) => (b.boundingBox.width * b.boundingBox.height)
              .compareTo(a.boundingBox.width * a.boundingBox.height));

          face = faces.first;
          _lastDetectedFace = face;
          _noFaceStreak = 0;
        } else {
          _noFaceStreak++;

          if (_noFaceStreak < 3 && _lastDetectedFace != null) {
            face = _lastDetectedFace;
          }
        }

        final warnings = _buildLiveWarnings(
          face: _noFaceStreak >= 3 ? null : face,
          imgW: image.width,
          imgH: image.height,
          brightness: brightness,
        );

        if (mounted) {
          setState(() {
            _liveWarnings = warnings;
            _liveQualityLabel =
                '${_liveQualityFromWarnings(warnings)} • ${_brightnessLabel(brightness)}';
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _liveQualityLabel = 'Live Scan Quality: Error';
            _liveWarnings = ['Live analyzer error: $e'];
          });
        }
      }
    });
  }

  Future<void> _stopLiveQuality() async {
    _liveRunning = false;

    try {
      await _controller?.stopImageStream();
    } catch (_) {}
  }

  bool _canCaptureNow() {
    final severe = _liveWarnings.any((w) {
      final text = w.toLowerCase();
      return text.contains('too dark') ||
          text.contains('move closer') ||
          text.contains('no face detected');
    });

    return !severe;
  }

  void _showCaptureBlockedMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Fix live scan tips first before capturing.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _handlePreviewTap() {
    if (_busy) return;

    if (!_canCaptureNow()) {
      _showCaptureBlockedMessage();
      return;
    }

    _captureAndScan();
  }

  Future<void> _captureAndScan() async {
    if (!_canCaptureNow()) {
      _showCaptureBlockedMessage();
      return;
    }

    final controller = _controller;

    if (controller == null || !controller.value.isInitialized || _busy) return;

    setState(() {
      _busy = true;
      _status = 'Capturing…';
      _capturedFile = null;
      _capturedUiImage = null;
      _detectedFace = null;
      _faceProfile = null;
      _look = null;
      _intensity = 0.75;
      _sceneLuminance = 0.50;
      _leftCheekLum = 0.50;
      _rightCheekLum = 0.50;
    });

    try {
      await _stopLiveQuality();

      final file = await controller.takePicture();
      final uiImage = await _loadUiImageFromFile(file.path);
      final sceneLum = await _estimateSceneLuminance(uiImage);

      setState(() {
        _capturedFile = file;
        _capturedUiImage = uiImage;
        _sceneLuminance = sceneLum;
        _status = 'Detecting face…';
      });

      final inputImage = InputImage.fromFilePath(file.path);
      final faces = await _faceDetector.processImage(inputImage);

      if (faces.isEmpty) {
        setState(() => _status = 'No face detected. Try better lighting.');
        return;
      }

      faces.sort((a, b) => (b.boundingBox.width * b.boundingBox.height)
          .compareTo(a.boundingBox.width * a.boundingBox.height));

      final face = faces.first;

      final box = face.boundingBox;
      final fw = box.width;
      final fh = box.height;

      final leftCheekRect = Rect.fromLTWH(
        box.left + fw * 0.08,
        box.top + fh * 0.45,
        fw * 0.28,
        fh * 0.22,
      );

      final rightCheekRect = Rect.fromLTWH(
        box.left + fw * 0.64,
        box.top + fh * 0.45,
        fw * 0.28,
        fh * 0.22,
      );

      final leftLum = await _avgLuminanceInRect(uiImage, leftCheekRect);
      final rightLum = await _avgLuminanceInRect(uiImage, rightCheekRect);

      setState(() {
        _leftCheekLum = leftLum;
        _rightCheekLum = rightLum;
        _status = 'Analyzing skin tone…';
      });

      final skin = await SkinAnalyzer.analyze(uiImage, face);
      final profile = FaceProfile.fromAnalysis(face, skin);

      final look = LookEngine.generateLook(
        profile: profile,
        preset: _selectedLook,
      );

      setState(() {
        _detectedFace = face;
        _faceProfile = profile;
        _look = look;
        _status = 'Done ✅ Navigating to results…';
      });

      if (mounted) {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ScanResultPage(
              scannedImagePath: _capturedFile?.path,
              scannedItem: widget.scannedItem,
              detectedFace: face,
              faceProfile: profile,
              look: look,
              selectedPreset: _selectedLook,
            ),
          ),
        );

        if (mounted) {
          setState(() {
            _capturedFile = null;
            _capturedUiImage = null;
            _detectedFace = null;
            _faceProfile = null;
            _look = null;
            _status = 'Tap the preview to capture & scan.';
          });

          final c = _controller;
          if (c != null && c.value.isInitialized) {
            await _startLiveQuality(c);
          }
        }
      }
    } catch (e) {
      setState(() => _status = 'Error: $e');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }

      final c = _controller;
      if (c != null && c.value.isInitialized) {
        await _startLiveQuality(c);
      }
    }
  }

  void _openInstructions() {
    final look = _look;
    if (look == null) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => InstructionsPage(
          look: look,
          faceProfile: _faceProfile,
          scannedImagePath: _capturedFile?.path,
          detectedFace: _detectedFace,
          selectedPreset: _selectedLook,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    final bool showPreview =
        _capturedUiImage != null && _detectedFace != null && _look != null;

    final bool showSlider = showPreview && _faceProfile != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Face Scan', style: TextStyle(fontSize: 16)),
        toolbarHeight: 48,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              color: Colors.black.withOpacity(0.8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                children: [
                  Text(
                    'Quality: $_liveQualityLabel',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                  if (_liveWarnings.isNotEmpty)
                    Text(
                      _liveWarnings.take(1).join(' • '),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                      ),
                    ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(12),
              child: GestureDetector(
                onTap: _handlePreviewTap,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: const Color(0xFFFF4D97),
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.black,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: controller == null || !controller.value.isInitialized
                          ? const Center(
                              child: CircularProgressIndicator(
                                color: Color(0xFFFF4D97),
                              ),
                            )
                          : Stack(
                              fit: StackFit.expand,
                              children: [
                                FittedBox(
                                  fit: BoxFit.cover,
                                  child: SizedBox(
                                    width: controller.value.previewSize!.height,
                                    height: controller.value.previewSize!.width,
                                    child: CameraPreview(controller),
                                  ),
                                ),
                                if (!_busy && _capturedUiImage == null)
                                  CustomPaint(
                                    painter: FaceGuidePainter(),
                                  ),
                                if (_busy)
                                  const Center(
                                    child: CircularProgressIndicator(
                                      color: Color(0xFFFF4D97),
                                    ),
                                  ),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: LookPicker(
                value: _selectedLook,
                onChanged: (v) => setState(() => _selectedLook = v),
              ),
            ),

            if (showPreview)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                child: Column(
                  children: [
                    SizedBox(
                      height: 180,
                      child: RepaintBoundary(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: FittedBox(
                            fit: BoxFit.contain,
                            child: SizedBox(
                              width: _capturedUiImage!.width.toDouble(),
                              height: _capturedUiImage!.height.toDouble(),
                              child: Builder(
                                builder: (context) {
                                  final bool isDebug = false;

                                  // ✅ FIXED: Using eyelinerStyleFromPreset instead of configFromPreset
                                  return CustomPaint(
                                    painter: MakeupOverlayPainter(
                                      image: _capturedUiImage!,
                                      face: _detectedFace!,
                                      lipstickColor: _look!.lipstickColor,
                                      blushColor: _look!.blushColor,
                                      eyeshadowColor: _look!.eyeshadowColor,
                                      intensity: _intensity,
                                      faceShape: _faceProfile!.faceShape,
                                      preset: _selectedLook,
                                      debugMode: isDebug,
                                      isLiveMode: false,
                                      eyelinerStyle: LookEngine.eyelinerStyleFromPreset(_selectedLook),
                                      skinColor: Color.fromARGB(
                                        255,
                                        _faceProfile!.avgR,
                                        _faceProfile!.avgG,
                                        _faceProfile!.avgB,
                                      ),
                                      sceneLuminance: _sceneLuminance,
                                      leftCheekLuminance: _leftCheekLum,
                                      rightCheekLuminance: _rightCheekLum,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    if (showSlider)
                      Row(
                        children: [
                          const Text('Opacity', style: TextStyle(fontSize: 12)),
                          Expanded(
                            child: Slider(
                              value: _intensity,
                              min: 0.0,
                              max: 1.0,
                              divisions: 20,
                              label: '${(_intensity * 100).round()}%',
                              onChanged: (v) => setState(() => _intensity = v),
                            ),
                          ),
                        ],
                      ),

                    const SizedBox(height: 8),

                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 40,
                            child: FilledButton.icon(
                              onPressed: (_faceProfile != null && _look != null)
                                  ? _openInstructions
                                  : null,
                              icon: const Icon(Icons.list_alt, size: 16),
                              label: const Text(
                                'View Instructions',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(width: 8),

                        Expanded(
                          child: SizedBox(
                            height: 40,
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ScanResultPage(
                                      scannedItem: widget.scannedItem,
                                      scannedImagePath: _capturedFile?.path,
                                      detectedFace: _detectedFace,
                                      faceProfile: _faceProfile,
                                      look: _look,
                                      selectedPreset: _selectedLook,
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.preview, size: 16),
                              label: const Text(
                                'View Result Screen',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Text(
                  _status,
                  style: const TextStyle(fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),

            if (_capturedUiImage == null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _busy ? null : _handlePreviewTap,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF4D97),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.camera_alt, size: 24),
                    label: const Text(
                      'Scan Face',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class FaceGuidePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.6)
      ..style = PaintingStyle.fill;

    const dotRadius = 4.0;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final positions = [0, 45, 90, 135, 180, 225, 270, 315];

    for (final angle in positions) {
      final radian = angle * 3.14159 / 180;
      final x = center.dx + radius * cos(radian);
      final y = center.dy + radius * sin(radian);
      canvas.drawCircle(Offset(x, y), dotRadius, paint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}