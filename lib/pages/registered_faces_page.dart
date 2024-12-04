import 'package:flutter/material.dart';
import 'package:frapp/services/face_recognition_service.dart';

class RegisteredFacesPage extends StatefulWidget {
  const RegisteredFacesPage({super.key});

  @override
  State<RegisteredFacesPage> createState() => _RegisteredFacesPageState();
}

class _RegisteredFacesPageState extends State<RegisteredFacesPage> {
  final FaceRecognitionService _faceService = FaceRecognitionService();
  List<Map<String, dynamic>> _faces = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFaces();
  }

  Future<void> _loadFaces() async {
    try {
      final faces = await _faceService.getRegisteredFaces();
      setState(() {
        _faces = faces;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading faces: $e')),
        );
      }
    }
  }

  Future<void> _deleteFace(String name) async {
    try {
      await _faceService.deleteFace(name);
      await _loadFaces(); // Reload the list
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Face deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting face: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registered Faces'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _faces.isEmpty
              ? const Center(
                  child: Text(
                    'No faces registered yet',
                    style: TextStyle(fontSize: 16),
                  ),
                )
              : ListView.builder(
                  itemCount: _faces.length,
                  itemBuilder: (context, index) {
                    final face = _faces[index];
                    return ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.face),
                      ),
                      title: Text(face['name']),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteFace(face['name']),
                      ),
                    );
                  },
                ),
    );
  }
}
