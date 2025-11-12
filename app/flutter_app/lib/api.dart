import 'dart:io';
import 'package:dio/dio.dart';

class ApiServiceDio {
  static const String baseUrl = 'https://supernotable-lorenza-unsieged.ngrok-free.dev/app';
  final Dio dio;

  ApiServiceDio() : dio = Dio(BaseOptions(baseUrl: baseUrl));

  // 1. Registration
  Future<int?> register(String name) async {
    final response = await dio.post('/registration', data: {'name': name});
    if (response.statusCode == 200) {
      return response.data['s_id'][0][0];
    } else {
      print('Registration failed: ${response.statusCode}');
      return null;
    }
  }

  // 2. Upload
  Future<bool> upload(int sId, String title, String text, File imageFile) async {
    FormData formData = FormData.fromMap({
      's_id': sId,
      'title': title,
      'text': text,
      'img': await MultipartFile.fromFile(imageFile.path, filename: imageFile.path.split('/').last),
    });

    final response = await dio.post('/upload', data: formData);
    return response.statusCode == 200;
  }
}