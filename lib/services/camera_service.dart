import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';

class CameraService {
  CameraController? controller;
  List<CameraDescription>? _cameras;

  Future<void> initialize() async {
    // Ensure permissions are granted before proceeding
    if (await Permission.camera.request().isGranted) {
      _cameras = await availableCameras();
      if (_cameras != null && _cameras!.isNotEmpty) {
        // Prefer the front camera for hand gesture recognition
        CameraDescription selectedCamera = _cameras!.firstWhere(
          (camera) => camera.lensDirection == CameraLensDirection.front,
          orElse: () => _cameras!.first,
        );

        controller = CameraController(
          selectedCamera,
          ResolutionPreset.medium,
          enableAudio: false,
          imageFormatGroup: ImageFormatGroup.yuv420,
        );

        await controller!.initialize();
      } else {
        throw Exception("No cameras available on the device.");
      }
    } else {
      throw Exception("Camera permission denied.");
    }
  }

  void startImageStream(Function(CameraImage) onImage) {
    if (controller != null && controller!.value.isInitialized) {
      if (!controller!.value.isStreamingImages) {
        controller!.startImageStream(onImage);
      }
    }
  }

  void stopImageStream() {
    if (controller != null && controller!.value.isStreamingImages) {
      controller!.stopImageStream();
    }
  }

  void dispose() {
    controller?.dispose();
  }
}
