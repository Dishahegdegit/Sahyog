import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class CloudinaryService {
  static const String cloudName = 'aj2utezx';
  static const String uploadPreset = 'Sahyog_preset';

  static const String _uploadUrl =
      'https://api.cloudinary.com/v1_1/$cloudName/image/upload';

  /// Uploads a single image File to Cloudinary.
  /// Returns the secure image URL string on success, or null on failure.
  Future<String?> uploadImage(File imageFile) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse(_uploadUrl));

      request.fields['upload_preset'] = uploadPreset;
      request.files.add(
        await http.MultipartFile.fromPath('file', imageFile.path),
      );

      final response = await request.send();
      final responseData = await response.stream.toBytes();
      final jsonData = json.decode(String.fromCharCodes(responseData));

      if (response.statusCode == 200) {
        return jsonData['secure_url'] as String?;
      } else {
        print('Cloudinary Upload Failed: ${jsonData['error']?['message']}');
        return null;
      }
    } catch (e) {
      print('Cloudinary Exception: $e');
      return null;
    }
  }

  /// Uploads a list of image Files to Cloudinary.
  /// Returns a list of uploaded secure image URL strings.
  Future<List<String>> uploadMultipleImages(List<File> imageFiles) async {
    List<String> uploadedUrls = [];
    for (File file in imageFiles) {
      final url = await uploadImage(file);
      if (url != null) {
        uploadedUrls.add(url);
      }
    }
    return uploadedUrls;
  }
}