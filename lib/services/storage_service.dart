import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import 'cloudinary_service.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final CloudinaryService _cloudinary = CloudinaryService();

  Future<String?> uploadDonationImage(dynamic imageInput) async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';
    final bytes = await _asBytes(imageInput);
    if (bytes == null || bytes.isEmpty) return null;

    try {
      final path =
          'donations/$uid/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = _storage.ref(path);
      await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint('Firebase Storage upload failed, using Cloudinary: $e');
      return _cloudinary.uploadImage(bytes);
    }
  }

  Future<Uint8List?> _asBytes(dynamic imageInput) async {
    if (imageInput is Uint8List) return imageInput;
    if (imageInput is XFile) return imageInput.readAsBytes();
    return null;
  }
}
