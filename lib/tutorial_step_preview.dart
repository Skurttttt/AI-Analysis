class StepLayerConfig {
  final bool showBrows;
  final bool showEyeshadow;
  final bool showEyeliner;
  final bool showBlush;
  final bool showContour;
  final bool showLips;

  const StepLayerConfig({
    required this.showBrows,
    required this.showEyeshadow,
    required this.showEyeliner,
    required this.showBlush,
    required this.showContour,
    required this.showLips,
  });

  const StepLayerConfig.none()
      : showBrows = false,
        showEyeshadow = false,
        showEyeliner = false,
        showBlush = false,
        showContour = false,
        showLips = false;

  const StepLayerConfig.browsOnly()
      : showBrows = true,
        showEyeshadow = false,
        showEyeliner = false,
        showBlush = false,
        showContour = false,
        showLips = false;
}

StepLayerConfig layerConfigForTargetArea(String targetArea) {
  switch (targetArea) {
    case 'full_face':
      return const StepLayerConfig.none();

    case 'brows':
      return const StepLayerConfig(
        showBrows: true,
        showEyeshadow: false,
        showEyeliner: false,
        showBlush: false,
        showContour: false,
        showLips: false,
      );

    case 'eyeshadow':
      return const StepLayerConfig(
        showBrows: true,
        showEyeshadow: true,
        showEyeliner: false,
        showBlush: false,
        showContour: false,
        showLips: false,
      );

    case 'eyeliner':
      return const StepLayerConfig(
        showBrows: true,
        showEyeshadow: true,
        showEyeliner: true,
        showBlush: false,
        showContour: false,
        showLips: false,
      );

    case 'blush_contour':
      return const StepLayerConfig(
        showBrows: true,
        showEyeshadow: true,
        showEyeliner: true,
        showBlush: true,
        showContour: true,
        showLips: false,
      );

    case 'lips':
      return const StepLayerConfig(
        showBrows: true,
        showEyeshadow: true,
        showEyeliner: true,
        showBlush: true,
        showContour: true,
        showLips: true,
      );

    case 'full_makeup':
      return const StepLayerConfig(
        showBrows: true,
        showEyeshadow: true,
        showEyeliner: true,
        showBlush: true,
        showContour: true,
        showLips: true,
      );

    default:
      return const StepLayerConfig.none();
  }
}