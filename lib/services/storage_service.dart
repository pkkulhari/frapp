import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  static const String _facesFileName = 'faces.json';

  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  Future<File> get _localFile async {
    final path = await _localPath;
    return File('$path/$_facesFileName');
  }

  Future<List<Map<String, dynamic>>> getFaces() async {
    try {
      final file = await _localFile;
      if (!await file.exists()) {
        await file.create();
        await file.writeAsString('[]');
        return [];
      }

      final contents = await file.readAsString();
      final List<dynamic> jsonData = json.decode(contents);
      return List<Map<String, dynamic>>.from(jsonData);
    } catch (e) {
      throw Exception('Error getting faces: $e');
    }
  }

  Future<void> saveFace(String name, List<dynamic> embedding) async {
    try {
      final file = await _localFile;
      final faces = await getFaces();

      if (faces.any((face) => face['name'] == name)) {
        throw Exception('Face with this name already exists');
      }

      faces.add({
        'name': name,
        'embedding': embedding,
      });

      await file.writeAsString(json.encode(faces));
    } catch (e) {
      throw Exception('Error saving face: $e');
    }
  }

  Future<void> deleteFace(String name) async {
    try {
      final file = await _localFile;
      final faces = await getFaces();

      faces.removeWhere((face) => face['name'] == name);
      await file.writeAsString(json.encode(faces));
    } catch (e) {
      throw Exception('Error deleting face: $e');
    }
  }

  Future<void> clearAllFaces() async {
    try {
      final file = await _localFile;
      await file.writeAsString('[]');
    } catch (e) {
      throw Exception('Error clearing faces: $e');
    }
  }
}
