import '../look_engine.dart' show MakeupLookPreset;
import 'makeup_look_config.dart';
import 'styles/blush_style.dart';
import 'styles/eyeliner_style.dart';
import 'styles/eyeshadow_style.dart';

class MakeupLookConfigs {
  static final Map<MakeupLookPreset, MakeupLookConfig> configs = {
    MakeupLookPreset.softGlam: MakeupLookConfig(
      blush: BlushContourStyle(
        blushY: 0.53,
        blushX: 0.31,
        blushW: 0.24,
        blushH: 0.085,
        blushAngle: -0.20,
        contourY: 0.63,
        contourW: 0.28,
        contourH: 0.045,
        contourAngle: -0.28,
        blushOpacity: 0.22,
        contourOpacity: 0.18,
      ),
      eyeliner: EyelinerStyleConfig(
        wingLength: 0.34,
        wingLift: 0.52,
        thickness: 2.0,
        startInset: 0.20,
        angleGuideOpacity: 0.25,
      ),
      eyeshadow: EyeshadowStyleConfig(
        lidHeight: 0.78,
        lidOpacity: 0.30,
        creaseLift: 0.50,
        creaseOpacity: 0.36,
        outerSize: 0.28,
        outerOpacity: 0.42,
        outerLift: 0.20,
        showOuterV: true,
        showLowerLash: false,
      ),
    ),

    MakeupLookPreset.emo: MakeupLookConfig(
      blush: BlushContourStyle(
        blushY: 0.57,
        blushX: 0.30,
        blushW: 0.25,
        blushH: 0.070,
        blushAngle: -0.12,
        contourY: 0.64,
        contourW: 0.34,
        contourH: 0.045,
        contourAngle: -0.18,
        blushOpacity: 0.16,
        contourOpacity: 0.24,
      ),
      eyeliner: EyelinerStyleConfig(
        wingLength: 0.48,
        wingLift: 0.40,
        thickness: 2.8,
        startInset: 0.06,
        angleGuideOpacity: 0.36,
      ),
      eyeshadow: EyeshadowStyleConfig(
        lidHeight: 0.95,
        lidOpacity: 0.42,
        creaseLift: 0.42,
        creaseOpacity: 0.42,
        outerSize: 0.42,
        outerOpacity: 0.58,
        outerLift: 0.10,
        showOuterV: false,
        showLowerLash: true,
      ),
    ),
  };

  static MakeupLookConfig get(MakeupLookPreset preset) {
    return configs[preset] ?? configs[MakeupLookPreset.softGlam]!;
  }
}