// import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:frapp/services/storage_service.dart';
// import 'package:path_provider/path_provider.dart';

class FaceRecognitionService {
  static final FaceRecognitionService _instance =
      FaceRecognitionService._internal();
  factory FaceRecognitionService() => _instance;
  FaceRecognitionService._internal();

  late Interpreter _interpreter;
  final _faceDetector = FaceDetector(options: FaceDetectorOptions());
  final _storageService = StorageService();

  bool _isInitialized = false;
  List<Map<String, dynamic>>? _cachedFaces;

  Future<void> initialize() async {
    if (_isInitialized) return;
    final interpreterOptions = InterpreterOptions();
    // interpreterOptions.threads = 4;
    // interpreterOptions.useNnApiForAndroid = true;
    // interpreterOptions.useMetalDelegateForIOS = true;

    _interpreter = await Interpreter.fromAsset('assets/mobilefacenet.tflite',
        options: interpreterOptions);
    _cachedFaces = await _storageService.getFaces();
    _isInitialized = true;
  }

  Future<List<double>?> getEmbedding(img.Image srcImage, Face face) async {
    int x, y, w, h;
    x = face.boundingBox.left.round();
    y = face.boundingBox.top.round();
    w = face.boundingBox.width.round();
    h = face.boundingBox.height.round();

    img.Image faceImage =
        img.copyCrop(srcImage, x: x, y: y, width: w, height: h);
    img.Image resizedImage = img.copyResizeCropSquare(faceImage, size: 112);

    // Save cropped face image
    // final docDir = await getApplicationDocumentsDirectory();
    // final file = File('${docDir.path}/${face.hashCode}.jpg');
    // await file.writeAsBytes(img.encodeJpg(resizedImage));

    List input = _imageToByteListFloat32(resizedImage, 112, 127.5, 127.5);
    input = input.reshape([1, 112, 112, 3]);
    List output = List.generate(1, (_) => List.filled(192, 0));
    _interpreter.run(input, output);
    return output[0].cast<double>();
  }

  List _imageToByteListFloat32(
      img.Image image, int size, double mean, double std) {
    var convertedBytes = Float32List(1 * size * size * 3);
    var buffer = Float32List.view(convertedBytes.buffer);
    int pixelIndex = 0;

    for (var i = 0; i < size; i++) {
      for (var j = 0; j < size; j++) {
        var pixel = image.getPixel(j, i);
        buffer[pixelIndex++] = (pixel.r - mean) / std;
        buffer[pixelIndex++] = (pixel.g - mean) / std;
        buffer[pixelIndex++] = (pixel.b - mean) / std;
      }
    }
    return convertedBytes.toList();
  }

  Future<void> registerFace(String name, List embedding) async {
    await _storageService.saveFace(name, embedding);
    _cachedFaces = await _storageService.getFaces();
  }

  Future<String> identifyFace(List<double> embedding,
      {double threshold = 1.0}) async {
    _cachedFaces ??= await _storageService.getFaces();

    double minDistance = double.maxFinite;
    String name = 'Unknown';

    for (var face in _cachedFaces!) {
      final distance =
          _euclideanDistance(embedding, face['embedding'].cast<double>());
      if (distance <= threshold && distance < minDistance) {
        minDistance = distance;
        name = face['name'];
      }
    }

    return name;
  }

  double _euclideanDistance(List e1, List e2) {
    if (e1.length != e2.length) {
      throw Exception('Vectors have different lengths');
    }
    var sum = 0.0;
    for (var i = 0; i < e1.length; i++) {
      sum += pow(e1[i] - e2[i], 2);
    }
    return sqrt(sum);
  }

  Future<void> deleteFace(String name) async {
    await _storageService.deleteFace(name);
    _cachedFaces = await _storageService.getFaces();
  }

  Future<List<Map<String, dynamic>>> getRegisteredFaces() async {
    _cachedFaces ??= await _storageService.getFaces();
    return _cachedFaces!;
  }

  Future<List<Face>> processImage(InputImage inputImage) async {
    final faces = await _faceDetector.processImage(inputImage);
    return faces;
  }

  void dispose() {
    if (!_isInitialized) return;
    _faceDetector.close();
    _interpreter.close();
    _isInitialized = false;
  }
}