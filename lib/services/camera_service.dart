import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;

class CameraService {
  static final CameraService _instance = CameraService._internal();
  factory CameraService() => _instance;
  CameraService._internal();

  late CameraController _controller;
  bool _isInitialized = false;

  Future<void> initialize(CameraDescription camera) async {
    _controller = CameraController(
      camera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.nv21,
    );
    await _controller.initialize();
    _isInitialized = true;
  }

  void startImageStream(Function(CameraImage) onImage) {
    _controller.startImageStream(onImage);
  }

  CameraController get controller {
    if (!_isInitialized) {
      throw CameraException('Camera not initialized',
          'Call initialize() before accessing the controller');
    }
    return _controller;
  }

  img.Image convertNV21ToImage(Uint8List nv21Data, int width, int height) {
    final image = img.Image(width: width, height: height);
    final ySize = width * height;
    final uvSize = width * height ~/ 4;

    final yPlane = nv21Data.sublist(0, ySize);
    final uvPlane = nv21Data.sublist(ySize, ySize + uvSize * 2);

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final yIndex = y * width + x;
        final yValue = yPlane[yIndex];

        final uvIndex = (y ~/ 2) * width + (x - (x % 2));
        final vValue = uvPlane[uvIndex];
        final uValue = uvPlane[uvIndex + 1];

        final r = (yValue + 1.402 * (vValue - 128)).clamp(0, 255).toInt();
        final g = (yValue - 0.34414 * (uValue - 128) - 0.71414 * (vValue - 128))
            .clamp(0, 255)
            .toInt();
        final b = (yValue + 1.772 * (uValue - 128)).clamp(0, 255).toInt();

        image.setPixel(x, y, img.ColorRgb8(r, g, b));
      }
    }

    return image;
  }

  Future<void> dispose() async {
    if (!_isInitialized) return;
    await _controller.stopImageStream();
    await _controller.dispose();
    _isInitialized = false;
  }
}
