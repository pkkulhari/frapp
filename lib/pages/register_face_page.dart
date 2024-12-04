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
  bool _isLoading = false;

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

    setState(() {
      _isLoading = true;
    });

    try {
      final image = await _imagePicker.pickImage(source: ImageSource.camera);
      if (image == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      InputImage inputImage = InputImage.fromFile(File(image.path));
      final faces = await _faceService.detectFaces(inputImage);
      if (faces.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No face detected')),
          );
        }
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final input = FaceRecognitionService.prepareInputFromImagePath({
        'imgPath': image.path,
        'face': faces.first,
      });
      final embedding = _faceService.getEmbedding(input);

      try {
        await _faceService.registerFace(nameController.text, embedding);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error registering face: $e')),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }

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
      body: Stack(
        children: [
          ListView(
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
                  onPressed: _isLoading ? null : _registerFace,
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('Register Face'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
