import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';

class VehicleModelView extends StatelessWidget {
  const VehicleModelView({super.key});

  static const modelPath =
      'assets/car_models/2025_byd_seal_5_dm-i_chazor_king_destroyer_05.glb';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Stack(
      fit: StackFit.expand,
      children: [
        Center(
          child: Icon(
            Icons.directions_car_filled_rounded,
            size: 220,
            color: scheme.onSurface.withValues(alpha: .18),
          ),
        ),
        ModelViewer(
          src: modelPath,
          alt: '2025 BYD Seal electric sedan',
          cameraControls: true,
          disableZoom: true,
          autoRotate: false,
          backgroundColor: Colors.transparent,
        ),
      ],
    );
  }
}
