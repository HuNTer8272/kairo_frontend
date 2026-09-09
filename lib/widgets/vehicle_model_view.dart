import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';

class VehicleModelView extends StatelessWidget {
  const VehicleModelView({super.key, required this.compact});

  final bool compact;

  static const modelPath =
      'assets/car_models/black_sedan.glb';

  @override
  Widget build(BuildContext context) {
    return ModelViewer(
      src: modelPath,
      alt: 'Black electric sedan',
      cameraControls: true,
      disableZoom: true,
      autoRotate: false,
      cameraOrbit: compact ? '0deg 75deg 100%' : '0deg 75deg 82%',
      fieldOfView: compact ? 'auto' : '38deg',
      loading: Loading.eager,
      reveal: Reveal.auto,
      shadowIntensity: 0.35,
      backgroundColor: Colors.transparent,
    );
  }
}
