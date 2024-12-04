import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:frapp/services/face_recognition_service.dart';
import 'package:frapp/services/camera_service.dart';
import 'package:frapp/widgets/face_detector_painter.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:flutter/services.dart';

class RegisterFace {
  late String name;
  late List<double> embedding;
  RegisterFace({required this.name, required this.embedding});
}

class RecognizeFacePage extends StatefulWidget {
  final CameraDescription camera;

  const RecognizeFacePage({super.key, required this.camera});

  @override
  State<RecognizeFacePage> createState() => _RecognizeFacePageState();
}

class _RecognizeFacePageState extends State<RecognizeFacePage> {
  final FaceRecognitionService _faceService = FaceRecognitionService();
  final CameraService _cameraService = CameraService();
  late Future<void> _initializeControllerFuture;
  CustomPaint? _customPaint;
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _initializeControllerFuture = _initializeServices();
  }

  Future<void> _initializeServices() async {
    try {
      await _faceService.initialize();
      await _cameraService.initialize(widget.camera);
      _cameraService.startImageStream(_processCameraImage);
    } catch (e) {
      throw Exception('Error initializing services: $e');
    }
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (_isBusy) return;
    _isBusy = true;

    try {
      // Prepare input image
      final orientations = {
        DeviceOrientation.portraitUp: 0,
        DeviceOrientation.landscapeLeft: 90,
        DeviceOrientation.portraitDown: 180,
        DeviceOrientation.landscapeRight: 270,
      };
      InputImageRotation? rotation;
      if (Platform.isIOS) {
        rotation = InputImageRotationValue.fromRawValue(
            widget.camera.sensorOrientation);
      } else {
        var rotationCompensation =
            orientations[_cameraService.controller.value.deviceOrientation];
        if (rotationCompensation == null) return;
        if (widget.camera.lensDirection == CameraLensDirection.front) {
          rotationCompensation =
              (widget.camera.sensorOrientation + rotationCompensation) % 360;
        } else {
          rotationCompensation =
              (widget.camera.sensorOrientation - rotationCompensation + 360) %
                  360;
        }
        rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
      }
      if (rotation == null) return;
      final format = InputImageFormatValue.fromRawValue(image.format.raw);
      if (format == null) return;

      InputImage inputImage = InputImage.fromBytes(
        bytes: image.planes[0].bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: format,
          bytesPerRow: image.planes[0].bytesPerRow,
        ),
      );

      // Detect faces
      final faces = await _faceService.detectFaces(inputImage);
      if (faces.isEmpty) {
        if (mounted) {
          setState(() => _customPaint = null);
        }
        _isBusy = false;
        return;
      }

      // Prepare input list
      List input = await compute(FaceRecognitionService.prepareInputFromNV21, {
        'nv21Data': image.planes[0].bytes,
        'width': image.width,
        'height': image.height,
        'isFrontCamera':
            widget.camera.lensDirection == CameraLensDirection.front,
        'face': faces.first
      });

      // Get embedding
      final embedding = _faceService.getEmbedding(input);
      // Identify the face
      final name = await _faceService.identifyFace(embedding);

      // Update UI
      if (mounted) {
        setState(() {
          _customPaint = CustomPaint(
            painter: FaceDetectorPainter(
              faces,
              inputImage.metadata!.size,
              inputImage.metadata!.rotation,
              widget.camera.lensDirection,
              name,
            ),
          );
        });
      }
    } finally {
      _isBusy = false;
    }
  }

  @override
  void dispose() {
    _faceService.dispose();
    _cameraService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recognize Face')),
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done &&
              !snapshot.hasError) {
            return CameraPreview(_cameraService.controller,
                child: _customPaint);
          } else if (snapshot.hasError) {
            return Center(
              child: Text('Error initializing camera: ${snapshot.error}'),
            );
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
    );
  }
}
