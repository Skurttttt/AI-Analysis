class EyeshadowStyleConfig {
  final double lidHeight;
  final double lidOpacity;
  final double creaseLift;
  final double creaseOpacity;
  final double outerSize;
  final double outerOpacity;

  // ✅ ADD THESE
  final double outerLift;
  final bool showOuterV;
  final bool showLowerLash;

  const EyeshadowStyleConfig({
    required this.lidHeight,
    required this.lidOpacity,
    required this.creaseLift,
    required this.creaseOpacity,
    required this.outerSize,
    required this.outerOpacity,
    required this.outerLift,
    required this.showOuterV,
    required this.showLowerLash,
  });
}