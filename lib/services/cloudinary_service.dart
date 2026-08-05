import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class CloudinaryService {
  static const String cloudName = 'aj2utezx';
  static const String uploadPreset = 'Sahyog_preset';

  static const String _uploadUrl =
      'https://api.cloudinary.com/v1_1/$cloudName/image/upload';

  /// Uploads an image (File, XFile, or Uint8List bytes) to Cloudinary.
  /// Returns the secure image URL string on success, or throws error on failure.
  Future<String?> uploadImage(dynamic imageInput, {String? filename}) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse(_uploadUrl));
      request.fields['upload_preset'] = uploadPreset;

      if (imageInput is XFile) {
        final bytes = await imageInput.readAsBytes();
        final name = filename ?? imageInput.name;
        request.files.add(
          http.MultipartFile.fromBytes(
            'file',
            bytes,
            filename: name.isNotEmpty ? name : 'upload.jpg',
          ),
        );
      } else if (imageInput is Uint8List) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'file',
            imageInput,
            filename: filename ?? 'upload.jpg',
          ),
        );
      } else if (imageInput is File) {
        final bytes = await imageInput.readAsBytes();
        final name = filename ?? imageInput.path.split(Platform.pathSeparator).last;
        request.files.add(
          http.MultipartFile.fromBytes(
            'file',
            bytes,
            filename: name.isNotEmpty ? name : 'upload.jpg',
          ),
        );
      } else {
        throw 'Unsupported image input type: ${imageInput.runtimeType}';
      }

      final response = await request.send();
      final responseData = await response.stream.toBytes();
      final jsonData = json.decode(utf8.decode(responseData));

      if (response.statusCode == 200) {
        return jsonData['secure_url'] as String?;
      } else {
        final errorMsg = jsonData['error']?['message'] ?? 'Cloudinary error code ${response.statusCode}';
        print('Cloudinary Upload Failed: $errorMsg');
        throw errorMsg;
      }
    } catch (e) {
      print('Cloudinary Exception: $e');
      rethrow;
    }
  }

  /// Backward-compatible alias for uploading bytes directly.
  Future<String?> uploadImageBytes(
    Uint8List bytes, {
    String filename = 'image.jpg',
  }) async {
    return uploadImage(bytes, filename: filename);
  }

  /// Uploads a list of images to Cloudinary.
  Future<List<String>> uploadMultipleImages(List<dynamic> imageInputs) async {
    List<String> uploadedUrls = [];
    for (var input in imageInputs) {
      final url = await uploadImage(input);
      if (url != null) {
        uploadedUrls.add(url);
      }
    }
    return uploadedUrls;
  }
}
