import 'dart:io';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

class ProfilePhotoHelper {
  ProfilePhotoHelper._();

  static final ImagePicker _picker = ImagePicker();

  /// Captures/picks an image from Camera or Gallery.
  /// Automatically applies maxWidth: 600, maxHeight: 600, imageQuality: 85.
  /// Handles permission issues gracefully (returns null or throws PlatformException).
  static Future<File?> pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 600,
        maxHeight: 600,
        imageQuality: 85,
      );
      if (pickedFile != null) {
        return File(pickedFile.path);
      }
    } on PlatformException catch (e) {
      if (e.code == 'photo_access_denied' || e.code == 'camera_access_denied') {
        throw Exception('Permission denied. Please enable access in settings.');
      }
      rethrow;
    }
    return null;
  }

  /// Resolves the relative path stored in SQLite to an absolute File.
  static Future<File> getAbsoluteFile(String relativePath) async {
    final Directory appDir = await getApplicationDocumentsDirectory();
    return File(join(appDir.path, relativePath));
  }

  /// Checks if the physical file exists on disk.
  static Future<bool> fileExists(String? relativePath) async {
    if (relativePath == null || relativePath.isEmpty) return false;
    try {
      final File file = await getAbsoluteFile(relativePath);
      return await file.exists();
    } catch (_) {
      return false;
    }
  }

  /// Saves a picked image file to local app documents directory.
  /// Folder structure: app_data/profile_photos/students/ or teachers/
  /// Filename format: `student_123_<timestamp>.jpg`
  /// Returns the relative path reference.
  static Future<String> saveImage(File tempFile, String subFolder, String prefix) async {
    final Directory appDir = await getApplicationDocumentsDirectory();
    final String photosDirName = join('profile_photos', subFolder);
    final Directory photosDir = Directory(join(appDir.path, photosDirName));

    if (!await photosDir.exists()) {
      await photosDir.create(recursive: true);
    }

    final int timestamp = DateTime.now().millisecondsSinceEpoch;
    final String extensionName = extension(tempFile.path).isNotEmpty ? extension(tempFile.path) : '.jpg';
    final String fileName = '${prefix}_$timestamp$extensionName';
    final String relativePath = join(photosDirName, fileName).replaceAll('\\', '/');

    final File destFile = File(join(appDir.path, relativePath));
    await tempFile.copy(destFile.path);

    return relativePath;
  }

  /// Safely deletes the physical file.
  static Future<void> deleteImage(String? relativePath) async {
    if (relativePath == null || relativePath.isEmpty) return;
    try {
      final File file = await getAbsoluteFile(relativePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // Log or handle error, do not crash as per instructions
    }
  }
}
