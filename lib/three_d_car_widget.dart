import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';

class ThreeDCarWidget extends StatelessWidget {
  const ThreeDCarWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 400, // Adjust height as needed
      child: ModelViewer(
        src: "https://modelviewer.dev/shared-assets/models/Astronaut.glb", // Ensure this file exists in assets
        alt: "3D Car Model",
        autoRotate: true, // Enables smooth rotation
        disableZoom: false, // Allows zooming
        ar: false, // No AR mode
        backgroundColor: Colors.transparent,
      ),
    );
  }
}
