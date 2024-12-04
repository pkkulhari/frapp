import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image_picker/image_picker.dart';
import 'package:frapp/services/face_recognition_service.dart';

class RegisterFacePage extends StatefulWidget {
  const RegisterFacePage({super.key});

  @override
  State<RegisterFacePage> createState() => _RegisterFacePageState();
}

class _RegisterFacePageState extends State<RegisterFacePage> {
  final TextEditingController nameController = TextEditingController();
  final _imagePicker = ImagePicker();
  final _faceService = FaceRecognitionService();

  @override
  void initState() {
    super.initState();
    _faceService.initialize();
  }

  @override
  void dispose() {
    nameController.dispose();
    _faceService.dispose();
    super.dispose();
  }

  Future<void> _registerFace() async {
    if (nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a name')),
      );
      return;
    }

    final image = await _imagePicker.pickImage(source: ImageSource.camera);
    if (image == null) return;

    InputImage inputImage = InputImage.fromFile(File(image.path));
    final faces = await _faceService.detectFaces(inputImage);
    if (faces.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No face detected')),
        );
      }
      return;
    }

    final input = FaceRecognitionService.prepareInputFromImagePath({
      'imgPath': image.path,
      'face': faces.first,
    });
    final embedding = _faceService.getEmbedding(input);

    await _faceService.registerFace(nameController.text, embedding);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Face registered successfully'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register Face')),
      body: ListView(
        children: <Widget>[
          const SizedBox(height: 16.0),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: TextField(
              controller: nameController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Your Name',
              ),
            ),
          ),
          const SizedBox(height: 16.0),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: ElevatedButton(
                onPressed: _registerFace, child: const Text('Register Face')),
          ),
        ],
      ),
    );
  }
}
