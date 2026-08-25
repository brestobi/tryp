import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

class CameraPermissionService {
  CameraPermissionService._();

  static Future<bool> ensureCameraPermission({
    CameraLensDirection lensDirection = CameraLensDirection.back,
  }) async {
    CameraController? controller;
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return false;

      final camera = cameras.firstWhere(
        (item) => item.lensDirection == lensDirection,
        orElse: () => cameras.first,
      );
      controller = CameraController(
        camera,
        ResolutionPreset.low,
        enableAudio: false,
      );
      await controller.initialize();
      return true;
    } on CameraException catch (error) {
      debugPrint('Camera permission preflight failed: ${error.description}');
      return false;
    } catch (error) {
      debugPrint('Camera permission preflight failed: $error');
      return false;
    } finally {
      await controller?.dispose();
    }
  }
}
