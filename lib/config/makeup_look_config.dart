import 'styles/blush_style.dart';
import 'styles/eyeliner_style.dart';
import 'styles/eyeshadow_style.dart';

class MakeupLookConfig {
  final BlushContourStyle blush;
  final EyelinerStyleConfig eyeliner;
  final EyeshadowStyleConfig eyeshadow;

  const MakeupLookConfig({
    required this.blush,
    required this.eyeliner,
    required this.eyeshadow,
  });
}